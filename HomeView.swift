//
//  HomeView.swift
//  FitSpo
//
//  Masonry feed with pull‑to‑refresh + endless scroll.
//  Updated 2025‑06‑30:
//  • Added separate navigation targets in Hot‑Today row.
//    – Tap 🔥 Hot Today  ➜  HotPostsView (top‑10 feed)
//    – Tap any avatar   ➜  PostDetailView for that post.
//

import SwiftUI
import FirebaseFirestore

struct HomeView: View {

    // ───────── state ─────────────────────────────────────────
    @State private var posts:   [Post]            = []
    @State private var cursor:  DocumentSnapshot? = nil      // Firestore paging cursor

    @State private var reachedEnd    = false
    @State private var isLoadingPage = false
    @State private var isRefreshing  = false

    private let PAGE_SIZE      = 12           // full page size
    private let FIRST_BATCH    = 4            // show first two rows fast
    private let PREFETCH_AHEAD = 4            // when ≤4 remain → fetch
    @State private var lastPrefetchIndex = -1 // prevents duplicate calls



    // Split into two columns
    private var leftColumn:  [Post] { posts.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element) }
    private var rightColumn: [Post] { posts.enumerated().filter { !$0.offset.isMultiple(of: 2) }.map(\.element) }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header

                    // ── Masonry grid
                    if posts.isEmpty && isLoadingPage {
                        skeletonGrid
                    } else {
                        HStack(alignment: .top, spacing: 8) {
                            column(for: leftColumn)
                            column(for: rightColumn)
                        }
                        .padding(.horizontal, 12)
                    }

                    if isLoadingPage && !posts.isEmpty {
                        ProgressView()
                            .padding(.vertical, 32)
                    }

                    if reachedEnd, !posts.isEmpty {
                        Text("No more posts")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 32)
                            .padding(.top, 16)
                    }
                }
            }
            .refreshable { await refresh() }
            .onAppear(perform: initialLoad)
            .onReceive(NotificationCenter.default.publisher(for: .didUploadPost)) { _ in
                Task { await refresh() }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: header
    private var header: some View {
        ZStack {
            Text("FitSpo").font(.largeTitle).fontWeight(.black)
            HStack {
                NavigationLink(destination: ActivityView()) {
                    Image(systemName: "bell")
                        .font(.title2)
                }
                Spacer()
                NavigationLink(destination: MessagesView()) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.title2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }



    // MARK: skeleton grid
    private var skeletonGrid: some View {
        HStack(alignment: .top, spacing: 8) {
            LazyVStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    PostCardSkeleton()
                }
            }
            LazyVStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    PostCardSkeleton()
                }
            }
        }
        .padding(.horizontal, 12)
    }

    // MARK: masonry column
    @ViewBuilder
    private func column(for list: [Post]) -> some View {
        // Compute a stable image height per column to avoid reflow when images load
        let screenW: CGFloat = UIScreen.main.bounds.width
        let colSpacing: CGFloat = 8
        let sidePadding: CGFloat = 24 // .padding(.horizontal, 12)
        let colWidth = (screenW - sidePadding - colSpacing) / 2
        let imageHeight = colWidth * (5.0/4.0) // 4:5 aspect (portrait)

        LazyVStack(spacing: 8) {
            ForEach(list) { post in
                PostCardView(post: post, fixedImageHeight: imageHeight) { toggleLike(post) }
                    .onAppear { maybePrefetch(after: post) }
            }
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: paging trigger
    // ─────────────────────────────────────────────────────────
    private func maybePrefetch(after post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let remaining = posts.count - idx - 1
        guard remaining <= PREFETCH_AHEAD else { return }

        // Only trigger once per index to avoid race conditions
        guard idx != lastPrefetchIndex else { return }
        lastPrefetchIndex = idx
        loadNextPage()
    }

    // MARK: initial fetch
    private func initialLoad() {
        guard posts.isEmpty, !isLoadingPage else { return }
        isLoadingPage = true
        NetworkService.shared.fetchPostsPage(pageSize: FIRST_BATCH, after: nil) { res in
            DispatchQueue.main.async {
                switch res {
                case .success(let tuple):
                    posts = tuple.0
                    // Prefetch images for the initial batch
                    ImagePrefetcher.shared.prefetch(urlStrings: tuple.0.map { $0.imageURL })
                    cursor     = tuple.1
                    reachedEnd = tuple.1 == nil
                    isLoadingPage = false
                    if !reachedEnd { loadAdditionalForFirstPage() }
                    updateSaveStates()
                case .failure(let err):
                    isLoadingPage = false
                    print("Initial load error:", err)
                }
            }
        }
    }

    // MARK: next page
    private func loadNextPage() {
        guard !isLoadingPage, !reachedEnd else { return }
        isLoadingPage = true
        NetworkService.shared.fetchPostsPage(pageSize: PAGE_SIZE, after: cursor) { res in
            DispatchQueue.main.async {
                isLoadingPage = false
                switch res {
                case .success(let tuple):
                    let newOnes = tuple.0.filter { p in !posts.contains(where: { $0.id == p.id }) }
                    posts.append(contentsOf: newOnes)
                    // Prefetch newly appended images
                    ImagePrefetcher.shared.prefetch(urlStrings: newOnes.map { $0.imageURL })
                    cursor     = tuple.1
                    reachedEnd = tuple.1 == nil
                    updateSaveStates()
                case .failure(let err):
                    print("Next page error:", err)
                }
            }
        }
    }

    // Fetch remaining posts for first page after initial batch
    private func loadAdditionalForFirstPage() {
        NetworkService.shared.fetchPostsPage(pageSize: PAGE_SIZE - FIRST_BATCH,
                                             after: cursor) { res in
            DispatchQueue.main.async {
                switch res {
                case .success(let tuple):
                    let newOnes = tuple.0.filter { p in !posts.contains(where: { $0.id == p.id }) }
                    posts.append(contentsOf: newOnes)
                    // Prefetch remaining first-page images
                    ImagePrefetcher.shared.prefetch(urlStrings: newOnes.map { $0.imageURL })
                    cursor     = tuple.1
                    reachedEnd = tuple.1 == nil
                    updateSaveStates()
                case .failure(let err):
                    print("Initial page extend error:", err)
                }
            }
        }
    }

    // MARK: pull‑to‑refresh
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        reachedEnd = false

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            NetworkService.shared.fetchPostsPage(pageSize: PAGE_SIZE, after: nil) { res in
                DispatchQueue.main.async {
                    switch res {
                    case .success(let tuple):
                        withAnimation(.easeIn) { posts = tuple.0 }
                        cursor     = tuple.1
                        reachedEnd = tuple.1 == nil
                        lastPrefetchIndex = -1
                        updateSaveStates()
                    case .failure(let err):
                        print("Refresh error:", err)
                    }
                    cont.resume()
                }
            }
        }
    }

    // MARK: like handling
    private func toggleLike(_ post: Post) {
        print("HomeView: Toggle like for post: \(post.id), current liked: \(post.isLiked), likes: \(post.likes)")
        NetworkService.shared.toggleLike(post: post) { result in
            DispatchQueue.main.async {
                if case .success(let updated) = result,
                   let idx = posts.firstIndex(where: { $0.id == updated.id }) {
                    print("HomeView: Like toggle success - updating post at index \(idx) with likes: \(updated.likes), liked: \(updated.isLiked)")
                    posts[idx] = updated
                } else if case .failure(let error) = result {
                    print("HomeView: Like toggle failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: save state handling
    private func updateSaveStates() {
        let postIds = posts.map { $0.id }
        NetworkService.shared.checkSaveStates(for: postIds) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let saveStates):
                    for (index, post) in posts.enumerated() {
                        if let isSaved = saveStates[post.id] {
                            var updatedPost = post
                            updatedPost.isSaved = isSaved
                            posts[index] = updatedPost
                        }
                    }
                case .failure(let error):
                    print("Error updating save states: \(error.localizedDescription)")
                }
            }
        }
    }


}

#if DEBUG
struct HomeView_Previews: PreviewProvider {
    static var previews: some View { HomeView() }
}
#endif
