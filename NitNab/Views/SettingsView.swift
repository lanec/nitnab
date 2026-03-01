//
//  SettingsView.swift
//  NitNab
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultLocale") private var defaultLocale = "en-US"
    @AppStorage("autoStartTranscription") private var autoStartTranscription = false
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "txt"
    
    var body: some View {
        TabView {
            GeneralSettingsView()
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
            
            ExportSettingsView(defaultExportFormat: $defaultExportFormat)
                .tabItem {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            
            MemoriesSettingsView()
                .tabItem {
                    Label("Memories", systemImage: "brain.head.profile")
                }
            
            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 600, height: 500)
    }
}

struct GeneralSettingsView: View {
    @AppStorage("defaultLocale") private var defaultLocale = "en-US"
    @AppStorage("autoStartTranscription") private var autoStartTranscription = false
    @AppStorage("defaultExportFormat") private var defaultExportFormat = "markdown"
    @AppStorage("autoPersist") private var autoPersist = true
    @AppStorage("alwaysOpenAdvancedMode") private var alwaysOpenAdvancedMode = false
    @State private var supportedLocales: [Locale] = []
    @State private var isiCloudAvailable: Bool = false
    @State private var storagePath: String = "Not configured"
    
    var body: some View {
        Form {
            Section {
                Toggle("Always open in Advanced Mode", isOn: $alwaysOpenAdvancedMode)
                    .help("Show advanced features (search, tag cloud, company context) on launch")
            } header: {
                Text("Interface")
            }
            
            Section {
                Picker("Default Language", selection: $defaultLocale) {
                    ForEach(supportedLocales, id: \.identifier) { locale in
                        Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                            .tag(locale.identifier)
                    }
                }
                
                Toggle("Auto-start transcription when files are added", isOn: $autoStartTranscription)
            } header: {
                Text("Transcription")
            }
            
            Section {
                Toggle("Automatically save transcripts", isOn: $autoPersist)
                    .help("Save audio files, transcripts, summaries, and chat history to your chosen folder")
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage Location")
                        .font(.headline)
                    
                    Text(storagePath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    HStack(spacing: 12) {
                        if isiCloudAvailable {
                            Button("Use iCloud Drive") {
                                selectiCloudDrive()
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Choose Folder...") {
                            selectCustomFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(.vertical, 4)
                
                if isiCloudAvailable {
                    Label("iCloud Drive will sync data across your devices", systemImage: "icloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Persistence")
            } footer: {
                Text("All files are stored locally in a folder structure: audio file, transcript.txt, summary.txt, and chat.json")
                    .font(.caption)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            Task {
                supportedLocales = await TranscriptionService.shared.getSupportedLocales()
                await loadStorageInfo()
            }
        }
        .onChange(of: autoPersist) { _, _ in
            Task {
                await loadStorageInfo()
            }
        }
    }
    
    private func loadStorageInfo() async {
        isiCloudAvailable = await PersistenceService.shared.isiCloudAvailable()
        
        // getStoragePath() always returns iCloud path as default if nothing is set
        if let path = await PersistenceService.shared.getStoragePath() {
            await MainActor.run {
                storagePath = path.path
            }
        } else {
            // Only happens if iCloud is completely unavailable
            await MainActor.run {
                storagePath = "iCloud Drive not available - please sign in to iCloud"
            }
        }
    }
    
    private func selectiCloudDrive() {
        Task {
            let containerID = "iCloud.\(Bundle.main.bundleIdentifier ?? "com.example.nitnab")"
            if let iCloudPath = FileManager.default.url(forUbiquityContainerIdentifier: containerID) {
                let nitnabPath = iCloudPath.appendingPathComponent("Documents/NitNab")
                await PersistenceService.shared.setStoragePath(nitnabPath)
                try? await PersistenceService.shared.ensureStoragePathExists()
                await loadStorageInfo()
            }
        }
    }
    
    private func selectCustomFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select Storage Folder"
        panel.message = "Choose where to store transcripts, summaries, and chat history"
        
        panel.begin { response in
            if response == .OK, let url = panel.url {
                Task {
                    await PersistenceService.shared.setStoragePath(url)
                    try? await PersistenceService.shared.ensureStoragePathExists()
                    await loadStorageInfo()
                }
            }
        }
    }
}

struct ExportSettingsView: View {
    @Binding var defaultExportFormat: String
    var body: some View {
        Form {
            Section {
                Picker("Default Export Format", selection: $defaultExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.fileExtension) { format in
                        Text(format.rawValue).tag(format.fileExtension)
                    }
                }
            } header: {
                Text("Export Options")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: Brand.IconSize.hero))
                .foregroundStyle(Brand.primary)
            
            Text("NitNab")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Nifty Instant Transcription\nNifty AutoSummarize Buddy")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            
            VStack(spacing: 8) {
                Text("Version 1.0.2")
                    .font(.caption)
                
                Text("Built with ❤️ by Lane Campbell (@lanec)")
                    .font(.caption)
            }
            .foregroundStyle(.tertiary)
            
            Divider()
                .padding(.horizontal, 40)
            
            VStack(spacing: 12) {
                Link(destination: URL(string: "https://www.nitnab.com")!) {
                    Label("Visit Website", systemImage: "globe")
                }
                
                Link(destination: URL(string: "https://github.com/lanec/nitnab")!) {
                    Label("View on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }
            .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    SettingsView()
}
