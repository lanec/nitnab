//
//  TranscriptView.swift
//  NitNab
//

import SwiftUI

@available(macOS 26.0, *)
struct TranscriptView: View {
    let job: TranscriptionJob
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var selectedTab = 0
    @State private var summary: String = ""
    @State private var isGeneratingSummary = false
    @State private var summaryError: String?
    @State private var isLoadingSummary = false
    @State private var showingCompanyAssignment = false

    // Get the current job from viewModel to reflect live updates
    private var currentJob: TranscriptionJob {
        viewModel.jobs.first(where: { $0.id == job.id }) ?? job
    }

    /// Contextual tint per tab (Brand Guide §Contextual Tint)
    private var contextualTint: Color {
        switch selectedTab {
        case 0: .blue
        case 1: .indigo
        case 2: .purple
        default: .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: Brand.Spacing.xxs) {
                    Text(currentJob.displayName)
                        .font(.headline)

                    if let result = job.result {
                        HStack(spacing: Brand.Spacing.md) {
                            Label("\(result.wordCount) words", systemImage: "text.word.spacing")
                            Label("\(result.characterCount) chars", systemImage: "textformat.abc")
                            Label(String(format: "%.1f%% confidence", result.confidence * 100), systemImage: "checkmark.seal")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // Action Buttons
                HStack(spacing: Brand.Spacing.xs) {
                    Button(action: { showingCompanyAssignment = true }) {
                        Label("Company", systemImage: "building.2")
                    }
                    .buttonStyle(.bordered)
                    .help("Assign to company")

                    Button(action: { viewModel.showRenameDialog(for: currentJob) }) {
                        Label("Rename", systemImage: "pencil")
                    }
                    .buttonStyle(.bordered)
                    .help("Rename this file")

                    Button(action: { viewModel.showDescriptionDialog(for: currentJob) }) {
                        Label("Description", systemImage: "doc.text")
                    }
                    .buttonStyle(.bordered)
                    .help("Edit description")

                    Button(action: { viewModel.openJobFolder(currentJob) }) {
                        Label("Finder", systemImage: "folder")
                    }
                    .buttonStyle(.bordered)
                    .help("Open folder in Finder")
                    .disabled(currentJob.folderPath == nil)

                    Divider()
                        .frame(height: 20)

                    Menu {
                        Button("Copy to Clipboard", action: { viewModel.copyToClipboard(currentJob) })
                        Divider()
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Button("Export as \(format.rawValue)") {
                                viewModel.exportTranscription(currentJob, format: format)
                            }
                        }
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                    .menuStyle(.borderlessButton)
                }
            }
            .padding(Brand.Spacing.md)
            .brandGlass(radius: 0)

            Divider()

            // Tab Picker
            Picker("View", selection: $selectedTab) {
                Text("Transcript").tag(0)
                Text("Summary").tag(1)
                Text("Chat").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(Brand.Spacing.md)

            // Content
            if let result = job.result {
                TabView(selection: $selectedTab) {
                    FullTranscriptTab(result: result)
                        .tint(.blue)
                        .tag(0)

                    SummaryTab(
                        job: job,
                        result: result,
                        summary: $summary,
                        isGenerating: $isGeneratingSummary,
                        isLoading: $isLoadingSummary,
                        error: $summaryError
                    )
                    .tint(.indigo)
                    .tag(1)
                    .task {
                        await loadSummaryIfNeeded()
                    }

                    ChatTab(job: job, result: result)
                        .tint(.purple)
                        .tag(2)
                }
                .tabViewStyle(.automatic)
            }
        }
        .tint(contextualTint)
        .animation(.easeInOut(duration: 0.2), value: selectedTab)
        .sheet(isPresented: $showingCompanyAssignment) {
            AssignCompanySheet(job: currentJob) { companyId in
                viewModel.assignCompany(companyId, to: currentJob)
            }
        }
    }

    private func loadSummaryIfNeeded() async {
        guard summary.isEmpty && !isLoadingSummary else { return }

        isLoadingSummary = true
        defer { isLoadingSummary = false }

        do {
            if let loadedSummary = try await PersistenceService.shared.loadSummary(for: job) {
                await MainActor.run {
                    summary = loadedSummary
                }
            }
        } catch {
            print("Failed to load summary: \(error.localizedDescription)")
        }
    }
}

@available(macOS 26.0, *)
struct FullTranscriptTab: View {
    let result: TranscriptionResult
    @State private var showCopied = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(result.fullTranscript, forType: .string)
                    showCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopied = false
                    }
                }) {
                    Label(showCopied ? "Copied!" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(Brand.Spacing.md)

            Divider()

            ScrollView {
                Text(result.fullTranscript)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(Brand.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

@available(macOS 26.0, *)
struct SummaryTab: View {
    let job: TranscriptionJob
    let result: TranscriptionResult
    @Binding var summary: String
    @Binding var isGenerating: Bool
    @Binding var isLoading: Bool
    @Binding var error: String?
    @State private var showRegenerateConfirmation = false

    var body: some View {
        ScrollView {
            VStack(spacing: Brand.Spacing.md) {
                if isLoading {
                    VStack(spacing: Brand.Spacing.md) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Loading summary...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if summary.isEmpty && !isGenerating {
                    VStack(spacing: Brand.Spacing.md) {
                        Image(systemName: "sparkles")
                            .font(.system(size: Brand.IconSize.feature))
                            .foregroundStyle(.indigo)

                        Text("Generate AI Summary")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Use Apple Intelligence to create a concise summary of this transcript")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button(action: { generateSummary() }) {
                            Label("Generate Summary", systemImage: "sparkles")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: 400)
                    .padding()
                } else if isGenerating {
                    VStack(spacing: Brand.Spacing.md) {
                        ProgressView()
                            .controlSize(.large)
                        Text("Generating summary...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else if let error = error {
                    VStack(spacing: Brand.Spacing.md) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: Brand.IconSize.feature))
                            .foregroundStyle(Brand.warning)

                        Text("Error")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(error)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Try Again") {
                            self.error = nil
                            generateSummary()
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: 400)
                    .padding()
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Label("AI Summary", systemImage: "sparkles")
                                .font(.headline)

                            Spacer()

                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(summary, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Regenerate") {
                                showRegenerateConfirmation = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(Brand.Spacing.md)

                        Divider()

                        ScrollView {
                            Text(summary)
                                .font(.body)
                                .textSelection(.enabled)
                                .padding(Brand.Spacing.md)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .confirmationDialog(
            "Regenerate Summary?",
            isPresented: $showRegenerateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Regenerate", role: .destructive) {
                generateSummary()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will replace the existing summary with a new one. This action cannot be undone.")
        }
    }

    private func generateSummary() {
        isGenerating = true
        error = nil

        Task {
            do {
                if #available(macOS 26.0, *) {
                    let generatedSummary = try await AIService.shared.generateSummary(transcript: result.fullTranscript)
                    await MainActor.run {
                        summary = generatedSummary
                        isGenerating = false
                    }

                    do {
                        try await PersistenceService.shared.saveSummary(generatedSummary, for: job)
                    } catch {
                        print("Failed to persist summary: \(error.localizedDescription)")
                    }
                } else {
                    throw AIError.modelUnavailable
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}

@available(macOS 26.0, *)
struct ChatTab: View {
    let job: TranscriptionJob
    let result: TranscriptionResult
    @State private var messages: [(role: String, content: String)] = []
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var loadedJobId: UUID? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                LazyVStack(spacing: Brand.Spacing.md) {
                    if messages.isEmpty {
                        VStack(spacing: Brand.Spacing.md) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: Brand.IconSize.feature))
                                .foregroundStyle(.purple)

                            Text("Chat with AI")
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("Ask questions about the transcript, request summaries, or draft emails based on the content")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 400)

                            VStack(alignment: .leading, spacing: Brand.Spacing.xs) {
                                Text("Try asking:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(["Summarize the main points", "Draft an email about this", "What action items were mentioned?"], id: \.self) { suggestion in
                                    Button(action: {
                                        inputText = suggestion
                                    }) {
                                        Text(suggestion)
                                            .font(.caption)
                                            .padding(.horizontal, Brand.Spacing.sm)
                                            .padding(.vertical, 6)
                                            .background(Brand.primaryLight)
                                            .continuousRadius(Brand.Radius.lg)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                    } else {
                        ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                            MessageBubble(role: message.role, content: message.content)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Input
            HStack(spacing: Brand.Spacing.sm) {
                TextField("Ask about the transcript...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(Brand.Spacing.xs)
                    .brandGlass(radius: Brand.Radius.md)
                    .lineLimit(1...5)
                    .disabled(isGenerating)
                    .onSubmit {
                        if !inputText.isEmpty {
                            sendMessage()
                        }
                    }

                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.circle.fill" : "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.purple)
                }
                .buttonStyle(.plain)
                .disabled(inputText.isEmpty && !isGenerating)
            }
            .padding(Brand.Spacing.md)
            .brandGlass(radius: 0)
        }
        .task(id: job.id) {
            await loadChatHistory()
        }
    }

    private func loadChatHistory() async {
        guard loadedJobId != job.id else { return }

        do {
            let loadedMessages = try await PersistenceService.shared.loadChatHistory(for: job)
            await MainActor.run {
                messages = loadedMessages
                loadedJobId = job.id
            }
        } catch {
            // Failed to load chat history
        }
    }

    private func sendMessage() {
        guard !inputText.isEmpty else { return }

        let userMessage = inputText
        inputText = ""

        messages.append((role: "User", content: userMessage))
        isGenerating = true

        Task {
            do {
                if #available(macOS 26.0, *) {
                    let response = try await AIService.shared.chat(
                        message: userMessage,
                        context: result.fullTranscript,
                        conversationHistory: messages
                    )

                    await MainActor.run {
                        messages.append((role: "Assistant", content: response))
                        isGenerating = false
                    }

                    if UserDefaults.standard.bool(forKey: "autoPersist") {
                        do {
                            try await PersistenceService.shared.saveChatHistory(messages, for: job)
                        } catch {
                            print("Failed to persist chat history: \(error.localizedDescription)")
                        }
                    }
                } else {
                    throw AIError.modelUnavailable
                }
            } catch {
                await MainActor.run {
                    messages.append((role: "Assistant", content: "Error: \(error.localizedDescription)"))
                    isGenerating = false
                }
            }
        }
    }
}

@available(macOS 26.0, *)
struct MessageBubble: View {
    let role: String
    let content: String

    var body: some View {
        HStack {
            if role == "User" {
                Spacer()
            }

            VStack(alignment: role == "User" ? .trailing : .leading, spacing: Brand.Spacing.xxs) {
                Text(role)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Text(content)
                    .font(.body)
                    .textSelection(.enabled)
                    .padding(Brand.Spacing.sm)
                    .background(role == "User" ? AnyShapeStyle(Brand.primary) : AnyShapeStyle(.quaternary))
                    .foregroundStyle(role == "User" ? .white : .primary)
                    .continuousRadius(Brand.Radius.lg)
            }
            .frame(maxWidth: 500, alignment: role == "User" ? .trailing : .leading)

            if role == "Assistant" {
                Spacer()
            }
        }
    }
}
