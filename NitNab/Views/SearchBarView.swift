//
//  SearchBarView.swift
//  NitNab
//
//  Global search bar for Advanced Mode
//

import SwiftUI

struct SearchBarView: View {
    @Binding var searchQuery: String
    @Binding var isSearching: Bool
    var onSearch: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            
            TextField("Search all transcripts...", text: $searchQuery)
                .textFieldStyle(.plain)
                .onSubmit {
                    isSearching = !searchQuery.isEmpty
                    onSearch()
                }
                .onChange(of: searchQuery) { _, newValue in
                    if newValue.isEmpty {
                        isSearching = false
                        onSearch()
                    }
                }
            
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    isSearching = false
                    onSearch()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Brand.Spacing.xs)
        .brandGlass(radius: Brand.Radius.md)
    }
}
