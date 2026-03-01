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
        .frame(minWidth: 900, minHeight: 600)
        .tint(.blue)
    }
}
