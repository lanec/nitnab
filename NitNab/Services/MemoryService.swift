//
//  MemoryService.swift
//  NitNab
//
//  Actor-based service for managing memory data (personal profiles, companies, people)
//

import Foundation
import SQLite3

// File-scope constant — no actor isolation needed
private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

actor MemoryService {

    static let shared = MemoryService()

    private var db: OpaquePointer?
    private let dbPath: URL
    private let ubiquitousContainerID: String
    private var isInitialized = false

    private init() {
        self.ubiquitousContainerID = "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.nitnab")"

        // Use same database as DatabaseService
        if let iCloudURL = FileManager.default.url(forUbiquityContainerIdentifier: ubiquitousContainerID) {
            let dbFolder = iCloudURL.appendingPathComponent("Documents/NitNab")
            self.dbPath = dbFolder.appendingPathComponent("nitnab.db")
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dbFolder = appSupport.appendingPathComponent("NitNab")
            self.dbPath = dbFolder.appendingPathComponent("nitnab.db")
        }
    }

    private func ensureInitialized() {
        guard !isInitialized else { return }
        openDatabase()
        guard db != nil else {
            log("ensureInitialized: database open failed, will retry next call")
            return
        }
        isInitialized = true
    }

    private func openDatabase() {
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(dbPath.path, &db, flags, nil)
        if result != SQLITE_OK {
            log("Failed to open database: code \(result)")
        }

        // Enable WAL mode
        var walStatement: OpaquePointer?
        if sqlite3_prepare_v2(db, "PRAGMA journal_mode=WAL;", -1, &walStatement, nil) == SQLITE_OK {
            sqlite3_step(walStatement)
        }
        sqlite3_finalize(walStatement)
    }

    private func log(_ message: String) {
        print("[MemoryService] \(message)")
    }

    // MARK: - Personal Profile CRUD

    func getPersonalProfile() async -> PersonalProfile? {
        ensureInitialized()
        let querySQL = "SELECT * FROM personal_profile WHERE id = 1;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            return parsePersonalProfile(from: statement)
        }

        return nil
    }

    func updatePersonalProfile(_ profile: PersonalProfile) async throws {
        ensureInitialized()
        let upsertSQL = """
        INSERT OR REPLACE INTO personal_profile
        (id, user_name, user_role, user_company, ai_context, updated_at)
        VALUES (1, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, upsertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, profile.userName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, profile.userRole, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, profile.userCompany, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, profile.aiContext, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: profile.updatedAt), -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }

        // Save family members separately
        for member in profile.familyMembers {
            try await addFamilyMember(member)
        }
    }

    func clearPersonalProfile() async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM personal_profile WHERE id = 1;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    // MARK: - Family Members CRUD

    func getAllFamilyMembers() async -> [FamilyMember] {
        ensureInitialized()
        let querySQL = "SELECT * FROM family_members ORDER BY created_at DESC;"
        var statement: OpaquePointer?
        var members: [FamilyMember] = []

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return members
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let member = parseFamilyMember(from: statement) {
                members.append(member)
            }
        }

        return members
    }

    func addFamilyMember(_ member: FamilyMember) async throws {
        ensureInitialized()
        let insertSQL = """
        INSERT OR REPLACE INTO family_members (id, name, relationship, notes, created_at)
        VALUES (?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, member.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, member.name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, member.relationship, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, member.notes, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: member.createdAt), -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func updateFamilyMember(_ member: FamilyMember) async throws {
        ensureInitialized()
        let updateSQL = """
        UPDATE family_members
        SET name = ?, relationship = ?, notes = ?
        WHERE id = ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, member.name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, member.relationship, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, member.notes, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, member.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func deleteFamilyMember(_ id: UUID) async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM family_members WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    func getFamilyMember(_ id: UUID) async -> FamilyMember? {
        ensureInitialized()
        let querySQL = "SELECT * FROM family_members WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return parseFamilyMember(from: statement)
        }

        return nil
    }

    // MARK: - Companies CRUD

    func getAllCompanies() async -> [Company] {
        ensureInitialized()
        let querySQL = "SELECT * FROM companies ORDER BY name ASC;"
        var statement: OpaquePointer?
        var companies: [Company] = []

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return companies
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let company = parseCompany(from: statement) {
                companies.append(company)
            }
        }

        return companies
    }

    func getCompany(_ id: UUID) async -> Company? {
        ensureInitialized()
        let querySQL = "SELECT * FROM companies WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            if var company = parseCompany(from: statement) {
                company.people = await getPeopleForCompany(company.id)
                company.vocabulary = await getVocabulary(for: company.id)
                return company
            }
        }

        return nil
    }

    func createCompany(_ company: Company) async throws {
        ensureInitialized()
        let insertSQL = """
        INSERT INTO companies (id, name, domain, notes, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, company.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, company.name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, company.domain, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, company.notes, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, ISO8601DateFormatter().string(from: company.createdAt), -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, ISO8601DateFormatter().string(from: company.updatedAt), -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }

        // Add people if any
        for person in company.people {
            try await addPerson(person, to: company.id)
        }

        // Add vocabulary if any
        for term in company.vocabulary {
            try await addVocabulary(term: term, to: company.id)
        }
    }

    func updateCompany(_ company: Company) async throws {
        ensureInitialized()
        let updateSQL = """
        UPDATE companies
        SET name = ?, domain = ?, notes = ?, updated_at = ?
        WHERE id = ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, company.name, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, company.domain, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, company.notes, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, ISO8601DateFormatter().string(from: Date()), -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, company.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func deleteCompany(_ id: UUID) async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM companies WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    // MARK: - People CRUD

    func getPerson(_ id: UUID) async -> Person? {
        ensureInitialized()
        let querySQL = "SELECT * FROM people WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        if sqlite3_step(statement) == SQLITE_ROW {
            return parsePerson(from: statement)
        }

        return nil
    }

    func addPerson(_ person: Person, to companyId: UUID) async throws {
        ensureInitialized()
        let insertSQL = """
        INSERT INTO people
        (id, company_id, full_name, preferred_name, title, email, phonetic_spelling, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, person.id.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, companyId.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, person.fullName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, person.preferredName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, person.title, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, person.email, -1, sqliteTransient)
        sqlite3_bind_text(statement, 7, person.phoneticSpelling, -1, sqliteTransient)
        sqlite3_bind_text(statement, 8, ISO8601DateFormatter().string(from: person.createdAt), -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func updatePerson(_ person: Person, companyId: UUID) async throws {
        ensureInitialized()
        let updateSQL = """
        UPDATE people
        SET full_name = ?, preferred_name = ?, title = ?, email = ?, phonetic_spelling = ?
        WHERE id = ?;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, updateSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, person.fullName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, person.preferredName, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, person.title, -1, sqliteTransient)
        sqlite3_bind_text(statement, 4, person.email, -1, sqliteTransient)
        sqlite3_bind_text(statement, 5, person.phoneticSpelling, -1, sqliteTransient)
        sqlite3_bind_text(statement, 6, person.id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func deletePerson(_ id: UUID) async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM people WHERE id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, id.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    // MARK: - Vocabulary Management

    func getVocabulary(for companyId: UUID) async -> [String] {
        ensureInitialized()
        let querySQL = "SELECT term FROM company_vocabulary WHERE company_id = ? ORDER BY term ASC;"
        var statement: OpaquePointer?
        var terms: [String] = []

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return terms
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)

        while sqlite3_step(statement) == SQLITE_ROW {
            if let termText = sqlite3_column_text(statement, 0) {
                terms.append(String(cString: termText))
            }
        }

        return terms
    }

    func addVocabulary(term: String, to companyId: UUID, phonetic: String? = nil) async throws {
        ensureInitialized()
        let insertSQL = """
        INSERT OR IGNORE INTO company_vocabulary (company_id, term, phonetic)
        VALUES (?, ?, ?);
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.saveFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, term, -1, sqliteTransient)
        sqlite3_bind_text(statement, 3, phonetic, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.saveFailed
        }
    }

    func removeVocabulary(term: String, from companyId: UUID) async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM company_vocabulary WHERE company_id = ? AND term = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)
        sqlite3_bind_text(statement, 2, term, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    func clearVocabulary(for companyId: UUID) async throws {
        ensureInitialized()
        let deleteSQL = "DELETE FROM company_vocabulary WHERE company_id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, deleteSQL, -1, &statement, nil) == SQLITE_OK else {
            throw MemoryError.deleteFailed
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw MemoryError.deleteFailed
        }
    }

    // MARK: - Context Building

    func buildCustomVocabulary(for companyId: UUID) async -> [String] {
        ensureInitialized()
        var allTerms: [String] = []

        // Get company's people names
        let querySQL = "SELECT * FROM people WHERE company_id = ?;"
        var statement: OpaquePointer?

        if sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK {
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)

            while sqlite3_step(statement) == SQLITE_ROW {
                if let person = parsePerson(from: statement) {
                    allTerms.append(person.fullName)
                    if let preferred = person.preferredName {
                        allTerms.append(preferred)
                    }
                    if let phonetic = person.phoneticSpelling {
                        allTerms.append(phonetic)
                    }
                }
            }
        }

        // Get company's custom vocabulary
        let vocabSQL = "SELECT * FROM company_vocabulary WHERE company_id = ?;"
        var vocabStatement: OpaquePointer?

        if sqlite3_prepare_v2(db, vocabSQL, -1, &vocabStatement, nil) == SQLITE_OK {
            defer { sqlite3_finalize(vocabStatement) }
            sqlite3_bind_text(vocabStatement, 1, companyId.uuidString, -1, sqliteTransient)

            while sqlite3_step(vocabStatement) == SQLITE_ROW {
                if let term = sqlite3_column_text(vocabStatement, 2) {
                    allTerms.append(String(cString: term))
                }
                if let phonetic = sqlite3_column_text(vocabStatement, 3) {
                    allTerms.append(String(cString: phonetic))
                }
            }
        }

        return allTerms
    }

    /// Build AI context string from personal profile and memories
    func buildAIContextString() async -> String {
        var context = ""

        // Personal profile
        if let profile = await getPersonalProfile() {
            if let userName = profile.userName {
                context += "User: \(userName)"
            }
            if let role = profile.userRole {
                context += ", Role: \(role)"
            }
            if let company = profile.userCompany {
                context += ", Company: \(company)"
            }
            if let aiContext = profile.aiContext, !aiContext.isEmpty {
                context += "\n\(aiContext)"
            }
            context += "\n"
        }

        // Family members
        let family = await getAllFamilyMembers()
        if !family.isEmpty {
            context += "Family: \(family.map { "\($0.name) (\($0.relationship))" }.joined(separator: ", "))\n"
        }

        return context
    }

    // MARK: - Parsing Helpers

    private func parsePersonalProfile(from statement: OpaquePointer?) -> PersonalProfile? {
        guard let statement = statement else { return nil }

        let userName = sqlite3_column_text(statement, 1).map { String(cString: $0) }
        let userRole = sqlite3_column_text(statement, 2).map { String(cString: $0) }
        let userCompany = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let aiContext = sqlite3_column_text(statement, 4).map { String(cString: $0) }

        let updatedAtString = sqlite3_column_text(statement, 5).map { String(cString: $0) } ?? ""
        let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) ?? Date()

        return PersonalProfile(
            userName: userName,
            userRole: userRole,
            userCompany: userCompany,
            familyMembers: [],
            aiContext: aiContext,
            updatedAt: updatedAt
        )
    }

    private func parseFamilyMember(from statement: OpaquePointer?) -> FamilyMember? {
        guard let statement = statement,
              let idString = sqlite3_column_text(statement, 0),
              let nameString = sqlite3_column_text(statement, 1),
              let relationshipString = sqlite3_column_text(statement, 2),
              let createdAtString = sqlite3_column_text(statement, 4) else {
            return nil
        }

        let id = UUID(uuidString: String(cString: idString)) ?? UUID()
        let name = String(cString: nameString)
        let relationship = String(cString: relationshipString)
        let notes = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let createdAt = ISO8601DateFormatter().date(from: String(cString: createdAtString)) ?? Date()

        return FamilyMember(id: id, name: name, relationship: relationship, notes: notes, createdAt: createdAt)
    }

    private func parseCompany(from statement: OpaquePointer?) -> Company? {
        guard let statement = statement,
              let idString = sqlite3_column_text(statement, 0),
              let nameString = sqlite3_column_text(statement, 1),
              let createdAtString = sqlite3_column_text(statement, 4),
              let updatedAtString = sqlite3_column_text(statement, 5) else {
            return nil
        }

        let id = UUID(uuidString: String(cString: idString)) ?? UUID()
        let name = String(cString: nameString)
        let domain = sqlite3_column_text(statement, 2).map { String(cString: $0) }
        let notes = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let createdAt = ISO8601DateFormatter().date(from: String(cString: createdAtString)) ?? Date()
        let updatedAt = ISO8601DateFormatter().date(from: String(cString: updatedAtString)) ?? Date()

        return Company(id: id, name: name, domain: domain, notes: notes, createdAt: createdAt, updatedAt: updatedAt)
    }

    private func parsePerson(from statement: OpaquePointer?) -> Person? {
        guard let statement = statement,
              let idString = sqlite3_column_text(statement, 0),
              let fullNameString = sqlite3_column_text(statement, 2),
              let createdAtString = sqlite3_column_text(statement, 7) else {
            return nil
        }

        let id = UUID(uuidString: String(cString: idString)) ?? UUID()
        let fullName = String(cString: fullNameString)
        let preferredName = sqlite3_column_text(statement, 3).map { String(cString: $0) }
        let title = sqlite3_column_text(statement, 4).map { String(cString: $0) }
        let email = sqlite3_column_text(statement, 5).map { String(cString: $0) }
        let phoneticSpelling = sqlite3_column_text(statement, 6).map { String(cString: $0) }
        let createdAt = ISO8601DateFormatter().date(from: String(cString: createdAtString)) ?? Date()

        return Person(id: id, fullName: fullName, preferredName: preferredName, title: title, email: email, phoneticSpelling: phoneticSpelling, createdAt: createdAt)
    }

    /// Build vocabulary list for a company (names + custom terms)
    func buildVocabularyForCompany(_ companyId: UUID) async -> [String] {
        return await buildCustomVocabulary(for: companyId)
    }

    /// Get all people for a specific company
    func getPeopleForCompany(_ companyId: UUID) async -> [Person] {
        ensureInitialized()
        let querySQL = "SELECT * FROM people WHERE company_id = ? ORDER BY full_name ASC;"
        var statement: OpaquePointer?
        var people: [Person] = []

        guard sqlite3_prepare_v2(db, querySQL, -1, &statement, nil) == SQLITE_OK else {
            return people
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_text(statement, 1, companyId.uuidString, -1, sqliteTransient)

        while sqlite3_step(statement) == SQLITE_ROW {
            if let person = parsePerson(from: statement) {
                people.append(person)
            }
        }

        return people
    }
}

// MARK: - Error Types

enum MemoryError: LocalizedError {
    case saveFailed
    case deleteFailed
    case notFound

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save memory data"
        case .deleteFailed:
            return "Failed to delete memory data"
        case .notFound:
            return "Memory data not found"
        }
    }
}
