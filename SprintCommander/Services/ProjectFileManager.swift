import Foundation

/// 프로젝트 소스 디렉토리 안에 .sprintcommander/ 폴더를 만들어 데이터 저장.
/// 외부 AI가 해당 프로젝트를 열면 바로 tasks.json을 읽고 수정할 수 있음.
///
/// 파일 구조 (각 프로젝트 소스 디렉토리 내):
///   /Documents/workspace/code/ClipKeyboard/
///   └── .sprintcommander/
///       ├── _schema.json     ← AI 참고용 스키마
///       ├── project.json     ← 프로젝트 메타
///       └── tasks.json       ← 칸반 태스크 배열 (AI가 수정)

final class ProjectFileManager {

    private static let dirName = ".sprintcommander"

    // MARK: - Callbacks

    /// 외부에서 tasks.json이 수정되었을 때 호출 (projectId, 새 태스크 배열)
    var onExternalTasksChange: ((UUID, [TaskItem]) -> Void)?
    
    /// 외부에서 project.json이 수정되었을 때 호출 (projectId, 업데이트된 필드들)
    var onExternalProjectChange: ((UUID, ProjectPatch) -> Void)?

    // MARK: - Internal state

    private var watchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var lastWriteDates: [UUID: Date] = [:]
    private var lastProjectWriteDates: [UUID: Date] = [:]

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

    // MARK: - Public: Save

    /// 모든 프로젝트의 파일을 일괄 저장 (sourcePath가 있는 프로젝트만)
    func saveAll(projects: [Project], tasks: [TaskItem]) {
        for project in projects {
            guard !project.sourcePath.isEmpty else { continue }
            let projectTasks = tasks.filter { $0.projectId == project.id }
            save(project: project, tasks: projectTasks)
        }
    }

    /// 단일 프로젝트 저장
    func save(project: Project, tasks: [TaskItem]) {
        guard let dir = sprintDir(for: project) else { return }

        // project.json
        if let data = try? enc.encode(project) {
            try? data.write(to: dir.appendingPathComponent("project.json"), options: .atomic)
            lastProjectWriteDates[project.id] = Date()
        }

        // tasks.json
        if let data = try? enc.encode(tasks) {
            let url = dir.appendingPathComponent("tasks.json")
            try? data.write(to: url, options: .atomic)
            lastWriteDates[project.id] = Date()
        }

        // _schema.json (한 번만 생성)
        let schemaURL = dir.appendingPathComponent("_schema.json")
        if !FileManager.default.fileExists(atPath: schemaURL.path) {
            writeSchema(to: dir, project: project)
        }
    }

    // MARK: - Public: Load

    func loadTasks(for project: Project) -> [TaskItem]? {
        guard let dir = sprintDir(for: project) else { return nil }
        let url = dir.appendingPathComponent("tasks.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? dec.decode([TaskItem].self, from: data)
    }

    func loadProject(for project: Project) -> ProjectPatch? {
        guard let dir = sprintDir(for: project) else { return nil }
        let url = dir.appendingPathComponent("project.json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? dec.decode(ProjectPatch.self, from: data)
    }

    // MARK: - Public: File Watching

    func startWatchingAll(projects: [Project]) {
        stopAll()
        for project in projects {
            startWatching(project: project)
        }
    }

    func startWatching(project: Project) {
        guard let dir = sprintDir(for: project) else { return }

        // tasks.json이 없으면 빈 배열로 생성
        let tasksURL = dir.appendingPathComponent("tasks.json")
        if !FileManager.default.fileExists(atPath: tasksURL.path) {
            try? enc.encode([TaskItem]()).write(to: tasksURL, options: .atomic)
            lastWriteDates[project.id] = Date()
        }

        let fd = open(dir.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename],
            queue: .global(qos: .utility)
        )

        let projectId = project.id
        let dirURL = dir

        source.setEventHandler { [weak self] in
            guard let self else { return }
            Thread.sleep(forTimeInterval: 0.3)
            self.checkForExternalChange(projectId: projectId, dir: dirURL)
        }

        source.setCancelHandler { close(fd) }
        source.resume()

        watchers[project.id] = source
    }

    func stopAll() {
        watchers.values.forEach { $0.cancel() }
        watchers.removeAll()
    }

    // MARK: - Private helpers

    /// 프로젝트 소스 경로 내 .sprintcommander/ 디렉토리 URL 반환
    private func sprintDir(for project: Project) -> URL? {
        guard !project.sourcePath.isEmpty else { return nil }
        let sourceURL = URL(fileURLWithPath: project.sourcePath)
        guard FileManager.default.fileExists(atPath: project.sourcePath) else { return nil }

        let dir = sourceURL.appendingPathComponent(Self.dirName)
        ensureDir(dir)
        return dir
    }

    private func ensureDir(_ url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }

    private func checkForExternalChange(projectId: UUID, dir: URL) {
        // tasks.json 체크
        let tasksURL = dir.appendingPathComponent("tasks.json")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: tasksURL.path),
           let mtime = attrs[.modificationDate] as? Date {
            let lastWrite = lastWriteDates[projectId] ?? .distantPast
            if mtime.timeIntervalSince(lastWrite) >= 0.5,
               let data = try? Data(contentsOf: tasksURL),
               let tasks = try? dec.decode([TaskItem].self, from: data) {
                print("[ProjectFiles] 외부 변경 감지 (tasks): \(dir.deletingLastPathComponent().lastPathComponent) (\(tasks.count)개 태스크)")
                DispatchQueue.main.async { [weak self] in
                    self?.onExternalTasksChange?(projectId, tasks)
                }
            }
        }

        // project.json 체크
        let projectURL = dir.appendingPathComponent("project.json")
        if let attrs = try? FileManager.default.attributesOfItem(atPath: projectURL.path),
           let mtime = attrs[.modificationDate] as? Date {
            let lastWrite = lastProjectWriteDates[projectId] ?? .distantPast
            if mtime.timeIntervalSince(lastWrite) >= 0.5,
               let data = try? Data(contentsOf: projectURL),
               let patch = try? dec.decode(ProjectPatch.self, from: data) {
                print("[ProjectFiles] 외부 변경 감지 (project): \(dir.deletingLastPathComponent().lastPathComponent)")
                DispatchQueue.main.async { [weak self] in
                    self?.onExternalProjectChange?(projectId, patch)
                }
            }
        }
    }

