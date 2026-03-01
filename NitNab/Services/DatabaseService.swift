//
//  DatabaseService.swift
//  NitNab
//
//  SQLite database for tracking transcriptions
//

import Foundation
import SQLite3

// File-scope constant — no actor isolation needed for a constant value
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor DatabaseService {

    static let shared = DatabaseService()

    private var db: OpaquePointer?
    private let dbPath: URL
    private let logFileURL: URL
    private let ubiquitousContainerID: String
    private var isInitialized = false
    private let transcriptionsSelectColumns = """
    id, folder_name, folder_path, audio_filename, audio_path, audio_format, transcript_path, transcript_text, summary_path, chat_path, duration, file_size, word_count, character_count, confidence, language, created_at, completed_at, status, progress, error, custom_name, description, company_id, attendee_ids, speakers, tags, modified_at, file_checksum
    """

    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"

        // Write to log file
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    try? fileHandle.close()
                }
            } else {
                try? data.write(to: logFileURL)
            }
        }
    }

    private init() {
        self.ubiquitousContainerID = "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.nitnab")"

        // Setup log file in temp directory
        let tempDir = FileManager.default.temporaryDirectory
        self.logFileURL = tempDir.appendingPathComponent("nitnab_db_debug.log")

        // Store database in app's container
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: ubiquitousContainerID) {
            let dbFolder = iCloudURL.appendingPathComponent("Documents/NitNab")
            try? FileManager.default.createDirectory(at: dbFolder, withIntermediateDirectories: true)
            self.dbPath = dbFolder.appendingPathComponent("nitnab.db")
        } else {
            // Fallback to local
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbFolder = appSupport.appendingPathComponent("NitNab")
            try? FileManager.default.createDirectory(at: dbFolder, withIntermediateDirectories: true)
            self.dbPath = dbFolder.appendingPathComponent("nitnab.db")
        }
    }

    // MARK: - Lazy Initialization

    private func ensureInitialized() {
        guard !isInitialized else { return }
        openDatabase()
        guard db != nil else {
            log("❌ ensureInitialized: database open failed, will retry next call")
            return
        }
        createTables()
        isInitialized = true
    }

    private func openDatabase() {
        log("🔧 openDatabase() called")
        log("🔧 dbPath: \(dbPath.path)")

        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(dbPath.path, &db, flags, nil)

        if result != SQLITE_OK {
            if let db = db {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                log("❌ Error opening database at \(dbPath.path): \(errorMessage) (code: \(result))")
            } else {
                log("❌ Error opening database at \(dbPath.path): db is nil (code: \(result))")
            }
        } else {
            log("✅ Database opened successfully at \(dbPath.path)")

            // Enable WAL mode for better concurrent access
            var walStatement: OpaquePointer?
            if sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL;", -1, &walStatement, nil) == SQLITE_OK {
                sqlite3_step(walStatement)
            }
            sqlite3_finalize(walStatement)
        }
    }

    private func createTables() {
        log("🔧 createTables() called")

        let createTableSQL = """
        CREATE TABLE IF NOT EXISTS transcriptions (
            id TEXT PRIMARY KEY,
            folder_name TEXT NOT NULL UNIQUE,
            folder_path TEXT,
            audio_filename TEXT NOT NULL,
            audio_path TEXT NOT NULL,
            audio_format TEXT NOT NULL,
            transcript_path TEXT,
            transcript_text TEXT,
            summary_path TEXT,
            chat_path TEXT,
            duration REAL NOT NULL,
            file_size INTEGER NOT NULL,
            word_count INTEGER,
            character_count INTEGER,
            confidence REAL,
            language TEXT,
            created_at TEXT NOT NULL,
            completed_at TEXT,
            status TEXT NOT NULL,
            progress REAL DEFAULT 0,
            error TEXT,
            custom_name TEXT,
            description TEXT
        );
        """

        var createTableStatement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, createTableSQL, -1, &createTableStatement, nil)

        if prepareResult == SQLITE_OK {
            let stepResult = sqlite3_step(createTableStatement)
            if stepResult == SQLITE_DONE {
                log("✅ Transcriptions table created successfully")
            } else {
                log("✅ Transcriptions table already exists")
            }
        } else {
            if let db = db {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                log("❌ Failed to create table: \(errorMessage) (code: \(prepareResult))")
            } else {
                log("❌ Failed to create table: db is nil (code: \(prepareResult))")
            }
        }
        sqlite3_finalize(createTableStatement)

        // MARK: - Create Memory Tables (Chunk 1)

        log("🔧 Creating memory tables...")
        createMemoryTables()

        // Migration: Add columns that may be missing
        log("🔧 Running database migration...")
        migrateDatabase()

        log("🔧 createTables() complete")
    }

    // MARK: - Memory Tables Creation (Chunk 1)

    private func createMemoryTables() {
        // Personal profile table (single row)
        let personalProfileSQL = """
        CREATE TABLE IF NOT EXISTS personal_profile (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            user_name TEXT,
            user_role TEXT,
            user_company TEXT,
            ai_context TEXT,
            updated_at TEXT NOT NULL
        );
        """
        executeTableCreation(sql: personalProfileSQL, tableName: "personal_profile")

        // Family members table
        let familyMembersSQL = """
        CREATE TABLE IF NOT EXISTS family_members (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            relationship TEXT NOT NULL,
            notes TEXT,
            created_at TEXT NOT NULL
        );
        """
        executeTableCreation(sql: familyMembersSQL, tableName: "family_members")

        // Companies table
        let companiesSQL = """
        CREATE TABLE IF NOT EXISTS companies (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL UNIQUE,
            domain TEXT,
            notes TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
        executeTableCreation(sql: companiesSQL, tableName: "companies")

        // People table
        let peopleSQL = """
        CREATE TABLE IF NOT EXISTS people (
            id TEXT PRIMARY KEY,
            company_id TEXT NOT NULL,
            full_name TEXT NOT NULL,
            preferred_name TEXT,
            title TEXT,
            email TEXT,
            phonetic_spelling TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );
        """
        executeTableCreation(sql: peopleSQL, tableName: "people")

        // Company vocabulary table
        let vocabularySQL = """
        CREATE TABLE IF NOT EXISTS company_vocabulary (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            company_id TEXT NOT NULL,
            term TEXT NOT NULL,
            phonetic TEXT,
            UNIQUE(company_id, term),
            FOREIGN KEY (company_id) REFERENCES companies(id) ON DELETE CASCADE
        );
        """
        executeTableCreation(sql: vocabularySQL, tableName: "company_vocabulary")

        log("✅ Memory tables creation complete")
    }

    private func executeTableCreation(sql: String, tableName: String) {
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, sql, -1, &statement, nil)

        if prepareResult == SQLITE_OK {
            let stepResult = sqlite3_step(statement)
            if stepResult == SQLITE_DONE {
                log("✅ \(tableName) table created")
            } else {
                log("✅ \(tableName) table already exists")
            }
        } else {
            if let db = db {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                log("❌ Failed to create \(tableName): \(errorMessage)")
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - Non-Destructive Migration (Phase 2 fix)

    private func migrateDatabase() {
        // Get existing columns
        let existingColumns = getExistingColumns(table: "transcriptions")
        log("🔧 Migration: Found \(existingColumns.count) existing columns")

        // All columns that may need to be added, with their types and defaults
        let columnDefs: [(name: String, type: String)] = [
            ("folder_path", "TEXT"),
            ("audio_format", "TEXT DEFAULT ''"),
            ("progress", "REAL DEFAULT 0"),
            ("error", "TEXT"),
            ("custom_name", "TEXT"),
            ("description", "TEXT"),
            ("transcript_text", "TEXT"),
            ("company_id", "TEXT"),
            ("attendee_ids", "TEXT"),
            ("speakers", "TEXT"),
            ("tags", "TEXT"),
            ("modified_at", "TEXT"),
            ("file_checksum", "TEXT"),
        ]

        var addedCount = 0
        for col in columnDefs where !existingColumns.contains(col.name) {
            addColumn(table: "transcriptions", name: col.name, type: col.type)
            addedCount += 1
        }

        if addedCount > 0 {
            log("✅ Migration: Added \(addedCount) missing columns")
        } else {
            log("✅ Migration: Schema is up to date")
        }
    }

    private func getExistingColumns(table: String) -> Set<String> {
        let checkColumnSQL = "PRAGMA table_info(\(table));"
        var statement: OpaquePointer?
        var columns = Set<String>()

        if sqlite3_prepare_v2(db, checkColumnSQL, -1, &statement, nil) == SQLITE_OK {
            while sqlite3_step(statement) == SQLITE_ROW {
                if let columnName = sqlite3_column_text(statement, 1) {
                    columns.insert(String(cString: columnName))
                }
            }
        }
        sqlite3_finalize(statement)
        return columns
    }

    private func addColumn(table: String, name: String, type: String) {
        let alterSQL = "ALTER TABLE \(table) ADD COLUMN \(name) \(type);"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, alterSQL, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) == SQLITE_DONE {
                log("✅ Added column \(table).\(name)")
            } else {
                if let db = db {
                    let errorMessage = String(cString: sqlite3_errmsg(db))
                    log("❌ Failed to add column \(table).\(name): \(errorMessage)")
                }
            }
        }
        sqlite3_finalize(statement)
    }

    // MARK: - JSON Helpers (Chunk 1 - Task 1.5)

    /// Encode an array to JSON string for database storage
    private func encodeToJSON<T: Encodable>(_ value: T) -> String? {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(value),
              let jsonString = String(data: data, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }

    /// Decode a JSON string from database to Swift array
    private func decodeFromJSON<T: Decodable>(_ json: String?) -> T? {
        guard let json = json,
              let data = json.data(using: .utf8) else {
            return nil
        }
        let decoder = JSONDecoder()
        return try? decoder.decode(T.self, from: data)
    }

    /// Encode UUID array to JSON string
    private func encodeUUIDs(_ uuids: [UUID]?) -> String? {
        guard let uuids = uuids else { return nil }
        let uuidStrings = uuids.map { $0.uuidString }
        return encodeToJSON(uuidStrings)
    }

    /// Decode JSON string to UUID array
    private func decodeUUIDs(_ json: String?) -> [UUID]? {
        guard let uuidStrings: [String] = decodeFromJSON(json) else { return nil }
        return uuidStrings.compactMap { UUID(uuidString: $0) }
    }

    /// Encode string array to JSON
    private func encodeStringArray(_ strings: [String]?) -> String? {
        guard let strings = strings else { return nil }
        return encodeToJSON(strings)
    }

    /// Decode JSON to string array
    private func decodeStringArray(_ json: String?) -> [String]? {
        return decodeFromJSON(json)
    }

    // MARK: - Insert/Update

    func insertTranscription(_ job: TranscriptionJob, folderName: String, audioPath: String) async throws {
        ensureInitialized()
        log("🔧 insertTranscription() called")
        log("🔧 job.id: \(job.id)")
        log("🔧 folderName: \(folderName)")
        log("🔧 audioPath: \(audioPath)")

        guard db != nil else {
            log("❌ Database not initialized!")
            throw DatabaseError.notInitialized
        }

        let insertSQL = """
        INSERT OR REPLACE INTO transcriptions
        (id, folder_name, folder_path, audio_filename, audio_path, audio_format, duration, file_size, language, created_at, status, progress, custom_name, description, file_checksum)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """

        log("🔧 Preparing INSERT statement...")
        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil)

        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ Failed to prepare INSERT statement: \(errorMessage) (code: \(prepareResult))")
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, job.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, folderName, -1, sqliteTransient)

        if let folderPath = job.folderPath {
            sqlite3_bind_text(statement, 3, folderPath, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 3)
        }

        sqlite3_bind_text(statement, 4, job.audioFile.filename, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, audioPath, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, job.audioFile.format, -1, sqliteTransient)
        sqlite3_bind_double(statement, 7, job.audioFile.duration)
        sqlite3_bind_int64(statement, 8, job.audioFile.fileSize)
        sqlite3_bind_text(statement, 9, "en-US", -1, sqliteTransient) // Default language
        sqlite3_bind_text(statement, 10, ISO8601DateFormatter().string(from: job.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 11, job.status.rawValue, -1, sqliteTransient)
        sqlite3_bind_double(statement, 12, job.progress)

        if let customName = job.customName {
            sqlite3_bind_text(statement, 13, customName, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 13)
        }

        if let desc = job.description {
            sqlite3_bind_text(statement, 14, desc, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 14)
        }

        if let checksum = job.fileChecksum {
            sqlite3_bind_text(statement, 15, checksum, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 15)
        }

        log("🔧 Executing INSERT...")
        let stepResult = sqlite3_step(statement)

        guard stepResult == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ INSERT failed: \(errorMessage) (code: \(stepResult))")
            throw DatabaseError.insertFailed
        }
        log("✅ INSERT executed successfully")
    }

    func updateJob(_ job: TranscriptionJob) async throws {
        ensureInitialized()
        guard db != nil else {
            throw DatabaseError.notInitialized
        }

        let updateSQL = """
        UPDATE transcriptions SET
            folder_path = ?,
            status = ?,
            progress = ?,
            error = ?,
            completed_at = ?,
            custom_name = ?,
            description = ?,
            transcript_text = ?,
            word_count = ?,
            character_count = ?,
            confidence = ?,
            language = ?,
            company_id = ?,
            file_checksum = ?
        WHERE id = ?;
        """

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("Failed to prepare UPDATE statement: \(errorMessage) (code: \(prepareResult))")
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        if let folderPath = job.folderPath {
            sqlite3_bind_text(statement, 1, folderPath, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 1)
        }

        sqlite3_bind_text(statement, 2, job.status.rawValue, -1, sqliteTransient)
        sqlite3_bind_double(statement, 3, job.progress)

        if let error = job.error {
            sqlite3_bind_text(statement, 4, error, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 4)
        }

        if let completedAt = job.completedAt {
            sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: completedAt), -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 5)
        }

        if let customName = job.customName {
            sqlite3_bind_text(statement, 6, customName, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 6)
        }

        if let desc = job.description {
            sqlite3_bind_text(statement, 7, desc, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 7)
        }

        if let result = job.result {
            sqlite3_bind_text(statement, 8, result.fullTranscript, -1, sqliteTransient)
            sqlite3_bind_int(statement, 9, Int32(result.wordCount))
            sqlite3_bind_int(statement, 10, Int32(result.characterCount))
            sqlite3_bind_double(statement, 11, result.confidence)
            sqlite3_bind_text(statement, 12, result.language, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 8)
            sqlite3_bind_null(statement, 9)
            sqlite3_bind_null(statement, 10)
            sqlite3_bind_null(statement, 11)
            sqlite3_bind_null(statement, 12)
        }

        if let companyId = job.companyId {
            sqlite3_bind_text(statement, 13, companyId.uuidString, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 13)
        }

        if let checksum = job.fileChecksum {
            sqlite3_bind_text(statement, 14, checksum, -1, sqliteTransient)
        } else {
            sqlite3_bind_null(statement, 14)
        }

        sqlite3_bind_text(statement, 15, job.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.updateFailed
        }
    }

    func updateTranscriptionWithResult(_ job: TranscriptionJob, transcriptPath: String) async throws {
        ensureInitialized()
        guard db != nil else { throw DatabaseError.notInitialized }

        let updateSQL = "UPDATE transcriptions SET transcript_path = ? WHERE id = ?;"
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, transcriptPath, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, job.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.updateFailed
        }

        try await updateJob(job)
    }

    func updateSummaryPath(_ jobID: UUID, summaryPath: String) async throws {
        ensureInitialized()
        guard db != nil else { throw DatabaseError.notInitialized }
        let updateSQL = "UPDATE transcriptions SET summary_path = ? WHERE id = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, summaryPath, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, jobID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.updateFailed
        }
    }

    func updateChatPath(_ jobID: UUID, chatPath: String) async throws {
        ensureInitialized()
        guard db != nil else { throw DatabaseError.notInitialized }
        let updateSQL = "UPDATE transcriptions SET chat_path = ? WHERE id = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, chatPath, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, jobID.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.updateFailed
        }
    }

    // MARK: - Delete

    func deleteAllJobs() async throws {
        ensureInitialized()
        guard db != nil else {
            throw DatabaseError.notInitialized
        }

        let deleteSQL = "DELETE FROM transcriptions;"

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ Failed to prepare DELETE ALL statement: \(errorMessage)")
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ Failed to execute DELETE ALL: \(errorMessage)")
            throw DatabaseError.deleteFailed
        }

        log("✅ Deleted all jobs from database")
    }

    func deleteJob(_ jobID: UUID) async throws {
        ensureInitialized()
        guard db != nil else {
            throw DatabaseError.notInitialized
        }

        let deleteSQL = "DELETE FROM transcriptions WHERE id = ?;"

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil)
        guard prepareResult == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ Failed to prepare DELETE statement: \(errorMessage)")
            throw DatabaseError.prepareFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, jobID.uuidString, -1, sqliteTransient)

        let stepResult = sqlite3_step(statement)
        guard stepResult == SQLITE_DONE else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            log("❌ Failed to execute DELETE: \(errorMessage)")
            throw DatabaseError.deleteFailed
        }

        log("✅ Deleted job from database: \(jobID.uuidString)")
    }

    // MARK: - Query

    func loadAllJobs() async -> [TranscriptionJob] {
        ensureInitialized()
        guard db != nil else { return [] }
        log("🔧 loadAllJobs() called")
        var jobs: [TranscriptionJob] = []
        let querySQL = "SELECT \(transcriptionsSelectColumns) FROM transcriptions ORDER BY created_at DESC;"

        var statement: OpaquePointer?
        let prepareResult = sqlite3_prepare_v2(db, querySQL, -1, &statement, nil)

        guard prepareResult == SQLITE_OK else {
            if let db = db {
                let errorMessage = String(cString: sqlite3_errmsg(db))
                log("❌ Failed to prepare SELECT: \(errorMessage) (code: \(prepareResult))")
            }
            return jobs
        }

        defer { sqlite3_finalize(statement) }

        var rowCount = 0
        while sqlite3_step(statement) == SQLITE_ROW {
            rowCount += 1
            if let job = parseTranscriptionJob(from: statement) {
                jobs.append(job)
                log("✅ Loaded job: \(job.audioFile.filename)")
            } else {
                log("⚠️ Failed to parse job from row \(rowCount)")
            }
        }

        log("✅ loadAllJobs() complete: Loaded \(jobs.count) jobs from \(rowCount) rows")
        return jobs
    }

    func getAllTranscriptions() async -> [TranscriptionRecord] {
        ensureInitialized()
        guard db != nil else { return [] }
        var records: [TranscriptionRecord] = []
        let querySQL = "SELECT \(transcriptionsSelectColumns) FROM transcriptions ORDER BY created_at DESC;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return records
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let record = parseTranscriptionRecord(from: statement) {
                records.append(record)
            }
        }

        return records
    }

    func getTranscription(id: UUID) async -> TranscriptionRecord? {
        ensureInitialized()
        guard db != nil else { return nil }
        let querySQL = "SELECT \(transcriptionsSelectColumns) FROM transcriptions WHERE id = ?;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return parseTranscriptionRecord(from: statement)
        }

        return nil
    }

    private func parseTranscriptionJob(from statement: OpaquePointer?) -> TranscriptionJob? {
        guard let statement = statement else { return nil }

        guard let idString = sqlite3_column_text(statement, 0),
              let audioFilename = sqlite3_column_text(statement, 3),
              let audioPath = sqlite3_column_text(statement, 4),
              let audioFormat = sqlite3_column_text(statement, 5),
              let createdAtString = sqlite3_column_text(statement, 16),
              let statusString = sqlite3_column_text(statement, 18) else {
            return nil
        }

        let id = UUID(uuidString: String(cString: idString)) ?? UUID()
        let duration = sqlite3_column_double(statement, 10)
        let fileSize = sqlite3_column_int64(statement, 11)

        // Parse dates
        let formatter = ISO8601DateFormatter()
        let createdAt = formatter.date(from: String(cString: createdAtString)) ?? Date()
        var completedAt: Date?
        if let completedString = sqlite3_column_text(statement, 17) {
            completedAt = formatter.date(from: String(cString: completedString))
        }

        // Create AudioFile
        let audioFile = AudioFile(
            url: URL(fileURLWithPath: String(cString: audioPath)),
            filename: String(cString: audioFilename),
            duration: duration,
            fileSize: fileSize,
            format: String(cString: audioFormat)
        )

        // Parse status
        let status = TranscriptionStatus(rawValue: String(cString: statusString)) ?? .pending
        let progress = sqlite3_column_double(statement, 19)

        // Parse optional fields
        var folderPath: String?
        if let path = sqlite3_column_text(statement, 2) {
            folderPath = String(cString: path)
        }

        var error: String?
        if let err = sqlite3_column_text(statement, 20) {
            error = String(cString: err)
        }

        var customName: String?
        if let name = sqlite3_column_text(statement, 21) {
            customName = String(cString: name)
        }

        var description: String?
        if let desc = sqlite3_column_text(statement, 22) {
            description = String(cString: desc)
        }

        // Parse company_id
        var companyId: UUID?
        if let companyIdString = sqlite3_column_text(statement, 23) {
            companyId = UUID(uuidString: String(cString: companyIdString))
        }

        // Parse file_checksum
        var fileChecksum: String?
        if let checksumString = sqlite3_column_text(statement, 28) {
            fileChecksum = String(cString: checksumString)
        }

        // Parse transcript result if available
        var result: TranscriptionResult?
        if let transcriptText = sqlite3_column_text(statement, 7) {
            let confidence = sqlite3_column_double(statement, 14)
            let language = sqlite3_column_text(statement, 15).map { String(cString: $0) } ?? "en-US"

            result = TranscriptionResult(
                fullTranscript: String(cString: transcriptText),
                segments: [],
                language: language,
                confidence: confidence
            )
        }

        // Reconstruct TranscriptionJob
        let job = TranscriptionJob(
            id: id,
            audioFile: audioFile,
            status: status,
            progress: progress,
            result: result,
            error: error,
            createdAt: createdAt,
            completedAt: completedAt,
            customName: customName,
            description: description,
            folderPath: folderPath,
            companyId: companyId,
            fileChecksum: fileChecksum
        )

        return job
    }

    private func parseTranscriptionRecord(from statement: OpaquePointer?) -> TranscriptionRecord? {
        guard let statement = statement else { return nil }

        guard let idString = sqlite3_column_text(statement, 0),
              let folderName = sqlite3_column_text(statement, 1),
              let audioFilename = sqlite3_column_text(statement, 3),
              let audioPath = sqlite3_column_text(statement, 4) else {
            return nil
        }

        let id = UUID(uuidString: String(cString: idString)) ?? UUID()
        let duration = sqlite3_column_double(statement, 10)
        let fileSize = sqlite3_column_int64(statement, 11)

        var transcriptPath: String?
        if let path = sqlite3_column_text(statement, 6) {
            transcriptPath = String(cString: path)
        }

        var summaryPath: String?
        if let path = sqlite3_column_text(statement, 8) {
            summaryPath = String(cString: path)
        }

        var chatPath: String?
        if let path = sqlite3_column_text(statement, 9) {
            chatPath = String(cString: path)
        }

        return TranscriptionRecord(
            id: id,
            folderName: String(cString: folderName),
            audioFilename: String(cString: audioFilename),
            audioPath: String(cString: audioPath),
            transcriptPath: transcriptPath,
            summaryPath: summaryPath,
            chatPath: chatPath,
            duration: duration,
            fileSize: fileSize
        )
    }
}

struct TranscriptionRecord {
    let id: UUID
    let folderName: String
    let audioFilename: String
    let audioPath: String
    let transcriptPath: String?
    let summaryPath: String?
    let chatPath: String?
    let duration: TimeInterval
    let fileSize: Int64
}

enum DatabaseError: LocalizedError {
    case notInitialized
    case prepareFailed
    case insertFailed
    case updateFailed
    case deleteFailed
    case queryFailed

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .prepareFailed:
            return "Failed to prepare database statement"
        case .insertFailed:
            return "Failed to insert record"
        case .updateFailed:
            return "Failed to update record"
        case .deleteFailed:
            return "Failed to delete record"
        case .queryFailed:
            return "Failed to query database"
        }
    }
}
