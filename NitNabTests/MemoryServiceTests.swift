//
//  MemoryServiceTests.swift
//  NitNabTests
//
//  Tests for MemoryService company and people management
//

import XCTest
@testable import NitNab

final class MemoryServiceTests: XCTestCase {
    
    var memoryService: MemoryService!
    
    override func setUpWithError() throws {
        memoryService = MemoryService.shared
    }
    
    override func tearDownWithError() throws {
        memoryService = nil
    }

    private func uniqueCompanyName(_ base: String) -> String {
        "\(base)-\(UUID().uuidString.prefix(8))"
    }
    
    // MARK: - Company CRUD Tests
    
    func testGetAllCompanies_ReturnsEmptyArrayInitially() async throws {
        let companies = await memoryService.getAllCompanies()
        
        // Should return an array (even if empty)
        XCTAssertNotNil(companies, "getAllCompanies should return a valid array")
    }
    
    func testCreateAndGetCompany() async throws {
        let company = Company(name: uniqueCompanyName("Test Company"), domain: "test.com", notes: "Test notes")
        
        // Create company
        try await memoryService.createCompany(company)
        
        // Retrieve it
        let retrieved = await memoryService.getCompany(company.id)
        
        XCTAssertNotNil(retrieved, "Should be able to retrieve created company")
        XCTAssertEqual(retrieved?.name, company.name)
        XCTAssertEqual(retrieved?.domain, "test.com")
    }
    
    func testGetAllCompanies_ReturnsCreatedCompanies() async throws {
        let company1 = Company(name: uniqueCompanyName("Alpha Corp"), domain: "alpha.com")
        let company2 = Company(name: uniqueCompanyName("Beta Inc"), domain: "beta.com")
        
        try await memoryService.createCompany(company1)
        try await memoryService.createCompany(company2)
        
        let companies = await memoryService.getAllCompanies()
        
        XCTAssertTrue(companies.contains(where: { $0.name == "Alpha Corp" }))
        XCTAssertTrue(companies.contains(where: { $0.name == "Beta Inc" }))
    }
    
    // MARK: - People Management Tests
    
    func testGetPeopleForCompany_ReturnsEmptyArrayForNewCompany() async throws {
        let company = Company(name: uniqueCompanyName("Empty Company"))
        try await memoryService.createCompany(company)
        
        let people = await memoryService.getPeopleForCompany(company.id)
        
        XCTAssertNotNil(people, "Should return valid array")
        XCTAssertEqual(people.count, 0, "New company should have no people")
    }
    
    func testAddPersonToCompany() async throws {
        let company = Company(name: uniqueCompanyName("People Test Company"))
        try await memoryService.createCompany(company)
        
        let person = Person(
            fullName: "Lane Campbell",
            preferredName: "Lane",
            phoneticSpelling: "Lane not Wayne"
        )
        
        try await memoryService.addPerson(person, to: company.id)
        
        let people = await memoryService.getPeopleForCompany(company.id)
        
        XCTAssertEqual(people.count, 1, "Should have one person")
        XCTAssertEqual(people.first?.fullName, "Lane Campbell")
        XCTAssertEqual(people.first?.phoneticSpelling, "Lane not Wayne")
    }
    
    func testGetPeopleForCompany_ReturnsMultiplePeople() async throws {
        let company = Company(name: uniqueCompanyName("Multi People Company"))
        try await memoryService.createCompany(company)
        
        let person1 = Person(fullName: "Alice Smith", preferredName: "Alice")
        let person2 = Person(fullName: "Bob Jones", preferredName: "Bob")
        let person3 = Person(fullName: "Charlie Brown", preferredName: "Charlie")
        
        try await memoryService.addPerson(person1, to: company.id)
        try await memoryService.addPerson(person2, to: company.id)
        try await memoryService.addPerson(person3, to: company.id)
        
        let people = await memoryService.getPeopleForCompany(company.id)
        
        XCTAssertEqual(people.count, 3, "Should have three people")
        
        // Verify they're sorted by name (as per ORDER BY full_name ASC)
        XCTAssertEqual(people[0].fullName, "Alice Smith")
        XCTAssertEqual(people[1].fullName, "Bob Jones")
        XCTAssertEqual(people[2].fullName, "Charlie Brown")
    }
    
    // MARK: - Vocabulary Tests
    
    func testBuildVocabularyForCompany_IncludesPeopleNames() async throws {
        let company = Company(name: uniqueCompanyName("Vocab Test Company"))
        try await memoryService.createCompany(company)
        
        let person = Person(
            fullName: "Lane Campbell",
            preferredName: "Lane",
            phoneticSpelling: "LANE"
        )
        
        try await memoryService.addPerson(person, to: company.id)
        
        let vocabulary = await memoryService.buildVocabularyForCompany(company.id)
        
        XCTAssertTrue(vocabulary.contains("Lane Campbell"), "Should contain full name")
        XCTAssertTrue(vocabulary.contains("Lane"), "Should contain preferred name")
        XCTAssertTrue(vocabulary.contains("LANE"), "Should contain phonetic spelling")
    }
    
    func testBuildVocabularyForCompany_IncludesCustomTerms() async throws {
        let company = Company(name: uniqueCompanyName("Custom Vocab Company"))
        try await memoryService.createCompany(company)
        
        try await memoryService.addVocabulary(term: "Kubernetes", to: company.id)
        try await memoryService.addVocabulary(term: "PostgreSQL", to: company.id)
        
        let vocabulary = await memoryService.buildVocabularyForCompany(company.id)
        
        XCTAssertTrue(vocabulary.contains("Kubernetes"))
        XCTAssertTrue(vocabulary.contains("PostgreSQL"))
    }
    
    // MARK: - Integration Tests
    
    func testCompanyWithPeopleAndVocabulary() async throws {
        // Create a realistic company setup
        let company = Company(name: uniqueCompanyName("Acme Corp"), domain: "acme.com")
        try await memoryService.createCompany(company)
        
        // Add people
        let ceo = Person(fullName: "Lane Campbell", preferredName: "Lane", title: "CEO", phoneticSpelling: "Lane not Wayne")
        let cto = Person(fullName: "Sarah Johnson", preferredName: "Sarah", title: "CTO")
        
        try await memoryService.addPerson(ceo, to: company.id)
        try await memoryService.addPerson(cto, to: company.id)
        
        // Add custom vocabulary
        try await memoryService.addVocabulary(term: "NitNab", to: company.id)
        try await memoryService.addVocabulary(term: "transcription", to: company.id)
        
        // Verify everything
        let people = await memoryService.getPeopleForCompany(company.id)
        let vocabulary = await memoryService.buildVocabularyForCompany(company.id)
        
        XCTAssertEqual(people.count, 2)
        XCTAssertTrue(people.contains(where: { $0.fullName == "Lane Campbell" }))
        XCTAssertTrue(people.contains(where: { $0.fullName == "Sarah Johnson" }))
        
        XCTAssertTrue(vocabulary.contains("Lane Campbell"))
        XCTAssertTrue(vocabulary.contains("Sarah Johnson"))
        XCTAssertTrue(vocabulary.contains("NitNab"))
        XCTAssertTrue(vocabulary.contains("transcription"))
    }
    
    // MARK: - Error Handling Tests
    
    func testGetPeopleForCompany_WithInvalidCompanyId() async throws {
        let invalidId = UUID()
        let people = await memoryService.getPeopleForCompany(invalidId)
        
        XCTAssertEqual(people.count, 0, "Should return empty array for invalid company")
    }
}
