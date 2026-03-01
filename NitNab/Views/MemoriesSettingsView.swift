//
//  MemoriesSettingsView.swift
//  NitNab
//
//  Memories tab in Settings for managing personal info, family, and companies
//

import SwiftUI

struct MemoriesSettingsView: View {
    @State private var profile: PersonalProfile = PersonalProfile()
    @State private var familyMembers: [FamilyMember] = []
    @State private var companies: [Company] = []
    @State private var showAddFamilyMember = false
    @State private var showAddCompany = false
    @State private var selectedCompany: Company?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Personal Information Section
                PersonalInfoSection(
                    profile: $profile,
                    familyMembers: $familyMembers,
                    showAddFamilyMember: $showAddFamilyMember
                )
                
                Divider()
                
                // Companies Section
                CompaniesSection(
                    companies: $companies,
                    showAddCompany: $showAddCompany,
                    selectedCompany: $selectedCompany
                )
            }
            .padding()
        }
        .onAppear {
            loadData()
        }
        .sheet(isPresented: $showAddFamilyMember) {
            AddFamilyMemberSheet { member in
                Task {
                    try? await MemoryService.shared.addFamilyMember(member)
                    loadData()
                }
            }
        }
        .sheet(isPresented: $showAddCompany) {
            AddCompanySheet { company in
                Task {
                    try? await MemoryService.shared.createCompany(company)
                    loadData()
                }
            }
        }
        .sheet(item: $selectedCompany) { company in
            CompanyDetailSheet(company: company) { updatedCompany in
                Task {
                    try? await MemoryService.shared.updateCompany(updatedCompany)
                    loadData()
                }
            }
        }
    }
    
    private func loadData() {
        Task {
            let loadedProfile = await MemoryService.shared.getPersonalProfile() ?? PersonalProfile()
            let loadedFamily = await MemoryService.shared.getAllFamilyMembers()
            let loadedCompanies = await MemoryService.shared.getAllCompanies()
            
            await MainActor.run {
                profile = loadedProfile
                familyMembers = loadedFamily
                companies = loadedCompanies
            }
        }
    }
}

// MARK: - Personal Info Section

