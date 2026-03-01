//
//  TagCloudView.swift
//  NitNab
//
//  Tag cloud visualization for topics
//

import SwiftUI

struct TagCloudView: View {
    let tags: [(tag: String, count: Int)]
    let selectedTag: String?
    var onTagSelected: (String) -> Void
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(tags, id: \.tag) { tagData in
                TagButton(
                    tag: tagData.tag,
                    count: tagData.count,
                    isSelected: selectedTag == tagData.tag,
                    maxCount: tags.map(\.count).max() ?? 1
                ) {
                    if selectedTag == tagData.tag {
                        onTagSelected("")  // Deselect
                    } else {
                        onTagSelected(tagData.tag)
                    }
                }
            }
        }
    }
}

struct TagButton: View {
    let tag: String
    let count: Int
    let isSelected: Bool
    let maxCount: Int
    let action: () -> Void
    
    private var fontSize: CGFloat {
        let ratio = Double(count) / Double(max(maxCount, 1))
        return 11 + (ratio * 8)  // 11-19pt
    }
    
    private var opacity: Double {
        let ratio = Double(count) / Double(max(maxCount, 1))
        return 0.5 + (ratio * 0.5)  // 0.5-1.0
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(tag)
                    .font(.system(size: fontSize))
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(isSelected ? Brand.primary : Brand.primaryMedium)
            .foregroundStyle(isSelected ? .white : Brand.primary)
            .opacity(isSelected ? 1.0 : opacity)
            .continuousRadius(Brand.Radius.sm)
        }
        .buttonStyle(.plain)
    }
}