    // MARK: - Schema

    private func writeSchema(to dir: URL, project: Project) {
        let schema: [String: Any] = [
            "_description": "SprintCommander 프로젝트 데이터",
            "_note": "tasks.json과 project.json을 수정하면 SprintCommander 앱에 자동 반영됩니다.",
            "_project": project.name,
            "_projectId": project.id.uuidString,
            "task_fields": [
                "id": "UUID string (새 태스크 생성 시 새 UUID 필요, 예: UUID().uuidString)",
                "projectId": "\(project.id.uuidString) (이 프로젝트의 ID, 반드시 이 값 사용)",
                "title": "string - 태스크 제목",
                "tags": "string[] - [\"Feature\", \"UI\", \"Backend\", \"Bug\", \"Core\", \"Performance\", \"Refactor\", \"Design\", \"iOS\"]",
                "priority": "string - high | medium | low",
                "storyPoints": "integer - 스토리 포인트 (1, 2, 3, 5, 8, 13)",
                "assignee": "string - 2글자 이니셜 (예: JK)",
                "assigneeColorHex": "string - 6자리 hex 색상 (예: 4FACFE, 34D399, A78BFA, FB923C)",
                "status": "string - 백로그 | 할 일 | 진행 중 | 완료"
            ],
            "project_fields": [
                "id": "\(project.id.uuidString) (변경 불가, 필수 포함)",
                "name": "string - 프로젝트 이름",
                "icon": "string - 이모지 아이콘",
                "desc": "string - 프로젝트 설명",
                "version": "string - 앱 버전 (예: 1.0.5)",
                "landingURL": "string - 랜딩 페이지 URL",
                "appStoreURL": "string - 앱스토어 링크",
                "pricing": [
                    "downloadPrice": "string - 다운로드 가격 (예: 무료, $4.99)",
                    "monthlyPrice": "string - 월 구독가",
                    "yearlyPrice": "string - 연 구독가",
                    "lifetimePrice": "string - 평생 구매가"
                ] as [String: String],
                "languages": "string[] - 지원 언어 코드 (예: [\"ko\", \"en\", \"ja\"])"
            ] as [String: Any],
            "task_example": [
                "id": "550e8400-e29b-41d4-a716-446655440000",
                "projectId": project.id.uuidString,
                "title": "예시 태스크",
                "tags": ["Feature", "Backend"],
                "priority": "high",
                "storyPoints": 5,
                "assignee": "JK",
                "assigneeColorHex": "4FACFE",
                "status": "백로그"
            ] as [String: Any],
            "usage": [
                "tasks.json 수정:",
                "  1. tasks.json 파일을 읽으세요",
                "  2. 태스크를 추가/수정/삭제하세요",
                "  3. 저장하면 SprintCommander 앱에 자동 반영됩니다",
                "",
                "project.json 수정:",
                "  1. project.json 파일을 읽으세요",
                "  2. 위 project_fields 중 원하는 필드를 수정하세요",
                "  3. id는 반드시 포함하고 변경하지 마세요",
                "  4. 저장하면 SprintCommander 앱에 자동 반영됩니다"
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("_schema.json"), options: .atomic)
        }
    }
}
