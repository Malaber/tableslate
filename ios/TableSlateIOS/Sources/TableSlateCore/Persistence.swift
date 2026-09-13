import Foundation

public struct PersistenceLoadResult: Sendable {
    public var data: AppData
    public var recoveryCopy: URL?

    public init(data: AppData, recoveryCopy: URL? = nil) {
        self.data = data
        self.recoveryCopy = recoveryCopy
    }
}

public struct AppDataStore {
    public let fileURL: URL
    private let fileManager: FileManager
    private let now: () -> Date

    public init(fileURL: URL, fileManager: FileManager = .default, now: @escaping () -> Date = Date.init) {
        self.fileURL = fileURL
        self.fileManager = fileManager
        self.now = now
    }

    public static func applicationSupport(
        baseDirectory: URL,
        fileManager: FileManager = .default
    ) throws -> AppDataStore {
        let directory = baseDirectory.appendingPathComponent("TableSlate", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return AppDataStore(fileURL: directory.appendingPathComponent("app-data.json"), fileManager: fileManager)
    }

    public func load() -> PersistenceLoadResult {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return PersistenceLoadResult(data: AppData())
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let appData = try decoder.decode(AppData.self, from: data)
            guard appData.schemaVersion <= AppData.currentSchemaVersion else {
                throw PersistenceError.unsupportedSchema(appData.schemaVersion)
            }
            return PersistenceLoadResult(data: migrate(appData))
        } catch {
            let stamp = ISO8601DateFormatter().string(from: now()).replacingOccurrences(of: ":", with: "-")
            let recoveryURL = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(stamp).json")
            do {
                try fileManager.copyItem(at: fileURL, to: recoveryURL)
                return PersistenceLoadResult(data: AppData(), recoveryCopy: recoveryURL)
            } catch {
                return PersistenceLoadResult(data: AppData())
            }
        }
    }

    public func save(_ appData: AppData) throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(appData).write(to: fileURL, options: .atomic)
    }

    private func migrate(_ appData: AppData) -> AppData {
        var migrated = appData
        migrated.schemaVersion = AppData.currentSchemaVersion
        return migrated
    }
}

private enum PersistenceError: Error {
    case unsupportedSchema(Int)
}
