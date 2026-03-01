//
//  ContentView.swift
//  NitNab
//

import SwiftUI

@available(macOS 26.0, *)
struct ContentView: View {
    @StateObject private var viewModel = TranscriptionViewModel()
    @AppStorage("alwaysOpenAdvancedMode") private var alwaysOpenAdvancedMode = false
    @State private var showAdvancedMode = false

    var body: some View {
        Group {
            if showAdvancedMode {
                AdvancedView(viewModel: viewModel)
            } else {
                StandardView(viewModel: viewModel)
            }
        }
        .tint(.blue)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button(action: { showAdvancedMode.toggle() }) {
                    Label(
                        showAdvancedMode ? "Simple Mode" : "Advanced Mode",
                        systemImage: showAdvancedMode ? "list.bullet" : "square.grid.2x2"
                    )
                }
                .help(showAdvancedMode ? "Switch to Simple Mode" : "Switch to Advanced Mode")
            }
        }
        .onAppear {
            showAdvancedMode = alwaysOpenAdvancedMode
        }
        .confirmationDialog(
            "Move to Trash",
            isPresented: $viewModel.showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Move to Trash", role: .destructive) {
                viewModel.confirmPendingDelete()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingDelete()
            }
        } message: {
            Text(viewModel.deleteConfirmationMessage)
        }
        .alert("Error", isPresented: $viewModel.showingError) {
            Button("OK") { }
            if viewModel.errorMessage?.contains("permission") == true {
                Button("Open Settings") {
                    viewModel.openSystemSettings()
                }
            }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred")
        }
        .alert("Duplicate Files Detected", isPresented: $viewModel.showingDuplicateWarning) {
            Button("OK") { }
        } message: {
            let fileList = viewModel.duplicateFiles.map { $0.filename }.joined(separator: "\n")
            Text("The following files are duplicates and were not added:\n\n\(fileList)")
        }
    }
}

struct EmptyTranscriptView: View {
    var body: some View {
        VStack(spacing: Brand.Spacing.md) {
            Image(systemName: "mic.fill")
                .font(.system(size: Brand.IconSize.hero))
                .foregroundStyle(Brand.gradient)

            Text("No Transcript Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Complete a transcription to view results here")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ErrorDetailView: View {
    let job: TranscriptionJob

    var body: some View {
        VStack(spacing: Brand.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: Brand.IconSize.hero))
                .foregroundStyle(Brand.error)

            Text("Transcription Failed")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: Brand.Spacing.sm) {
                Text("File:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(job.audioFile.filename)
                    .font(.body)
                    .fontWeight(.medium)

                Text("Error:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(job.error ?? "Unknown error")
                    .font(.body)
                    .foregroundStyle(Brand.error)
            }
            .padding(Brand.Spacing.md)
            .frame(maxWidth: 500)
            .brandCard()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

@available(macOS 26.0, *)
#Preview {
    ContentView()
}
