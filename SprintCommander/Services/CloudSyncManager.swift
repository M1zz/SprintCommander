import Foundation
import Combine

final class CloudSyncManager {
    static let fileName = "SprintCommanderData.json"

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

    private var metadataQuery: NSMetadataQuery?
    private var onChange: ((AppData) -> Void)?
    private var saveCancellable: AnyCancellable?
    private let saveSubject = PassthroughSubject<AppData, Never>()

    // MARK: - Paths

    private var localDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("SprintCommander")
    }

    private var localURL: URL {
        localDir.appendingPathComponent(Self.fileName)
    }

    private var cloudURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent(Self.fileName)
    }

    // MARK: - Init / Deinit

    init() {
        saveCancellable = saveSubject
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] data in
                self?.writeToStores(data)
            }
    }

    deinit {
        stopMonitoring()
    }

    // MARK: - Save (debounced)

    func save(_ data: AppData) {
        saveSubject.send(data)
    }

    func saveImmediately(_ data: AppData) {
        writeToStores(data)
    }

    private func writeToStores(_ data: AppData) {
        guard let jsonData = try? encoder.encode(data) else { return }

        // Local
        let fm = FileManager.default
        if !fm.fileExists(atPath: localDir.path) {
            try? fm.createDirectory(at: localDir, withIntermediateDirectories: true)
        }
        try? jsonData.write(to: localURL, options: .atomic)

        // iCloud
        if let url = cloudURL {
            let dir = url.deletingLastPathComponent()
            if !fm.fileExists(atPath: dir.path) {
                try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try? jsonData.write(to: url, options: .atomic)
        }
    }

    // MARK: - Load (latest wins)

    func load() -> AppData? {
        let localData = loadFrom(localURL)
        let cloudData = cloudURL.flatMap { loadFrom($0) }

        switch (localData, cloudData) {
        case let (local?, cloud?):
            return local.timestamp >= cloud.timestamp ? local : cloud
        case let (local?, nil):
            return local
        case let (nil, cloud?):
            return cloud
        case (nil, nil):
            return nil
        }
    }

    private func loadFrom(_ url: URL) -> AppData? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AppData.self, from: data)
    }

    // MARK: - iCloud Monitoring

    func startMonitoring(onChange: @escaping (AppData) -> Void) {
        self.onChange = onChange

        // Try downloading cloud file if it exists
        if let url = cloudURL {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }

        let query = NSMetadataQuery()
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, Self.fileName)
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(metadataQueryDidUpdate),
            name: .NSMetadataQueryDidUpdate,
            object: query
        )

        query.start()
        metadataQuery = query
    }

    func stopMonitoring() {
        metadataQuery?.stop()
        metadataQuery = nil
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func metadataQueryDidUpdate() {
        guard let url = cloudURL,
              let cloudData = loadFrom(url) else { return }

        let localData = loadFrom(localURL)
        if localData == nil || cloudData.timestamp > localData!.timestamp {
            // Cloud is newer – update local copy
            if let jsonData = try? encoder.encode(cloudData) {
                try? jsonData.write(to: localURL, options: .atomic)
            }
            DispatchQueue.main.async { [weak self] in
                self?.onChange?(cloudData)
            }
        }
    }
}
