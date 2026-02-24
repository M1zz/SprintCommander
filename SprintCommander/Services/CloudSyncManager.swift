import Foundation
import CloudKit
import Combine

final class CloudSyncManager {
    // MARK: - Constants
    
    private static let recordType = "AppData"
    private static let recordID = CKRecord.ID(recordName: "MainAppData")
    private static let jsonKey = "jsonData"
    private static let timestampKey = "timestamp"
    private static let localFileName = "SprintCommanderData.json"
    private static let subscriptionID = "AppDataChanges"
    
    // MARK: - Properties
    
    private let container: CKContainer
    private let database: CKDatabase
    
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
    
    private var onChange: ((AppData) -> Void)?
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<AppData, Never>()
    
    // MARK: - Local Cache Path
    
    private var localDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SprintCommander")
    }
    
    private var localURL: URL {
        localDir.appendingPathComponent(Self.localFileName)
    }
    
    // MARK: - Init
    
    init() {
        self.container = CKContainer(identifier: "iCloud.com.leeo.SprintCommander")
        self.database = container.privateCloudDatabase
        
        saveCancellable = saveSubject
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] data in
                self?.writeToStores(data)
            }
    }
    
    // MARK: - Save
    
    func save(_ data: AppData) {
        saveSubject.send(data)
    }
    
    func saveImmediately(_ data: AppData) {
        writeToStores(data)
    }
    
    private func writeToStores(_ data: AppData) {
        // 1. Save locally first (for offline support)
        saveToLocal(data)
        
        // 2. Save to CloudKit
        saveToCloud(data)
    }
    
    private func saveToLocal(_ data: AppData) {
        guard let jsonData = try? encoder.encode(data) else { return }
        
        let fm = FileManager.default
        if !fm.fileExists(atPath: localDir.path) {
            try? fm.createDirectory(at: localDir, withIntermediateDirectories: true)
        }
        try? jsonData.write(to: localURL, options: .atomic)
    }
    
    private func saveToCloud(_ data: AppData) {
        guard let jsonData = try? encoder.encode(data),
              let jsonString = String(data: jsonData, encoding: .utf8) else { return }
        
        // Fetch existing record or create new
        database.fetch(withRecordID: Self.recordID) { [weak self] existingRecord, error in
            guard let self = self else { return }
            
            let record: CKRecord
            if let existing = existingRecord {
                record = existing
            } else {
                record = CKRecord(recordType: Self.recordType, recordID: Self.recordID)
            }
            
            record[Self.jsonKey] = jsonString
            record[Self.timestampKey] = data.timestamp
            
            self.database.save(record) { _, error in
                if let error = error {
                    print("[CloudSync] Save error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Load
    
    func load() -> AppData? {
        // Load from local cache first (fast)
        let localData = loadFromLocal()
        
        // Async fetch from cloud and update if newer
        fetchFromCloud { [weak self] cloudData in
            guard let self = self,
                  let cloud = cloudData else { return }
            
            let local = self.loadFromLocal()
            if local == nil || cloud.timestamp > local!.timestamp {
                self.saveToLocal(cloud)
                DispatchQueue.main.async {
                    self.onChange?(cloud)
                }
            }
        }
        
        return localData
    }
    
    private func loadFromLocal() -> AppData? {
        guard let data = try? Data(contentsOf: localURL) else { return nil }
        return try? decoder.decode(AppData.self, from: data)
    }
    
    private func fetchFromCloud(completion: @escaping (AppData?) -> Void) {
        database.fetch(withRecordID: Self.recordID) { [weak self] record, error in
            guard let self = self,
                  let record = record,
                  let jsonString = record[Self.jsonKey] as? String,
                  let jsonData = jsonString.data(using: .utf8),
                  let appData = try? self.decoder.decode(AppData.self, from: jsonData) else {
                completion(nil)
                return
            }
            completion(appData)
        }
    }
    
    // MARK: - Monitoring (CloudKit Subscription)
    
    func startMonitoring(onChange: @escaping (AppData) -> Void) {
        self.onChange = onChange
        
        // Register for silent push notifications
        setupSubscription()
        
        // Also observe CKAccountChanged for login/logout
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(accountChanged),
            name: .CKAccountChanged,
            object: nil
        )
        
        // Initial fetch to sync
        fetchFromCloud { [weak self] cloudData in
            guard let self = self,
                  let cloud = cloudData else { return }
            
            let local = self.loadFromLocal()
            if local == nil || cloud.timestamp > local!.timestamp {
                self.saveToLocal(cloud)
                DispatchQueue.main.async {
                    onChange(cloud)
                }
            }
        }
    }
    
    func stopMonitoring() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupSubscription() {
        // Check if subscription exists
        database.fetch(withSubscriptionID: Self.subscriptionID) { [weak self] subscription, error in
            guard let self = self else { return }
            
            if subscription == nil {
                // Create subscription for changes
                let subscription = CKQuerySubscription(
                    recordType: Self.recordType,
                    predicate: NSPredicate(value: true),
                    subscriptionID: Self.subscriptionID,
                    options: [.firesOnRecordUpdate, .firesOnRecordCreation]
                )
                
                let notificationInfo = CKSubscription.NotificationInfo()
                notificationInfo.shouldSendContentAvailable = true
                subscription.notificationInfo = notificationInfo
                
                self.database.save(subscription) { _, error in
                    if let error = error {
                        print("[CloudSync] Subscription error: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    @objc private func accountChanged() {
        // Re-fetch when account changes
        fetchFromCloud { [weak self] cloudData in
            guard let self = self,
                  let cloud = cloudData else { return }
            
            self.saveToLocal(cloud)
            DispatchQueue.main.async {
                self.onChange?(cloud)
            }
        }
    }
    
    // MARK: - Handle Remote Notification
    
    func handleRemoteNotification(userInfo: [String: Any], completion: @escaping () -> Void) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == Self.subscriptionID else {
            completion()
            return
        }
        
        fetchFromCloud { [weak self] cloudData in
            defer { completion() }
            
            guard let self = self,
                  let cloud = cloudData else { return }
            
            let local = self.loadFromLocal()
            if local == nil || cloud.timestamp > local!.timestamp {
                self.saveToLocal(cloud)
                DispatchQueue.main.async {
                    self.onChange?(cloud)
                }
            }
        }
    }
}
