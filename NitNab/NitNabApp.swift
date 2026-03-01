//
//  NitNabApp.swift
//  NitNab - Nifty Instant Transcription Nifty AutoSummarize Buddy
//
//  Created by Lane Campbell (@lanec)
//  Available at: https://github.com/lanec/nitnab
//  Website: https://www.nitnab.com
//

import SwiftUI

@available(macOS 26.0, *)
@main
struct NitNabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            FileListCommands()
        }
        
        Settings {
            SettingsView()
        }
    }
}

@available(macOS 26.0, *)
struct FileListCommands: Commands {
    @FocusedValue(\.fileListCommandActions) private var actions

    var body: some Commands {
        CommandMenu("Selection") {
            Button("Select All Files") {
                actions?.selectAll()
            }
            .keyboardShortcut("a", modifiers: .command)
            .disabled(!(actions?.canSelectAll ?? false))

            Button("Clear Selection") {
                actions?.clearSelection()
            }
            .keyboardShortcut(.escape, modifiers: [])
            .disabled(!(actions?.canDelete ?? false))

            Button("Move Selected to Trash…") {
                actions?.requestDelete()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(!(actions?.canDelete ?? false))

            Button("Move Selected to Trash…") {
                actions?.requestDelete()
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(!(actions?.canDelete ?? false))
        }
    }
}
