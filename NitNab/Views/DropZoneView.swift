//
//  DropZoneView.swift
//  NitNab
//

import SwiftUI
import UniformTypeIdentifiers

@available(macOS 26.0, *)
struct DropZoneView: View {
    @ObservedObject var viewModel: TranscriptionViewModel
    @State private var isTargeted = false
    @State private var showingFilePicker = false
    
    var body: some View {
        VStack(spacing: Brand.Spacing.xl) {
            // Icon
            Image(systemName: isTargeted ? "arrow.down.doc.fill" : "waveform.badge.plus")
                .font(.system(size: Brand.IconSize.hero))
                .foregroundStyle(isTargeted ? AnyShapeStyle(Brand.gradient) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: isTargeted)
            
            // Title
            Text(isTargeted ? "Drop Files Here" : "Add Audio Files")
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            VStack(spacing: Brand.Spacing.xs) {
                Text("Drag and drop audio files or click to browse")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                Text("Supports: M4A, WAV, MP3, AIFF, CAF, FLAC")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Browse Button
            Button(action: { 
                showingFilePicker = true
            }) {
                Label("Browse Files", systemImage: "folder")
                    .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Brand.Radius.xl)
                .strokeBorder(
                    isTargeted ? Brand.primary : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [10, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: Brand.Radius.xl)
                        .fill(isTargeted ? Brand.primaryLight : Color.clear)
                )
        )
        .padding(Brand.Spacing.xxxl)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            handleDrop(providers: providers)
            return true
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: AudioFileManager.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.addFilesDirectly(urls)
            case .failure:
                break
            }
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else {
                    return
                }
                
                DispatchQueue.main.async {
                    viewModel.addFilesDirectly([url])
                }
            }
        }
    }
}
