//
//  CompanyPickerSheet.swift
//  NitNab
//
//  Sheet to select a company before transcription
//

import SwiftUI

struct CompanyPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let audioFiles: [AudioFile]
    let onComplete: (UUID?) -> Void
    
    @State private var companies: [Company] = []
    @State private var selectedCompanyId: UUID?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign to Company")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a company to use custom vocabulary and improve name recognition during transcription.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                if audioFiles.count > 1 {
                    Text("Adding \(audioFiles.count) files")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Company List
            if isLoading {
                ProgressView("Loading companies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companies.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: Brand.IconSize.feature))
                        .foregroundStyle(.secondary)
                    
                    Text("No companies yet")
                        .font(.headline)
                    
                    Text("Add companies in Settings → Memories to enable custom vocabulary and name recognition.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // No company option
                        CompanyOptionRow(
                            title: "No Company",
                            subtitle: "Use default transcription without custom vocabulary",
                            icon: "waveform",
                            isSelected: selectedCompanyId == nil,
                            action: { selectedCompanyId = nil }
                        )
                        
                        Divider()
                            .padding(.leading, 56)
                        
                        // Company options
                        ForEach(companies) { company in
                            CompanyOptionRow(
                                title: company.name,
                                subtitle: company.notes ?? "Custom vocabulary will be used",
                                icon: "building.2",
                                isSelected: selectedCompanyId == company.id,
                                action: { selectedCompanyId = company.id }
                            )
                            
                            if company.id != companies.last?.id {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .background(Color.clear)
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Start Transcription") {
                    onComplete(selectedCompanyId)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .task {
            await loadCompanies()
        }
    }
    
    private func loadCompanies() async {
        let loaded = await MemoryService.shared.getAllCompanies()
        await MainActor.run {
            self.companies = loaded.sorted { $0.name < $1.name }
            self.isLoading = false
        }
    }
}

struct CompanyOptionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? Brand.primary : .secondary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Brand.primary)
                        .font(.title3)
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(isSelected ? Brand.primaryLight : Color.clear)
    }
}

// MARK: - Assign Company Sheet (for existing jobs)

@available(macOS 26.0, *)
struct AssignCompanySheet: View {
    @Environment(\.dismiss) private var dismiss
    let job: TranscriptionJob
    let onComplete: (UUID?) -> Void
    
