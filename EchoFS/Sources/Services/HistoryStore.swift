import Foundation
import GRDB
import os.log

/// SQLite-backed transcript history store using GRDB.
final class HistoryStore: ObservableObject {
    private static let logger = Logger(subsystem: "com.echo-fs", category: "HistoryStore")

    @Published var items: [TranscriptItem] = []

    private var dbQueue: DatabaseQueue?

    init() {
        do {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbDir = appSupport.appendingPathComponent("echo-fs", isDirectory: true)
            try FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
            let dbPath = dbDir.appendingPathComponent("history.sqlite3").path

            dbQueue = try DatabaseQueue(path: dbPath)
            try migrate()
        } catch {
            Self.logger.error("Failed to open database: \(error.localizedDescription)")
        }
    }

    func save(_ item: TranscriptItem) {
        guard let dbQueue else { return }

        do {
            try dbQueue.write { db in
                var record = TranscriptRecord(item: item)
                try record.insert(db)
            }
            DispatchQueue.main.async {
                self.items.insert(item, at: 0)
            }
        } catch {
            Self.logger.error("Failed to insert transcript: \(error.localizedDescription)")
        }
    }

    func list(limit: Int = 50) -> [TranscriptItem] {
        guard let dbQueue else { return [] }

        do {
            return try dbQueue.read { db in
                let records = try TranscriptRecord
                    .order(Column("createdAt").desc)
                    .limit(limit)
                    .fetchAll(db)
                return records.map { $0.toTranscriptItem() }
            }
        } catch {
            Self.logger.error("Failed to list transcripts: \(error.localizedDescription)")
            return []
        }
    }

    func clearAll() {
        guard let dbQueue else { return }

        do {
            try dbQueue.write { db in
                try TranscriptRecord.deleteAll(db)
            }
            DispatchQueue.main.async {
                self.items.removeAll()
            }
            Self.logger.info("History cleared")
        } catch {
            Self.logger.error("Failed to clear history: \(error.localizedDescription)")
        }
    }

    func loadItems() {
        items = list()
    }

    // MARK: - Migration

    private func migrate() throws {
        guard let dbQueue else { return }

        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "transcriptRecord", ifNotExists: true) { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .double).notNull().indexed()
                t.column("textRaw", .text).notNull()
                t.column("textProcessed", .text).notNull()
                t.column("sourceAppBundleID", .text)
                t.column("modelID", .text).notNull()
                t.column("latencyMs", .integer).notNull().defaults(to: 0)
            }
        }
        try migrator.migrate(dbQueue)
    }
}

// MARK: - GRDB Record

/// GRDB-compatible record type that maps to/from TranscriptItem.
struct TranscriptRecord: Codable, FetchableRecord, PersistableRecord {
    var id: String
    var createdAt: Double
    var textRaw: String
    var textProcessed: String
    var sourceAppBundleID: String?
    var modelID: String
    var latencyMs: Int

    init(item: TranscriptItem) {
        self.id = item.id.uuidString
        self.createdAt = item.createdAt.timeIntervalSince1970
        self.textRaw = item.textRaw
        self.textProcessed = item.textProcessed
        self.sourceAppBundleID = item.sourceAppBundleID
        self.modelID = item.modelID
        self.latencyMs = item.latencyMs
    }

    func toTranscriptItem() -> TranscriptItem {
        TranscriptItem(
            id: UUID(uuidString: id) ?? UUID(),
            createdAt: Date(timeIntervalSince1970: createdAt),
            textRaw: textRaw,
            textProcessed: textProcessed,
            sourceAppBundleID: sourceAppBundleID,
            modelID: modelID,
            latencyMs: latencyMs
        )
    }
}
