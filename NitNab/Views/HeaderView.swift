//
//  HeaderView.swift
//  NitNab
//

import SwiftUI

@available(macOS 26.0, *)
struct HeaderView: View {
    @ObservedObject var viewModel: TranscriptionViewModel

    var body: some View {
        HStack(spacing: Brand.Spacing.md) {
            // Logo and Title
            HStack(spacing: Brand.Spacing.sm) {
                if let inAppIcon = NSImage(named: "AppIconInAppLight") {
                    Image(nsImage: inAppIcon)
                        .resizable()
                        .frame(width: 40, height: 40)
                        .clipShape(.rect(cornerRadius: 10, style: .continuous))
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Brand.gradient)
                }

                VStack(alignment: .leading, spacing: Brand.Spacing.xxs) {
                    Text("NitNab")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Nifty Instant Transcription Nifty AutoSummarize Buddy")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            // Language Picker
            if !viewModel.jobs.isEmpty {
                Picker("Language", selection: $viewModel.selectedLocale) {
                    ForEach(viewModel.supportedLocales, id: \.identifier) { locale in
                        Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                            .tag(locale)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .disabled(viewModel.isProcessing)
            }

            // Control Buttons
            if !viewModel.jobs.isEmpty {
                HStack(spacing: Brand.Spacing.xs) {
                    if viewModel.isProcessing {
                        Button(action: { viewModel.cancelProcessing() }) {
                            Label("Cancel", systemImage: "stop.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.error)
                    } else {
                        Button(action: { viewModel.startProcessing() }) {
                            Label("Start Transcription", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Brand.primary)
                        .disabled(!viewModel.canStartProcessing)

                        Menu {
                            Button("Clear Completed", action: { viewModel.clearCompleted() })
                            Button("Clear All", action: { viewModel.clearAll() })
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .menuStyle(.borderlessButton)
                    }
                }
            }
        }
        .padding(Brand.Spacing.md)
        .brandGlass(radius: 0)
    }
}
