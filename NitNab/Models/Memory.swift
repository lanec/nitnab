//
//  Memory.swift
//  NitNab
//
//  Data models for the Memories system
//  Stores personal information, family, companies, and professional contacts
//

import Foundation

// MARK: - Personal Information

/// User's personal profile information
struct PersonalProfile: Codable {
    var userName: String?
    var userRole: String?
    var userCompany: String?
    var familyMembers: [FamilyMember]
    var aiContext: String?  // Freeform context to help AI understand the user
    var updatedAt: Date
    
    init() {
        self.familyMembers = []
        self.updatedAt = Date()
    }
    
    init(userName: String? = nil, userRole: String? = nil, userCompany: String? = nil, familyMembers: [FamilyMember] = [], aiContext: String? = nil, updatedAt: Date = Date()) {
        self.userName = userName
        self.userRole = userRole
        self.userCompany = userCompany
        self.familyMembers = familyMembers
        self.aiContext = aiContext
        self.updatedAt = updatedAt
    }
}

/// Family member information
struct FamilyMember: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var relationship: String  // e.g., "Spouse", "Child", "Parent", "Sibling", "Pet"
    var notes: String?
    var createdAt: Date
    
    init(name: String, relationship: String, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.relationship = relationship
        self.notes = notes
        self.createdAt = Date()
    }
    
    init(id: UUID, name: String, relationship: String, notes: String?, createdAt: Date) {
        self.id = id
        self.name = name
        self.relationship = relationship
        self.notes = notes
        self.createdAt = createdAt
    }
}

// MARK: - Professional Contacts

/// Company/Organization information
struct Company: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var domain: String?  // e.g., "acme.com"
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    
    // Not stored directly in database, loaded separately
    var people: [Person]
    var vocabulary: [String]
    
    init(name: String, domain: String? = nil, notes: String? = nil) {
        self.id = UUID()
        self.name = name
        self.domain = domain
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.people = []
        self.vocabulary = []
    }
    
    init(id: UUID, name: String, domain: String?, notes: String?, createdAt: Date, updatedAt: Date, people: [Person] = [], vocabulary: [String] = []) {
        self.id = id
        self.name = name
        self.domain = domain
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.people = people
        self.vocabulary = vocabulary
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Company, rhs: Company) -> Bool {
        lhs.id == rhs.id
    }
}

/// Person within a company
struct Person: Identifiable, Codable, Hashable {
    let id: UUID
    var fullName: String
    var preferredName: String?  // e.g., "Bob" vs "Robert"
    var title: String?          // e.g., "CEO", "CTO"
    var email: String?
    var phoneticSpelling: String?  // e.g., "Niamh" → "NEEV"
    var createdAt: Date
    
    init(fullName: String, preferredName: String? = nil, title: String? = nil, email: String? = nil, phoneticSpelling: String? = nil) {
        self.id = UUID()
        self.fullName = fullName
        self.preferredName = preferredName
        self.title = title
        self.email = email
        self.phoneticSpelling = phoneticSpelling
        self.createdAt = Date()
    }
    
    init(id: UUID, fullName: String, preferredName: String?, title: String?, email: String?, phoneticSpelling: String?, createdAt: Date) {
        self.id = id
        self.fullName = fullName
        self.preferredName = preferredName
        self.title = title
        self.email = email
        self.phoneticSpelling = phoneticSpelling
        self.createdAt = createdAt
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Person, rhs: Person) -> Bool {
        lhs.id == rhs.id
    }
}

/// Custom vocabulary term for a company
struct VocabularyTerm: Identifiable, Codable {
    let id: Int?  // Database auto-increment ID
    var term: String
    var phonetic: String?
    
    init(term: String, phonetic: String? = nil) {
        self.id = nil
        self.term = term
        self.phonetic = phonetic
    }
    
    init(id: Int, term: String, phonetic: String?) {
        self.id = id
        self.term = term
        self.phonetic = phonetic
    }
}

// MARK: - Extensions

extension PersonalProfile {
    /// Whether the profile has been set up
    var isConfigured: Bool {
        userName != nil || userRole != nil || !familyMembers.isEmpty
    }
}

extension Company {
    /// Display name with people count
    var displayDescription: String {
        let peopleCount = people.count
        let vocabCount = vocabulary.count
        return "\(name) • \(peopleCount) people • \(vocabCount) terms"
    }
}

extension Person {
    /// Best name to display (preferred name if available, otherwise full name)
    var displayName: String {
        preferredName ?? fullName
    }
    
    /// Full display with title
    var displayNameWithTitle: String {
        if let title = title {
            return "\(displayName) (\(title))"
        }
        return displayName
    }
}
