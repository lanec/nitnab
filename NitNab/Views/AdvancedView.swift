//
//  AdvancedView.swift
//  NitNab
//
//  Advanced mode - power user features (search, tags, company context)
//

import SwiftUI

@available(macOS 26.0, *)
struct AdvancedView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var selectedTag: String?
    @State private var sortOption: SortOption = .dateAdded
    @State private var showingFilePicker = false
    @State private var filteredJobIDs: [UUID] = []
    @State private var tagCounts: [(tag: String, count: Int)] = []
    @FocusState private var isFileListFocused: Bool
    
    enum SortOption: String, CaseIterable {
        case dateAdded = "Date Added"
        case dateModified = "Date Modified"
        case dateCompleted = "Date Completed"
        case alphabetical = "A-Z"
    }
    
    private var filteredJobs: [TranscriptionJob] {
        viewModel.jobs(for: filteredJobIDs)
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
            selectAll: { viewModel.selectAllVisible(filteredJobIDs) },
            clearSelection: { viewModel.clearSelection() },
            requestDelete: { viewModel.requestDeleteForCurrentSelection() },
            canSelectAll: !filteredJobIDs.isEmpty,
            canDelete: !viewModel.selectedJobIDs.isEmpty
        )
    }

    private func recomputeTagCounts() {
        var counts: [String: Int] = [:]
        for job in viewModel.jobs {
            for tag in job.tags ?? [] {
                counts[tag, default: 0] += 1
            }
        }
        let ordered = counts
            .map { (tag: $0.key, count: $0.value) }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.tag.localizedCompare(rhs.tag) == .orderedAscending
                }
                return lhs.count > rhs.count
            }
        tagCounts = ordered
    }

    private func recomputeFilteredJobs() {
        var jobs = viewModel.jobs
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)

        if isSearching && !query.isEmpty {
            jobs = jobs.filter { job in
                job.displayName.localizedCaseInsensitiveContains(query) ||
                job.result?.fullTranscript.localizedCaseInsensitiveContains(query) == true ||
                job.description?.localizedCaseInsensitiveContains(query) == true
            }
        }

        if let selectedTag {
            jobs = jobs.filter { job in
                job.tags?.contains(selectedTag) == true
            }
        }

        switch sortOption {
        case .dateAdded:
            jobs.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            jobs.sort { ($0.modifiedAt ?? $0.createdAt) > ($1.modifiedAt ?? $1.createdAt) }
        case .dateCompleted:
            jobs.sort { ($0.completedAt ?? Date.distantPast) > ($1.completedAt ?? Date.distantPast) }
        case .alphabetical:
            jobs.sort { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        }

        let ids = jobs.map(\.id)
        if filteredJobIDs != ids {
            filteredJobIDs = ids
        }
        viewModel.syncSelectionAfterJobsMutation(visibleIDs: ids)
    }

    private func recomputeDerivedState() {
        recomputeTagCounts()
        recomputeFilteredJobs()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Advanced Controls
            HeaderView(viewModel: viewModel)
            
            Divider()
            
            // Advanced Mode Layout
            HSplitView {
                // Left Sidebar: Advanced Features
                VStack(alignment: .leading, spacing: 16) {
                    // Search Bar
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Search", systemImage: "magnifyingglass")
                            .font(.headline)
                        
                        SearchBarView(
                            searchQuery: $searchQuery,
                            isSearching: $isSearching,
                            onSearch: {}
                        )
                        
                        if isSearching {
                            Text("\(filteredJobIDs.count) results")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(Brand.Spacing.md)
                    .brandCard()

                    // Tag Cloud
                    VStack(alignment: .leading, spacing: Brand.Spacing.xs) {
                        Label("Topics", systemImage: "tag")
                            .font(.headline)
                        
                        if tagCounts.isEmpty {
                            Text("No topics yet. Topics are automatically extracted from transcripts.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            TagCloudView(
                                tags: tagCounts,
                                selectedTag: selectedTag,
                                onTagSelected: { tag in
                                    selectedTag = tag.isEmpty ? nil : tag
                                }
                            )
                        }
                    }
                    .padding(Brand.Spacing.md)
                    .brandCard()

                    Spacer()
                }
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 280)
                .padding()
                
                // Main Content Area
                if filteredJobs.isEmpty && !viewModel.jobs.isEmpty {
                    // No results for filter
                    VStack(spacing: 16) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: Brand.IconSize.feature))
                            .foregroundStyle(.secondary)
                        
                        Text("No Results")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(isSearching ? "No transcripts match '\(searchQuery)'" : "No transcripts with tag '\(selectedTag ?? "")'")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Button("Clear Filters") {
                            searchQuery = ""
                            isSearching = false
                            selectedTag = nil
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.jobs.isEmpty {
                    DropZoneView(viewModel: viewModel)
                } else {
                    HSplitView {
                        // File List with sorting
                        VStack(spacing: 0) {
                            // Sort Controls and Add Files Button
                            HStack {
                                Button(action: { showingFilePicker = true }) {
                                    Label("Add Files", systemImage: "plus")
                                }
                                .buttonStyle(.borderless)
                                .help("Add audio files to transcribe")
                                
                                Divider()
                                    .frame(height: 16)
                                    .padding(.horizontal, 4)
                                
                                Text("Sort:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Picker("Sort", selection: $sortOption) {
                                    ForEach(SortOption.allCases, id: \.self) { option in
                                        Text(option.rawValue).tag(option)
                                    }
                                }
                                .pickerStyle(.menu)
                                
                                Spacer()
                                
                                Text("\(filteredJobIDs.count) files")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, Brand.Spacing.xs)
                            .brandGlass(radius: 0)
                            
                            // Filtered file list
                            List(selection: listSelection) {
                                ForEach(filteredJobs) { job in
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
                        .frame(minWidth: 250, idealWidth: 280, maxWidth: 350)
                        
                        // Transcript View
                        if viewModel.selectedJobIDs.count > 1 {
                            BulkSelectionDetailView(
                                snapshot: viewModel.selectionSnapshot,
                                canDelete: !viewModel.selectedJobIDs.isEmpty,
                                onMoveToTrash: { viewModel.requestDeleteForCurrentSelection() },
                                onClearSelection: { viewModel.clearSelection() }
                            )
                            .frame(minWidth: 400)
                        } else if let selectedJob = viewModel.selectedJob {
                            if selectedJob.status == .completed {
                                TranscriptView(job: selectedJob, viewModel: viewModel)
                                    .frame(minWidth: 400)
                            } else if selectedJob.status == .failed {
                                ErrorDetailView(job: selectedJob)
                                    .frame(minWidth: 400)
                            } else {
                                EmptyTranscriptView()
                                    .frame(minWidth: 400)
                            }
                        } else {
                            EmptyTranscriptView()
                                .frame(minWidth: 400)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFilesDirectly(urls)
            case .failure:
                break
            }
        }
        .onAppear {
            recomputeDerivedState()
        }
        .onChange(of: viewModel.jobsVersion) { _, _ in
            recomputeDerivedState()
        }
        .onChange(of: searchQuery) { _, _ in
            recomputeFilteredJobs()
        }
        .onChange(of: isSearching) { _, _ in
            recomputeFilteredJobs()
        }
        .onChange(of: selectedTag) { _, _ in
            recomputeFilteredJobs()
        }
        .onChange(of: sortOption) { _, _ in
            recomputeFilteredJobs()
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize
        var frames: [CGRect]
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var frames: [CGRect] = []
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }
            
            self.frames = frames
            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
