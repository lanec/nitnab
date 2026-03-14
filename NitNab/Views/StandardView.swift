//
//  StandardView.swift
//  NitNab
//
//  Simple mode - clean interface for basic transcription
//

import SwiftUI

@available(macOS 26.0, *)
struct StandardView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(viewModel: viewModel)
            
            Divider()
            
            // Main Content
            if viewModel.jobs.isEmpty {
                DropZoneView(viewModel: viewModel)
            } else {
                HSplitView {
                    // Left: File List
                    FileListView(viewModel: viewModel)
                        .frame(minWidth: 250, idealWidth: 280, maxWidth: 350)
                    
                    // Right: Transcript View
                    if viewModel.selectionSnapshot.count > 1 {
                        MultiSelectionDetailView(
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
        .frame(minWidth: 900, minHeight: 600)
        .tint(.blue)
    }
}

@available(macOS 26.0, *)
struct MultiSelectionDetailView: View {
    let snapshot: TranscriptionViewModel.SelectionSnapshot
    let canDelete: Bool
    let onMoveToTrash: () -> Void
    let onClearSelection: () -> Void

    private var groupedStatuses: [(status: TranscriptionStatus, count: Int)] {
        let counts = snapshot.statusCounts
        let orderedStatuses: [TranscriptionStatus] = [.pending, .processing, .completed, .failed, .cancelled]
        return orderedStatuses.compactMap { status in
            guard let count = counts[status], count > 0 else { return nil }
            return (status, count)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Brand.Spacing.lg) {
            VStack(alignment: .leading, spacing: Brand.Spacing.xs) {
                Text("\(snapshot.count) Files Selected")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Use bulk actions to manage selected files.")
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: Brand.Spacing.sm) {
                Text("Status Breakdown")
                    .font(.headline)

                ForEach(groupedStatuses, id: \.status) { item in
                    HStack {
                        Text(label(for: item.status))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(item.count)")
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(Brand.Spacing.md)
            .brandCard()

            HStack(spacing: Brand.Spacing.sm) {
                Button("Move Selected to Trash…", role: .destructive, action: onMoveToTrash)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canDelete)

                Button("Clear Selection", action: onClearSelection)
                    .buttonStyle(.bordered)
            }

            Spacer()
        }
        .padding(Brand.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func label(for status: TranscriptionStatus) -> String {
        switch status {
        case .pending:
            return "Pending"
        case .processing:
            return "Processing"
        case .completed:
            return "Completed"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Cancelled"
        }
    }
}
