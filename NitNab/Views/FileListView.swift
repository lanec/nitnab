//
//  FileListView.swift
//  NitNab
//

import SwiftUI

@available(macOS 26.0, *)
struct FileListView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var showingFilePicker = false
    @FocusState private var isFileListFocused: Bool

    private var visibleJobIDs: [UUID] {
        viewModel.jobs.map(\.id)
    }

    private var listSelection: Binding<Set<UUID>> {
        Binding(
            get: { viewModel.selectedJobIDs },
            set: { newValue in
                viewModel.setSelection(newValue, primary: viewModel.selectedJobID)
            }
        )
    }

    private var commandActions: FileListCommandActions {
        FileListCommandActions(
            selectAll: { viewModel.selectAllVisible(visibleJobIDs) },
            clearSelection: { viewModel.clearSelection() },
            requestDelete: { viewModel.requestDeleteForCurrentSelection() },
            canSelectAll: !visibleJobIDs.isEmpty,
            canDelete: !viewModel.selectedJobIDs.isEmpty
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Files (\(viewModel.jobs.count))")
                    .font(.headline)

                Spacer()

                Button(action: { showingFilePicker = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isProcessing)
            }
            .padding(Brand.Spacing.md)
            .brandGlass(radius: 0)

            Divider()

            List(selection: listSelection) {
                ForEach(viewModel.jobs) { job in
                    FileRowView(
                        job: job,
                        isSelected: viewModel.selectedJobIDs.contains(job.id),
                        isProcessing: viewModel.isProcessing,
                        onAssignCompany: { companyId in viewModel.assignCompany(companyId, toJobID: job.id) },
                        onShowRenameDialog: { viewModel.showRenameDialog(forJobID: job.id) },
                        onShowDescriptionDialog: { viewModel.showDescriptionDialog(forJobID: job.id) },
                        onCopyTranscript: { viewModel.copyToClipboard(jobID: job.id) },
                        onExport: { format in viewModel.exportTranscription(jobID: job.id, format: format) },
                        onRetry: { viewModel.retryJob(jobID: job.id) },
                        onRequestDelete: { viewModel.requestDeleteFromContextMenu(forJobID: job.id) },
                        onOpenFolder: { viewModel.openJobFolder(jobID: job.id) },
                        onRenameInline: { newName in viewModel.renameJob(jobID: job.id, to: newName) }
                    )
                    .tag(job.id)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .focused($isFileListFocused)
            .focusedSceneValue(\.fileListCommandActions, isFileListFocused ? commandActions : nil)
            .onDeleteCommand {
                viewModel.requestDeleteForCurrentSelection()
            }
            .onExitCommand {
                viewModel.clearSelection()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: AudioFileManager.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFiles(urls)
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
        .sheet(isPresented: $viewModel.showingCompanyPicker) {
            CompanyPickerSheet(
                audioFiles: viewModel.pendingAudioFiles,
                onComplete: { companyId in
                    viewModel.confirmFilesWithCompany(companyId)
                }
            )
        }
    }
}

@available(macOS 26.0, *)
struct FileRowView: View {
    let job: TranscriptionJob
    let isSelected: Bool
    let isProcessing: Bool
    let onAssignCompany: (UUID?) -> Void
    let onShowRenameDialog: () -> Void
    let onShowDescriptionDialog: () -> Void
    let onCopyTranscript: () -> Void
    let onExport: (ExportFormat) -> Void
    let onRetry: () -> Void
    let onRequestDelete: () -> Void
    let onOpenFolder: () -> Void
    let onRenameInline: (String) -> Void

    @State private var showingCompanyAssignment = false
    @State private var isHovering = false
    @State private var isEditingName = false
    @State private var editedName = ""
    @FocusState private var isNameFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                statusIcon

                VStack(alignment: .leading, spacing: 4) {
                    if isEditingName {
                        TextField("Name", text: $editedName)
                            .font(.body)
                            .fontWeight(.medium)
                            .textFieldStyle(.plain)
                            .focused($isNameFieldFocused)
                            .onSubmit { saveName() }
                            .onExitCommand { cancelEditing() }
                    } else {
                        Text(job.displayName)
                            .font(.body)
                            .fontWeight(.medium)
                            .lineLimit(1)
                            .onTapGesture(count: 2) { startEditing() }
                            .help("Double-click to rename")
                    }

                    HStack(spacing: 12) {
                        Label(job.audioFile.formattedDuration, systemImage: "clock")
                        Label(job.audioFile.formattedFileSize, systemImage: "doc")
                        Label(job.audioFile.format, systemImage: "waveform")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if isHovering || isSelected {
                    HStack(spacing: 4) {
                        Button(action: { showingCompanyAssignment = true }) {
                            Image(systemName: "building.2")
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                        .help("Assign to company")

                        Button(action: onShowRenameDialog) {
                            Image(systemName: "pencil")
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                        .help("Rename")

                        Button(action: onShowDescriptionDialog) {
                            Image(systemName: "doc.text")
                                .font(.body)
                        }
                        .buttonStyle(.borderless)
                        .help("Edit description")

                        Divider()
                            .frame(height: 16)

                        Menu {
                            if job.status == .completed {
                                Button("Copy Transcript", action: onCopyTranscript)

                                Divider()

                                Menu("Export As...") {
                                    ForEach(ExportFormat.allCases, id: \.self) { format in
                                        Button(format.rawValue) {
                                            onExport(format)
                                        }
                                    }
                                }

                                Divider()
                            }

                            if job.status == .failed {
                                Button("Retry", action: onRetry)
                                Divider()
                            }

                            Button("Move to Trash…", role: .destructive, action: onRequestDelete)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.body)
                        }
                        .menuStyle(.borderlessButton)
                    }
                    .disabled(isProcessing)
                } else {
                    Image(systemName: "ellipsis.circle")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(job.statusDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if job.status == .processing {
                    ProgressView(value: job.progress)
                        .progressViewStyle(.linear)
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color(nsColor: .separatorColor)),
            alignment: .bottom
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
        .contextMenu {
            Button("Open Folder in Finder", action: onOpenFolder)
                .disabled(job.folderPath == nil)

            Divider()

            Button("Rename", action: onShowRenameDialog)

            Button("Edit Description", action: onShowDescriptionDialog)

            Button("Assign Company") {
                showingCompanyAssignment = true
            }

            Divider()

            if job.status == .completed {
                Button("Copy Transcript", action: onCopyTranscript)
            }

            if job.status == .failed {
                Button("Retry", action: onRetry)
            }

            Divider()

            Button("Move to Trash…", role: .destructive, action: onRequestDelete)
        }
        .overlay(
            isSelected ?
            Rectangle()
                .stroke(Brand.primary, lineWidth: 2)
            : nil
        )
        .sheet(isPresented: $showingCompanyAssignment) {
            AssignCompanySheet(job: job) { companyId in
                onAssignCompany(companyId)
            }
        }
    }

    private func startEditing() {
        editedName = job.customName ?? job.audioFile.filename
        isEditingName = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isNameFieldFocused = true
        }
    }

    private func saveName() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            cancelEditing()
            return
        }

        if trimmedName != job.displayName {
            onRenameInline(trimmedName)
        }

        isEditingName = false
        isNameFieldFocused = false
    }

    private func cancelEditing() {
        isEditingName = false
        isNameFieldFocused = false
        editedName = ""
    }

    private var statusIcon: some View {
        Group {
            switch job.status {
            case .pending:
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
            case .processing:
                ProgressView()
                    .controlSize(.small)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Brand.success)
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Brand.error)
            case .cancelled:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Brand.warning)
            }
        }
        .font(.title3)
        .frame(width: 24)
    }

    private var backgroundColor: Color {
        if isSelected {
            return Brand.primary.opacity(0.15)
        }
        switch job.status {
        case .completed:
            return Brand.success.opacity(0.08)
        case .failed:
            return Brand.error.opacity(0.08)
        case .processing:
            return Brand.primaryLight
        default:
            return .clear
        }
    }
}
