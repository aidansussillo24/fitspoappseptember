//
//  PostCardView.swift
//  FitSpo
//
//  Feed card now uses RemoteImage with automatic retry & caching.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct PostCardView: View {
    let post: Post
    /// When non‑nil the main photo is force‑cropped to this height – used by Explore.
    var fixedImageHeight: CGFloat? = nil
    let onLike: () -> Void

    @State private var authorName      = ""
    @State private var authorAvatarURL = ""
    @State private var isLoadingAuthor = true
    @State private var showHeart       = false
    @State private var showShareSheet  = false
    @State private var shareChat: Chat?
    @State private var navigateToChat  = false
    @State private var showReportSheet = false
    @State private var showDeleteConfirm = false
    @State private var isSaved = false

    @Environment(\.openURL) private var openURL

    // MARK: – Initialiser
    init(post: Post,
         fixedImageHeight: CGFloat? = nil,
         onLike: @escaping () -> Void) {
        self.post = post
        self.fixedImageHeight = fixedImageHeight
        self.onLike = onLike
        _isSaved = State(initialValue: post.isSaved)
    }

    // MARK: – Computed properties
    private var timeAgoString: String {
        let now = Date()
        let diff = now.timeIntervalSince(post.timestamp)

        let minute: TimeInterval = 60
        let hour: TimeInterval   = 60 * minute
        let day: TimeInterval    = 24 * hour
        let week: TimeInterval   = 7  * day

        switch diff {
        case ..<minute:
            return "now"
        case ..<hour:
            return "\(Int(diff / minute))m"
        case ..<day:
            return "\(Int(diff / hour))h"
        case ..<week:
            return "\(Int(diff / day))d"
        default:
            return "\(Int(diff / week))w"
        }
    }

    private var forecastURL: URL? {
        guard let lat = post.latitude, let lon = post.longitude else { return nil }
        return URL(string: "https://weather.com/weather/today/l/\(lat),\(lon)")
    }

    // MARK: – Body
    var body: some View {
        VStack(spacing: 0) {

            // ── Header (avatar · name · weather) ──────────────────
            HStack(spacing: 12) {
                NavigationLink(destination: ProfileView(userId: post.userId)) {
                    HStack(spacing: 8) {
                        avatarThumb
                        VStack(alignment: .leading, spacing: 2) {
                            Text(authorName.isEmpty ? "Loading…" : authorName)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)

                            if let temp = post.temp, let icon = post.weatherSymbolName {
                                HStack(spacing: 4) {
                                    Image(systemName: icon)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text("\(Int(temp))°")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                // Three‑dots menu
                Menu {
                    if post.userId == Auth.auth().currentUser?.uid {
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button { showReportSheet = true } label: {
                            Label("Report", systemImage: "flag")
                        }
                        Button { savePost() } label: {
                            Label(isSaved ? "Unsave" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // ── Main image – cropped to uniform height when requested ─
            NavigationLink(destination: PostDetailView(post: post)) {
                RemoteImage(url: post.imageURL, contentMode: .fill)
                    .aspectRatio(4/5, contentMode: .fill)
                    .frame(height: fixedImageHeight)   // nil does nothing; Explore supplies a value
                    .clipped()
                    .highPriorityGesture(
                        TapGesture(count: 2).onEnded { handleDoubleTapLike() }
                    )
                    .overlay(HeartBurstView(trigger: $showHeart))
            }
            .buttonStyle(.plain)

            // ── Footer (like · comment · share · time) ─────────────
            HStack(spacing: 12) {
                // Like
                Button(action: onLike) {
                    HStack(spacing: 4) {
                        Image(systemName: post.isLiked ? "heart.fill" : "heart")
                            .foregroundColor(post.isLiked ? .red : .primary)
                        Text("\(post.likes)")
                    }
                }
                .buttonStyle(.plain)

                // Comment
                NavigationLink(destination: PostDetailView(post: post, initialShowComments: true)) {
                    Image(systemName: "message")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                // Share
                Button { showShareSheet = true } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(timeAgoString)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.white)
        }
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .sheet(isPresented: $showShareSheet) { shareSheet }
        .sheet(isPresented: $showReportSheet) {
            ReportSheetView(postId: post.id, isPresented: $showReportSheet)
        }
        .alert("Delete Post", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { deletePost() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this post? This action cannot be undone.")
        }
        .background { chatNavigationLink }
        .onAppear(perform: fetchAuthor)
        .onAppear { fetchSavedState() }
    }

    // MARK: – Avatar helper
    @ViewBuilder private var avatarThumb: some View {
        if let url = URL(string: authorAvatarURL), !authorAvatarURL.isEmpty {
            RemoteImage(url: url.absoluteString, contentMode: .fill)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .frame(width: 32, height: 32)
                .foregroundColor(.gray)
        }
    }

    // MARK: – Author fetch
    private func fetchAuthor() {
        Firestore.firestore()
            .collection("users")
            .document(post.userId)
            .getDocument { snap, err in
                isLoadingAuthor = false
                guard err == nil, let d = snap?.data() else {
                    authorName = "Unknown"; return
                }
                authorName      = d["displayName"] as? String ?? "Unknown"
                authorAvatarURL = d["avatarURL"]   as? String ?? ""
            }
    }

    private func handleDoubleTapLike() {
        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        showHeart = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showHeart = false }
        if !post.isLiked { onLike() }
    }

    // MARK: – Share functionality
    private var shareSheet: some View {
        ShareToUserView { uid in
            showShareSheet = false
            sharePost(to: uid)
        }
    }

    private func sharePost(to uid: String) {
        guard let me = Auth.auth().currentUser?.uid else { return }
        let pair = [me, uid].sorted()
        NetworkService.shared.createChat(participants: pair) { res in
            switch res {
            case .success(let chat):
                NetworkService.shared.sendPost(chatId: chat.id,
                                               postId: post.id) { _ in }
                DispatchQueue.main.async {
                    shareChat = chat
                    navigateToChat = true
                }
            case .failure(let err):
                print("Chat creation error:", err.localizedDescription)
            }
        }
    }

    private var chatNavigationLink: some View {
        Group {
            if let chat = shareChat {
                NavigationLink(destination: ChatDetailView(chat: chat),
                               isActive: $navigateToChat) { EmptyView() }
                    .hidden()
            }
        }
    }

    // MARK: – Post actions
    private func savePost() {
        let original = isSaved
        isSaved.toggle()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        NetworkService.shared.toggleSavePost(post: post) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let updated):
                    isSaved = updated.isSaved
                case .failure:
                    isSaved = original // revert on error
                }
            }
        }
    }

    private func deletePost() {
        NetworkService.shared.deletePost(id: post.id) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    print("Post deleted successfully")
                    // TODO: Update UI to remove the post
                case .failure(let error):
                    print("Failed to delete post: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: – Lifecycle
    private func fetchSavedState() {
        NetworkService.shared.isPostSaved(postId: post.id) { result in
            if case .success(let saved) = result {
                DispatchQueue.main.async { isSaved = saved }
            }
        }
    }
}

#if DEBUG
struct PostCardView_Previews: PreviewProvider {
    static var previews: some View {
        PostCardView(
            post: Post(
                id:        "1",
                userId:    "alice",
                imageURL:  "https://via.placeholder.com/400x600",
                caption:   "Preview card",
                timestamp: Date(),
                likes:     42,
                isLiked:   false,
                latitude:  nil,
                longitude: nil,
                temp:      22,
                weatherIcon: "01d",
                hashtags:  []
            ),
            fixedImageHeight: 350 // preview with Explore‑style crop
        ) { }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