    @State private var companies: [Company] = []
    @State private var selectedCompanyId: UUID?
    @State private var isLoading = true
    @State private var showingCompanyEditor = false
    @State private var editingCompany: Company?
    @State private var showingCompanyDetail: Company?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign to Company")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select a company to associate this transcription with. This affects metadata only and won't re-transcribe the audio.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .foregroundStyle(.secondary)
                    Text(job.audioFile.filename)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Company List
            if isLoading {
                ProgressView("Loading companies...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if companies.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "building.2")
                        .font(.system(size: Brand.IconSize.feature))
                        .foregroundStyle(.secondary)
                    
                    Text("No companies yet")
                        .font(.headline)
                    
                    Text("Create a company to organize your transcriptions and manage contacts.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    Button(action: { showingCompanyEditor = true }) {
                        Label("New Company", systemImage: "plus.circle.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // New Company Button
                    HStack {
                        Button(action: { showingCompanyEditor = true }) {
                            Label("New Company", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    
                    Divider()
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // No company option
                            CompanyOptionRow(
                                title: "No Company",
                                subtitle: "Remove company assignment",
                                icon: "waveform",
                                isSelected: selectedCompanyId == nil,
                                action: { selectedCompanyId = nil }
                            )
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Company options with management
                            ForEach(companies) { company in
                                CompanyManagementRow(
                                    company: company,
                                    isSelected: selectedCompanyId == company.id,
                                    onSelect: { selectedCompanyId = company.id },
                                    onEdit: { 
                                        editingCompany = company
                                        showingCompanyEditor = true
                                    },
                                    onManage: { showingCompanyDetail = company },
                                    onDelete: { deleteCompany(company) }
                                )
                                
                                if company.id != companies.last?.id {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                            }
                        }
                    }
                    .background(Color.clear)
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("Assign") {
                    onComplete(selectedCompanyId)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
        .task {
            await loadCompanies()
        }
        .sheet(isPresented: $showingCompanyEditor) {
            CompanyEditorSheet(company: editingCompany) {
                editingCompany = nil
                Task { await loadCompanies() }
            }
        }
        .sheet(item: $showingCompanyDetail) { company in
            CompanyContactsSheet(company: company) {
                Task { await loadCompanies() }
            }
        }
    }
    
    private func loadCompanies() async {
        let loaded = await MemoryService.shared.getAllCompanies()
        await MainActor.run {
            self.companies = loaded.sorted { $0.name < $1.name }
            // Pre-select current company if any
            self.selectedCompanyId = job.companyId
            self.isLoading = false
        }
    }
    
    private func deleteCompany(_ company: Company) {
        Task {
            do {
                try await MemoryService.shared.deleteCompany(company.id)
                await loadCompanies()
            } catch {
                print("Failed to delete company: \(error)")
            }
        }
    }
}

// MARK: - Company Management Row

@available(macOS 26.0, *)
struct CompanyManagementRow: View {
    let company: Company
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onManage: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection button
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.title2)
                        .foregroundStyle(isSelected ? Brand.primary : .secondary)
                        .frame(width: 32)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(company.name)
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Text(company.notes ?? "No description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Brand.primary)
                            .font(.title3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            // Management buttons
            Menu {
                Button(action: onManage) {
                    Label("Manage Contacts", systemImage: "person.2")
                }
                
                Button(action: onEdit) {
                    Label("Edit Company", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete Company", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding()
        .background(isSelected ? Brand.primaryLight : Color.clear)
    }
}

// MARK: - Company Editor Sheet

@available(macOS 26.0, *)
struct CompanyEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let company: Company?
    let onComplete: () -> Void
    
    @State private var name = ""
    @State private var domain = ""
    @State private var notes = ""
    @State private var isSaving = false
    
    var isEditing: Bool { company != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(isEditing ? "Edit Company" : "New Company")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(isEditing ? "Update company information." : "Create a new company to organize transcriptions and manage contacts.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section {
                    TextField("Company Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Domain (optional)", text: $domain)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Notes (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    TextEditor(text: $notes)
                        .frame(height: 80)
                        .border(Color(nsColor: .separatorColor), width: 1)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Create") {
                    saveCompany()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 450, height: 350)
        .task {
            if let company = company {
                name = company.name
                domain = company.domain ?? ""
                notes = company.notes ?? ""
            }
        }
    }
    
    private func saveCompany() {
        isSaving = true
        
        Task {
            do {
                if let existing = company {
                    // Update existing
                    var updated = existing
                    updated.name = name
                    updated.domain = domain.isEmpty ? nil : domain
                    updated.notes = notes.isEmpty ? nil : notes
                    try await MemoryService.shared.updateCompany(updated)
                } else {
                    // Create new
                    let newCompany = Company(
                        name: name,
                        domain: domain.isEmpty ? nil : domain,
                        notes: notes.isEmpty ? nil : notes
                    )
                    try await MemoryService.shared.createCompany(newCompany)
                }
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Failed to save company: \(error)")
                isSaving = false
            }
        }
    }
}

// MARK: - Company Contacts Sheet

@available(macOS 26.0, *)
struct CompanyContactsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let company: Company
    let onComplete: () -> Void
    
    @State private var people: [Person] = []
    @State private var isLoading = true
    @State private var showingPersonEditor = false
    @State private var editingPerson: Person?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(company.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Manage contacts for this company")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Content
            if isLoading {
                ProgressView("Loading contacts...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    // Add Contact Button
                    HStack {
                        Button(action: { showingPersonEditor = true }) {
                            Label("New Contact", systemImage: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                        
                        Spacer()
                        
                        Text("\(people.count) contacts")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.clear)
                    
                    Divider()
                    
                    if people.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "person.2")
                                .font(.system(size: Brand.IconSize.feature))
                                .foregroundStyle(.secondary)
                            
                            Text("No contacts yet")
                                .font(.headline)
                            
                            Text("Add contacts to improve name recognition during transcription")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(people) { person in
                                    PersonRow(
                                        person: person,
                                        onEdit: {
                                            editingPerson = person
                                            showingPersonEditor = true
                                        },
                                        onDelete: { deletePerson(person) }
                                    )
                                    
                                    if person.id != people.last?.id {
                                        Divider()
                                            .padding(.leading, 56)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Actions
            HStack {
                Spacer()
                
                Button("Done") {
                    onComplete()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 500, height: 500)
        .task {
            await loadPeople()
        }
        .sheet(isPresented: $showingPersonEditor) {
            PersonEditorSheet(person: editingPerson, companyId: company.id) {
                editingPerson = nil
                Task { await loadPeople() }
            }
        }
    }
    
    private func loadPeople() async {
        let loaded = await MemoryService.shared.getPeopleForCompany(company.id)
        await MainActor.run {
            self.people = loaded.sorted { $0.fullName < $1.fullName }
            self.isLoading = false
        }
    }
    
    private func deletePerson(_ person: Person) {
        Task {
            do {
                try await MemoryService.shared.deletePerson(person.id)
                await loadPeople()
            } catch {
                print("Failed to delete person: \(error)")
            }
        }
    }
}

// MARK: - Person Row

@available(macOS 26.0, *)
struct PersonRow: View {
    let person: Person
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(person.fullName)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let phonetic = person.phoneticSpelling {
                    Text("Phonetic: \(phonetic)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let title = person.title {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No phonetic spelling")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            Menu {
                Button(action: onEdit) {
                    Label("Edit", systemImage: "pencil")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding()
    }
}

// MARK: - Person Editor Sheet

@available(macOS 26.0, *)
struct PersonEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person?
    let companyId: UUID
    let onComplete: () -> Void
    
    @State private var fullName = ""
    @State private var preferredName = ""
    @State private var title = ""
    @State private var email = ""
    @State private var phoneticSpelling = ""
    @State private var isSaving = false
    
    var isEditing: Bool { person != nil }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(isEditing ? "Edit Contact" : "New Contact")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(isEditing ? "Update contact information." : "Add a contact to improve name recognition during transcription.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            
            Divider()
            
            // Form
            Form {
                Section {
                    TextField("Full Name", text: $fullName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Preferred Name (optional)", text: $preferredName)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Title (optional)", text: $title)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Email (optional)", text: $email)
                        .textFieldStyle(.roundedBorder)
                    
                    TextField("Phonetic Spelling (optional)", text: $phoneticSpelling)
                        .textFieldStyle(.roundedBorder)
                    
                    Text("Example: \"Lane not Wayne\" to help avoid misinterpretations")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .scrollDisabled(true)
            
            Divider()
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button(isEditing ? "Save" : "Add") {
                    savePerson()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(fullName.isEmpty || isSaving)
            }
            .padding()
        }
        .frame(width: 450, height: 420)
        .task {
            if let person = person {
                fullName = person.fullName
                preferredName = person.preferredName ?? ""
                title = person.title ?? ""
                email = person.email ?? ""
                phoneticSpelling = person.phoneticSpelling ?? ""
            }
        }
    }
    
    private func savePerson() {
        isSaving = true
        
        Task {
            do {
                if let existing = person {
                    // Update existing
                    var updated = existing
                    updated.fullName = fullName
                    updated.preferredName = preferredName.isEmpty ? nil : preferredName
                    updated.title = title.isEmpty ? nil : title
                    updated.email = email.isEmpty ? nil : email
                    updated.phoneticSpelling = phoneticSpelling.isEmpty ? nil : phoneticSpelling
                    try await MemoryService.shared.updatePerson(updated, companyId: companyId)
                } else {
                    // Create new
                    let newPerson = Person(
                        fullName: fullName,
                        preferredName: preferredName.isEmpty ? nil : preferredName,
                        title: title.isEmpty ? nil : title,
                        email: email.isEmpty ? nil : email,
                        phoneticSpelling: phoneticSpelling.isEmpty ? nil : phoneticSpelling
                    )
                    try await MemoryService.shared.addPerson(newPerson, to: companyId)
                }
                
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Failed to save person: \(error)")
                isSaving = false
            }
        }
    }
}
