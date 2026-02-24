import Foundation
import CloudKit
import Combine
import AppKit

// MARK: - CloudSyncManager
//
// 동기화 시나리오:
//   A컴퓨터에서 작업 후 저장 → CloudKit 업로드
//   B컴퓨터에서 CKDatabaseSubscription silent push 수신 → fetchLatest() → 로컬보다 새 데이터면 적용
//
// 핵심 설계:
//   - CKDatabaseSubscription으로 서버 변경 시 자동 push 알림 수신
//   - 저장 충돌(serverRecordChanged)을 타임스탬프 기반으로 해결
//   - 네트워크 오류는 지수 백오프로 재시도
//   - serverRecord 캐싱으로 불필요한 fetch 라운드트립 제거
//   - 모든 CloudKit 조작은 serial 큐에서 순서 보장

final class CloudSyncManager {

    // MARK: - CloudKit 상수
    private enum CK {
        static let containerID = "iCloud.com.leeo.SprintCommander"
        static let recordType  = "AppData"
        static let recordID    = CKRecord.ID(recordName: "MainAppData")
        static let jsonField   = "jsonData"
        static let tsField     = "timestamp"
    }

    // MARK: - 로컬 캐시 경로
    private var localDir: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("SprintCommander")
    }
    private var localURL: URL { localDir.appendingPathComponent("SprintCommanderData.json") }

    // MARK: - Properties
    private let container: CKContainer
    private let db: CKDatabase

    /// 마지막으로 서버에서 받은 CKRecord. 저장 시 불필요한 fetch를 피하기 위해 캐싱.
    /// syncQ 위에서만 접근해야 함.
    private var serverRecord: CKRecord?

    /// 데이터가 변경됐을 때 호출되는 콜백 (메인 스레드 보장)
    var onChange: ((AppData) -> Void)?

    /// CKRecord 접근의 스레드 안전성을 위한 직렬 큐
    private let syncQ = DispatchQueue(label: "com.leeo.SprintCommander.sync", qos: .utility)

    // MARK: - 디바운스 저장 파이프라인
    private let saveSubject = PassthroughSubject<AppData, Never>()
    private var saveCancellable: AnyCancellable?

    // MARK: - Codecs
    private let enc: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let dec: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    private static let subscriptionID = "private-db-changes"

    init() {
        container = CKContainer(identifier: CK.containerID)
        db = container.privateCloudDatabase

        // 1초 디바운스: 연속 수정 시 마지막 값만 저장
        saveCancellable = saveSubject
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] data in self?.writeToStores(data) }
    }

    // MARK: - 공개 저장 API

    /// 디바운스 저장 (데이터 변경 시마다 호출)
    func save(_ data: AppData) {
        saveSubject.send(data)
    }

    /// 즉시 저장 (앱 종료 / 백그라운드 진입 시)
    func saveImmediately(_ data: AppData) {
        writeToStores(data)
    }

    // MARK: - 공개 로드 / 동기화 API

    /// 로컬 데이터를 즉시 반환 + 백그라운드에서 CloudKit fetch.
    /// 클라우드가 더 새로우면 onChange 콜백 호출.
    func load() -> AppData? {
        let local = loadLocal()
        fetchCloudAndApply(localTimestamp: local?.timestamp)
        return local
    }

    /// 명시적 동기화 요청 (scenePhase active, 수동 새로고침).
    func fetchLatest() {
        fetchCloudAndApply(localTimestamp: loadLocal()?.timestamp)
    }

    // MARK: - 모니터링

    func startMonitoring(onChange: @escaping (AppData) -> Void) {
        self.onChange = onChange

        // iCloud 계정 변경 감지 (로그인/로그아웃)
        NotificationCenter.default.addObserver(
            self, selector: #selector(accountChanged),
            name: .CKAccountChanged, object: nil
        )

        // 원격 알림 등록 + CloudKit 구독
        NSApplication.shared.registerForRemoteNotifications()
        subscribeToChanges()
    }

    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Push 알림 수신 처리

    /// AppDelegate에서 didReceiveRemoteNotification 시 호출
    func handleRemoteNotification(userInfo: [String: Any]) {
        let notification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        guard notification?.subscriptionID == Self.subscriptionID else { return }
        print("[CloudSync] push 수신 → 서버 변경 감지, fetch 시작")
        fetchLatest()
    }

    // MARK: - CKDatabaseSubscription (서버 변경 시 silent push)

    private func subscribeToChanges() {
        // 매번 구독을 재등록 (기존 구독 삭제 후 재생성)
        // CloudKit이 중복 subscriptionID를 자동 처리하므로 안전
        let subscription = CKDatabaseSubscription(subscriptionID: Self.subscriptionID)

        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true  // silent push
        subscription.notificationInfo = info

        let op = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        op.qualityOfService = .utility
        op.modifySubscriptionsResultBlock = { result in
            switch result {
            case .success:
                print("[CloudSync] ✅ 구독 등록/갱신 완료")
            case .failure(let error):
                print("[CloudSync] ❌ 구독 등록 실패: \(error.localizedDescription)")
            }
        }
        db.add(op)
    }

    // MARK: - 로컬 I/O

    private func loadLocal() -> AppData? {
        guard let data = try? Data(contentsOf: localURL) else { return nil }
        return try? dec.decode(AppData.self, from: data)
    }

    private func saveLocal(_ data: AppData) {
        guard let json = try? enc.encode(data) else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: localDir.path) {
            try? fm.createDirectory(at: localDir, withIntermediateDirectories: true)
        }
        try? json.write(to: localURL, options: .atomic)
    }

    // MARK: - 통합 저장 (로컬 + 클라우드)

    private func writeToStores(_ data: AppData) {
        saveLocal(data)       // 즉시 로컬 기록
        uploadToCloud(data)   // 비동기 CloudKit 업로드
    }

    // MARK: - CloudKit Fetch

    private func fetchCloudAndApply(localTimestamp: Date?) {
        print("[CloudSync] 🔄 서버에서 데이터 fetch 시작...")
        db.fetch(withRecordID: CK.recordID) { [weak self] record, error in
            guard let self else { return }

            if let error = error as? CKError, error.code == .unknownItem {
                print("[CloudSync] 서버에 데이터 없음 (최초 상태)")
                return
            }

            if let error = error {
                print("[CloudSync] ❌ fetch 오류: \(error.localizedDescription)")
                return
            }

            guard let record else { return }

            // 서버 레코드 캐싱 (다음 저장 시 fetch 생략)
            self.syncQ.async { self.serverRecord = record }

            guard let remote = self.decodeRecord(record) else {
                print("[CloudSync] ❌ 서버 데이터 디코딩 실패")
                return
            }

            // 로컬보다 새로운 경우만 적용
            if let localTS = localTimestamp, remote.timestamp <= localTS {
                print("[CloudSync] ⏭️ 로컬이 최신 (local: \(localTS), remote: \(remote.timestamp))")
                return
            }

            print("[CloudSync] ✅ 서버 데이터 적용 (timestamp: \(remote.timestamp))")
            self.saveLocal(remote)
            DispatchQueue.main.async { self.onChange?(remote) }
        }
    }

    // MARK: - CloudKit Upload (충돌 해결 포함)

    private func uploadToCloud(_ data: AppData, retryCount: Int = 0) {
        syncQ.async { [weak self] in
            guard let self else { return }

            if self.serverRecord != nil {
                // 캐시된 레코드가 있으면 재사용 (change tag 유지)
                let record = self.serverRecord!
                self.encodeIntoRecord(data, record: record)
                self.performUpload(record: record, data: data, retryCount: retryCount)
            } else {
                // 캐시 없음 → 먼저 서버에서 기존 레코드를 fetch 후 업데이트
                self.db.fetch(withRecordID: CK.recordID) { [weak self] record, error in
                    guard let self else { return }
                    self.syncQ.async {
                        let rec: CKRecord
                        if let existing = record {
                            self.serverRecord = existing
                            rec = existing
                        } else {
                            rec = CKRecord(recordType: CK.recordType, recordID: CK.recordID)
                        }
                        self.encodeIntoRecord(data, record: rec)
                        self.performUpload(record: rec, data: data, retryCount: retryCount)
                    }
                }
            }
        }
    }

    private func performUpload(record: CKRecord, data: AppData, retryCount: Int) {
        let op = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        op.savePolicy = .ifServerRecordUnchanged
        op.qualityOfService = .utility

        op.perRecordSaveBlock = { [weak self] _, result in
            switch result {
            case .success(let saved):
                self?.syncQ.async { self?.serverRecord = saved }
                print("[CloudSync] ✅ 업로드 성공 (timestamp: \(data.timestamp))")
            case .failure(let error):
                print("[CloudSync] ❌ 레코드 저장 실패: \(error.localizedDescription)")
            }
        }

        op.modifyRecordsResultBlock = { [weak self] result in
            if case .failure(let error) = result {
                self?.handleUploadError(error, data: data, retryCount: retryCount)
            }
        }

        self.db.add(op)
    }

    private func handleUploadError(_ error: Error, data: AppData, retryCount: Int) {
        guard let ckError = error as? CKError else {
            print("[CloudSync] 알 수 없는 오류: \(error)")
            return
        }

        switch ckError.code {

        case .serverRecordChanged:
            // 충돌: 서버에 더 새로운 레코드가 있음
            guard let serverRec = ckError.serverRecord else { return }

            syncQ.async { [weak self] in self?.serverRecord = serverRec }

            let serverTS = serverRec[CK.tsField] as? Date ?? .distantPast

            if data.timestamp >= serverTS {
                // 우리 데이터가 더 새로움 → 서버 레코드에 덮어쓰고 재시도
                print("[CloudSync] 충돌 해결: 로컬이 더 새로움, 덮어씁니다")
                encodeIntoRecord(data, record: serverRec)
                uploadToCloud(data, retryCount: retryCount + 1)
            } else {
                // 서버 데이터가 더 새로움 → 서버 버전 수용
                print("[CloudSync] 충돌 해결: 서버가 더 새로움, 적용합니다")
                if let remote = decodeRecord(serverRec) {
                    saveLocal(remote)
                    DispatchQueue.main.async { [weak self] in self?.onChange?(remote) }
                }
            }

        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited:
            guard retryCount < 5 else {
                print("[CloudSync] 재시도 횟수 초과, 포기합니다")
                return
            }
            let delay = pow(2.0, Double(retryCount)) // 1, 2, 4, 8, 16초
            print("[CloudSync] 네트워크 오류, \(delay)초 후 재시도 (\(retryCount + 1)/5)")
            DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.uploadToCloud(data, retryCount: retryCount + 1)
            }

        case .notAuthenticated:
            print("[CloudSync] iCloud에 로그인되지 않았습니다")

        case .quotaExceeded:
            print("[CloudSync] iCloud 저장 공간 부족")

        default:
            print("[CloudSync] 저장 오류 (\(ckError.code.rawValue)): \(ckError.localizedDescription)")
        }
    }

    // MARK: - CKRecord ↔ AppData 변환

    private func encodeIntoRecord(_ data: AppData, record: CKRecord) {
        guard let json = try? enc.encode(data),
              let str  = String(data: json, encoding: .utf8) else { return }
        record[CK.jsonField] = str
        record[CK.tsField]   = data.timestamp as CKRecordValue
    }

    private func decodeRecord(_ record: CKRecord) -> AppData? {
        guard let str  = record[CK.jsonField] as? String,
              let json = str.data(using: .utf8) else { return nil }
        return try? dec.decode(AppData.self, from: json)
    }

    // MARK: - 계정 변경

    @objc private func accountChanged() {
        // 계정이 바뀌면 캐시 무효화 후 재동기화
        syncQ.async { [weak self] in self?.serverRecord = nil }
        fetchCloudAndApply(localTimestamp: loadLocal()?.timestamp)
    }
}