struct PersonalInfoSection: View {
    @Binding var profile: PersonalProfile
    @Binding var familyMembers: [FamilyMember]
    @Binding var showAddFamilyMember: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Personal Information")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Your Name", text: Binding(
                    get: { profile.userName ?? "" },
                    set: { profile.userName = $0.isEmpty ? nil : $0 }
                ))
                
                TextField("Your Role/Title", text: Binding(
                    get: { profile.userRole ?? "" },
                    set: { profile.userRole = $0.isEmpty ? nil : $0 }
                ))
                
                TextField("Your Company", text: Binding(
                    get: { profile.userCompany ?? "" },
                    set: { profile.userCompany = $0.isEmpty ? nil : $0 }
                ))
            }
            .formStyle(.grouped)
            
            // Family Members
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Family Members")
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: { showAddFamilyMember = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                
                if familyMembers.isEmpty {
                    Text("No family members added")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                        .padding(.vertical, 4)
                } else {
                    ForEach(familyMembers) { member in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(member.name)
                                    .font(.body)
                                Text(member.relationship)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                Task {
                                    try? await MemoryService.shared.deleteFamilyMember(member.id)
                                }
                            }) {
                                Image(systemName: "trash")
                                    .foregroundStyle(Brand.error)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(.top, 8)
            
            // AI Context
            VStack(alignment: .leading, spacing: 8) {
                Text("AI Context")
                    .font(.headline)
                Text("Help AI understand you better (optional)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: Binding(
                    get: { profile.aiContext ?? "" },
                    set: { profile.aiContext = $0.isEmpty ? nil : $0 }
                ))
                .frame(height: 80)
                .border(Color(nsColor: .separatorColor))
            }
            .padding(.top, 8)
            
            Button("Save Personal Info") {
                Task {
                    try? await MemoryService.shared.updatePersonalProfile(profile)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(Brand.Spacing.md)
        .brandCard()
    }
}

// MARK: - Companies Section

struct CompaniesSection: View {
    @Binding var companies: [Company]
    @Binding var showAddCompany: Bool
    @Binding var selectedCompany: Company?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Companies & Professional Contacts")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { showAddCompany = true }) {
                    Label("Add Company", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if companies.isEmpty {
                Text("No companies added. Add companies to track people and custom vocabulary.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(companies) { company in
                    Button(action: { selectedCompany = company }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(company.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                
                                Text("\(company.people.count) people • \(company.vocabulary.count) terms")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(Brand.Spacing.md)
                        .brandCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(Brand.Spacing.md)
        .brandCard()
    }
}

// MARK: - Add Family Member Sheet

struct AddFamilyMemberSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var relationship = "Spouse"
    @State private var notes = ""
    
    let onSave: (FamilyMember) -> Void
    
    let relationships = ["Spouse", "Child", "Parent", "Sibling", "Pet", "Other"]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Family Member")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Name", text: $name)
                
                Picker("Relationship", selection: $relationship) {
                    ForEach(relationships, id: \.self) { rel in
                        Text(rel).tag(rel)
                    }
                }
                
                TextField("Notes (optional)", text: $notes)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add") {
                    let member = FamilyMember(name: name, relationship: relationship, notes: notes.isEmpty ? nil : notes)
                    onSave(member)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - Add Company Sheet

struct AddCompanySheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var name = ""
    @State private var domain = ""
    @State private var notes = ""
    
    let onSave: (Company) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Company")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Company Name", text: $name)
                
                TextField("Domain (optional)", text: $domain)
                    .textContentType(.URL)
                
                TextField("Notes (optional)", text: $notes)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add") {
                    var company = Company(name: name, domain: domain.isEmpty ? nil : domain, notes: notes.isEmpty ? nil : notes)
                    onSave(company)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - Company Detail Sheet

struct CompanyDetailSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var company: Company
    @State private var showAddPerson = false
    @State private var newVocabTerm = ""
    
    let onSave: (Company) -> Void
    
    init(company: Company, onSave: @escaping (Company) -> Void) {
        _company = State(initialValue: company)
        self.onSave = onSave
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(company.name)
                .font(.title)
                .fontWeight(.bold)
            
            TabView {
                // Details Tab
                Form {
                    TextField("Company Name", text: $company.name)
                    
                    TextField("Domain", text: Binding(
                        get: { company.domain ?? "" },
                        set: { company.domain = $0.isEmpty ? nil : $0 }
                    ))
                    
                    TextField("Notes", text: Binding(
                        get: { company.notes ?? "" },
                        set: { company.notes = $0.isEmpty ? nil : $0 }
                    ))
                }
                .formStyle(.grouped)
                .tabItem {
                    Label("Details", systemImage: "info.circle")
                }
                
                // People Tab
                VStack {
                    HStack {
                        Text("People")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Add Person") {
                            showAddPerson = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    
                    List(company.people) { person in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.fullName)
                                .font(.body)
                            if let title = person.title {
                                Text(title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .tabItem {
                    Label("People", systemImage: "person.2")
                }
                
                // Vocabulary Tab
                VStack {
                    HStack {
                        TextField("Add term", text: $newVocabTerm)
                        
                        Button("Add") {
                            if !newVocabTerm.isEmpty {
                                company.vocabulary.append(newVocabTerm)
                                newVocabTerm = ""
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newVocabTerm.isEmpty)
                    }
                    .padding()
                    
                    List {
                        ForEach(company.vocabulary, id: \.self) { term in
                            Text(term)
                        }
                        .onDelete { indexSet in
                            company.vocabulary.remove(atOffsets: indexSet)
                        }
                    }
                }
                .tabItem {
                    Label("Vocabulary", systemImage: "text.book.closed")
                }
            }
            
            HStack {
                Button("Delete Company", role: .destructive) {
                    Task {
                        try? await MemoryService.shared.deleteCompany(company.id)
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Button("Save") {
                    onSave(company)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .padding()
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showAddPerson) {
            AddPersonSheet(companyId: company.id) { person in
                company.people.append(person)
            }
        }
    }
}

// MARK: - Add Person Sheet

struct AddPersonSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var fullName = ""
    @State private var preferredName = ""
    @State private var title = ""
    @State private var email = ""
    @State private var phoneticSpelling = ""
    
    let companyId: UUID
    let onSave: (Person) -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Person")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                TextField("Full Name", text: $fullName)
                
                TextField("Preferred Name (optional)", text: $preferredName)
                
                TextField("Title/Role (optional)", text: $title)
                
                TextField("Email (optional)", text: $email)
                    .textContentType(.emailAddress)
                
                TextField("Phonetic Spelling (optional)", text: $phoneticSpelling)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Add") {
                    let person = Person(
                        fullName: fullName,
                        preferredName: preferredName.isEmpty ? nil : preferredName,
                        title: title.isEmpty ? nil : title,
                        email: email.isEmpty ? nil : email,
                        phoneticSpelling: phoneticSpelling.isEmpty ? nil : phoneticSpelling
                    )
                    
                    Task {
                        try? await MemoryService.shared.addPerson(person, to: companyId)
                        onSave(person)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(fullName.isEmpty)
            }
            .padding()
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

#Preview {
    MemoriesSettingsView()
}
