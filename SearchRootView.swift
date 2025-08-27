//
//  SearchRootView.swift
//

import SwiftUI

struct SearchRootView: View {
    @State private var query = ""
    @State private var showResults = false
    @State private var trendingTags: [String] = []
    @State private var suggestions: [String] = []

    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 48))
                    .opacity(0.15)
                Text("Search accounts or #tags")
                    .foregroundColor(.secondary)
                Spacer()
            }
            .navigationTitle("Search")
        }
        .searchable(text: $query, prompt: "Username or #tag") {
            ForEach(suggestions, id: \.self) { tag in
                Text("#\(tag)").searchCompletion("#\(tag)")
            }
        }
        .onSubmit(of: .search) {
            if !query.isEmpty { showResults = true }
        }
        .onChange(of: query) { _ in Task { await updateSuggestions() } }
        .sheet(isPresented: $showResults) {
            SearchResultsView(query: query)
                .presentationDetents([.large])
        }
        .task { await loadTags() }
    }

    // ────────── Suggestions helpers ──────────
    @MainActor
    private func loadTags() async {
        do {
            trendingTags = try await NetworkService.shared.fetchTopHashtags()
            suggestions = trendingTags
        } catch {
            trendingTags = []
            suggestions = []
        }
    }

    @MainActor
    private func updateSuggestions() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("#") else { suggestions = []; return }
        let prefix = trimmed.dropFirst().lowercased()
        do {
            let dynamic = try await NetworkService.shared.suggestHashtags(prefix: String(prefix))
            suggestions = dynamic
        } catch {
            suggestions = trendingTags.filter { $0.hasPrefix(prefix) }
        }
    }
}
