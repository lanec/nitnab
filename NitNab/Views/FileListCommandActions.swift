//
//  FileListCommandActions.swift
//  NitNab
//

import SwiftUI

@available(macOS 26.0, *)
struct FileListCommandActions {
    let selectAll: () -> Void
    let clearSelection: () -> Void
    let requestDelete: () -> Void
    let canSelectAll: Bool
    let canDelete: Bool
}

@available(macOS 26.0, *)
private struct FileListCommandActionsKey: FocusedValueKey {
    typealias Value = FileListCommandActions
}

@available(macOS 26.0, *)
extension FocusedValues {
    var fileListCommandActions: FileListCommandActions? {
        get { self[FileListCommandActionsKey.self] }
        set { self[FileListCommandActionsKey.self] = newValue }
    }
}
