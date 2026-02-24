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

    // MARK: - Internal state

    private var watchers: [UUID: DispatchSourceFileSystemObject] = [:]
    private var lastWriteDates: [UUID: Date] = [:]

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
        let tasksURL = dir.appendingPathComponent("tasks.json")

        guard let attrs = try? FileManager.default.attributesOfItem(atPath: tasksURL.path),
              let mtime = attrs[.modificationDate] as? Date else { return }

        // 우리가 마지막으로 쓴 시점 이후인지 확인 (0.5초 마진)
        if let lastWrite = lastWriteDates[projectId],
           mtime.timeIntervalSince(lastWrite) < 0.5 { return }

        guard let data = try? Data(contentsOf: tasksURL),
              let tasks = try? dec.decode([TaskItem].self, from: data) else { return }

        print("[ProjectFiles] 외부 변경 감지: \(dir.deletingLastPathComponent().lastPathComponent) (\(tasks.count)개 태스크)")
        DispatchQueue.main.async { [weak self] in
            self?.onExternalTasksChange?(projectId, tasks)
        }
    }

    // MARK: - Schema

    private func writeSchema(to dir: URL, project: Project) {
        let schema: [String: Any] = [
            "_description": "SprintCommander 프로젝트 데이터",
            "_note": "tasks.json을 수정하면 SprintCommander 앱에 자동 반영됩니다.",
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
            "example": [
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
                "1. tasks.json 파일을 읽으세요",
                "2. 태스크를 추가/수정/삭제하세요",
                "3. 저장하면 SprintCommander 앱에 자동 반영됩니다",
                "4. 새 태스크의 id는 새 UUID를, projectId는 \(project.id.uuidString)를 사용하세요"
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: schema, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: dir.appendingPathComponent("_schema.json"), options: .atomic)
        }
    }
}
