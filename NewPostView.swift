//
//  NewPostView.swift
//  FitSpo
//
//  Modern Instagram-style image selector with enhanced UX
//  Features: Smooth animations, better grid layout, improved preview, modern styling

import SwiftUI
import PhotosUI

private struct OffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct NewPostView: View {
    
    // MARK: - PhotoKit
    @State private var assets: [PHAsset] = []
    @State private var isLoadingAssets = true
    private let manager = PHCachingImageManager()
    
    // Enhanced caching for better performance
    @State private var imageCache: [String: UIImage] = [:]
    @State private var preloadingQueue = DispatchQueue(label: "image-preload", qos: .userInitiated)
    
    // Full-library support with incremental paging
    @State private var fetchResult: PHFetchResult<PHAsset>?
    @State private var loadedCount: Int = 0
    private let pageSize: Int = 120
    @State private var totalPhotoCount: Int = 0
    
    // Album selection
    @State private var albums: [PHAssetCollection] = []
    @State private var selectedAlbum: PHAssetCollection?
    @State private var showAlbumPicker = false
    
    // MARK: - Selection
    @State private var selected: PHAsset?
    @State private var preview: UIImage?
    @State private var collapsed = false
    @State private var showCropper = false
    @State private var showCaption = false
    
    // MARK: - UI States
    @State private var showPermissionAlert = false
    @State private var permissionDenied = false
    
    // MARK: - Location
    @StateObject private var locationManager = LocationManager.shared
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Preview Section
                    previewSection
                    
                    // MARK: - Library Header
                    libraryHeader
                    
                    // MARK: - Photo Grid
                    photoGrid
                }
            }
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.primary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") {
                        showCropper = true
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(preview != nil ? .blue : .secondary)
                    .disabled(preview == nil)
                }
            }
            .sheet(isPresented: $showCropper) {
                if let img = preview {
                    ModernImageCropperView(image: img) { croppedImage in
                        preview = croppedImage
                        showCropper = false
                        showCaption = true
                    }
                }
            }
            .background(
                NavigationLink(isActive: $showCaption) {
                    if let img = preview {
                        PostCaptionView(image: img) {
                            dismiss()
                        }
                    }
                } label: { EmptyView() }.hidden()
            )
            .alert("Photo Library Access", isPresented: $showPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Please allow access to your photo library to select photos for your post.")
            }
            .task(loadAssets)
            .coordinateSpace(name: "scroll")
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        VStack(spacing: 0) {
            if let img = preview {
                // Fixed 4:5 container with full-bleed blurred background and centered image
                let containerHeight: CGFloat = collapsed ? 0 : 400
                GeometryReader { geometry in
                    let width = geometry.size.width
                    
                    ZStack {
                        // Background blur
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: width, height: containerHeight)
                            .clipped()
                            .blur(radius: 18)
                            .opacity(0.55)
                        
                        // Foreground image
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: containerHeight)
                    }
                    .frame(width: width, height: containerHeight)
                    .clipped()
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .frame(height: containerHeight)
                .frame(maxWidth: .infinity)
            } else {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("Select a photo to get started")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: collapsed ? 0 : 400)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.easeInOut(duration: 0.3), value: collapsed)
        .animation(.easeInOut(duration: 0.3), value: preview)
        
        // Collapse indicator
        .overlay(alignment: .top) {
            if collapsed && preview != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        collapsed = false
                    }
                }) {
                    VStack(spacing: 2) {
                        Image(systemName: "chevron.compact.up")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        Text("Tap to expand")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }
    
    // MARK: - Library Header
    private var libraryHeader: some View {
        HStack {
            Button(action: {
                showAlbumPicker = true
            }) {
                HStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedAlbum?.localizedTitle ?? "Photo Library")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        HStack(spacing: 4) {
                            Text("\(totalPhotoCount > 0 ? totalPhotoCount : assets.count) photos")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                            
                            if selected != nil {
                                Text("• Selected")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            if isLoadingAssets {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(height: collapsed ? 0 : nil)
        .clipped()
        .opacity(collapsed ? 0 : 1)
        .animation(.easeInOut(duration: 0.3), value: collapsed)
        .sheet(isPresented: $showAlbumPicker) {
            AlbumPickerView(
                albums: albums,
                selectedAlbum: $selectedAlbum,
                onSelect: { album in
                    selectedAlbum = album
                    showAlbumPicker = false
                    Task {
                        await loadAssets(from: album)
                    }
                }
            )
        }
    }
    
    // MARK: - Photo Grid
    private var photoGrid: some View {
        ScrollView {
            GeometryReader { geo in
                Color.clear
                    .preference(key: OffsetKey.self,
                               value: geo.frame(in: .named("scroll")).minY)
            }
            .frame(height: 0)
            
            if assets.isEmpty && !isLoadingAssets {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No photos found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                    
                    if permissionDenied {
                        Button("Open Settings") {
                            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(settingsUrl)
                            }
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                    }
                }
                .padding(.top, 60)
            } else {
                // Fixed grid layout with proper spacing
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(Array(assets.enumerated()), id: \.element.localIdentifier) { index, asset in
                        FixedSizeThumbnail(
                            asset: asset,
                            manager: manager,
                            isSelected: asset == selected,
                            index: index,
                            imageCache: $imageCache
                        ) {
                            print("Tapped thumbnail at index: \(index)")
                            select(asset)
                        }
                        .id("\(asset.localIdentifier)-\(index)")
                        .onAppear {
                            if index >= assets.count - 12 {
                                loadNextPageIfNeeded()
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .background(Color(.systemGray5))
        .onPreferenceChange(OffsetKey.self) { y in
            if y < -30 && !collapsed && preview != nil {
                withAnimation(.easeInOut(duration: 0.3)) {
                    collapsed = true
                }
            } else if y > 0 && collapsed {
                withAnimation(.easeInOut(duration: 0.3)) {
                    collapsed = false
                }
            }
        }
    }
    
    // MARK: - PhotoKit Loading
    private func loadAssets() async {
        isLoadingAssets = true
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            if granted != .authorized && granted != .limited {
                permissionDenied = true
                isLoadingAssets = false
                return
            }
        case .denied, .restricted:
            permissionDenied = true
            isLoadingAssets = false
            return
        case .authorized, .limited:
            break
        @unknown default:
            permissionDenied = true
            isLoadingAssets = false
            return
        }
        
        // Load albums
        await loadAlbums()
        
        // Load assets from selected album or all photos
        await loadAssets(from: selectedAlbum)
    }
    
    private func loadAlbums() async {
        var allAlbums: [PHAssetCollection] = []
        var favoritesAlbum: PHAssetCollection?
        var otherAlbums: [PHAssetCollection] = []
        
        // Smart albums - only local ones
        let smartAlbums = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
        smartAlbums.enumerateObjects { collection, _, _ in
            // Filter out shared albums, empty albums, and unwanted system albums
            let isLocalAlbum = collection.assetCollectionSubtype != .smartAlbumAllHidden &&
                              collection.assetCollectionSubtype != .albumCloudShared &&
                              collection.assetCollectionSubtype != .albumMyPhotoStream
            
            if isLocalAlbum {
                let assets = PHAsset.fetchAssets(in: collection, options: nil)
                if assets.count > 0 {
                    // Prioritize Favorites first
                    if collection.assetCollectionSubtype == .smartAlbumFavorites {
                        favoritesAlbum = collection
                    } else {
                        otherAlbums.append(collection)
                    }
                }
            }
        }
        
        // User albums (regular albums, not shared)
        let userAlbums = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        userAlbums.enumerateObjects { collection, _, _ in
            let assets = PHAsset.fetchAssets(in: collection, options: nil)
            if assets.count > 0 {
                otherAlbums.append(collection)
            }
        }
        
        // Build final list with Favorites first
        if let favorites = favoritesAlbum {
            allAlbums.append(favorites)
        }
        allAlbums.append(contentsOf: otherAlbums)
        
        await MainActor.run {
            albums = allAlbums
        }
    }
    
    private func loadAssets(from album: PHAssetCollection?) async {
        assets = []
        imageCache = [:]
        loadedCount = 0
        
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let fetch: PHFetchResult<PHAsset>
        if let album = album {
            fetch = PHAsset.fetchAssets(in: album, options: options)
        } else {
            fetch = PHAsset.fetchAssets(with: .image, options: options)
        }
        
        fetchResult = fetch
        totalPhotoCount = fetch.count
        
        // Load the first page
        let initialCount = min(pageSize, fetch.count)
        var initialAssets: [PHAsset] = []
        if initialCount > 0 {
            let indexSet = IndexSet(integersIn: 0..<initialCount)
            fetch.enumerateObjects(at: indexSet, options: []) { asset, _, _ in
                initialAssets.append(asset)
            }
        }
        loadedCount = initialAssets.count
        
        await MainActor.run {
            assets = initialAssets
            isLoadingAssets = false
            
            if let first = assets.first { select(first) }
            preloadThumbnails()
        }
    }
    
    // MARK: - Image Preloading
    private func preloadThumbnails() {
        guard !assets.isEmpty else { return }
        
        // Preload first 20 thumbnails for smooth scrolling
        let preloadCount = min(20, assets.count)
        let assetsToPreload = Array(assets.prefix(preloadCount))
        
        preloadingQueue.async {
            let scale = UIScreen.main.scale
            let targetSize = CGSize(width: 300 * scale, height: 300 * scale)
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .exact
            
            for asset in assetsToPreload {
                // Skip if already cached
                if imageCache[asset.localIdentifier] != nil { continue }
                
                manager.requestImage(
                    for: asset,
                    targetSize: targetSize,
                    contentMode: .aspectFill,
                    options: options
                ) { img, _ in
                    DispatchQueue.main.async {
                        if let img = img {
                            imageCache[asset.localIdentifier] = img
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Paging
    private func loadNextPageIfNeeded() {
        guard let fetch = fetchResult else { return }
        guard loadedCount < fetch.count else { return }
        
        let nextCount = min(pageSize, fetch.count - loadedCount)
        guard nextCount > 0 else { return }
        
        var newAssets: [PHAsset] = []
        let start = loadedCount
        let end = loadedCount + nextCount
        let indexSet = IndexSet(integersIn: start..<end)
        fetch.enumerateObjects(at: indexSet, options: []) { asset, _, _ in
            newAssets.append(asset)
        }
        loadedCount += nextCount
        
        // Append on main thread
        DispatchQueue.main.async {
            assets.append(contentsOf: newAssets)
            preloadThumbnails()
        }
    }
    
    // MARK: - Selection
    private func select(_ asset: PHAsset) {
        // Haptic feedback for selection
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
        
        // Debug: Print asset info to help track selection
        print("Selected asset: \(asset.localIdentifier)")
        
        selected = asset
        collapsed = false
        
        let size = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        manager.requestImage(
            for: asset,
            targetSize: size,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            DispatchQueue.main.async {
                preview = image
            }
        }
    }
}

// MARK: - Fixed Size Thumbnail
fileprivate struct FixedSizeThumbnail: View {
    let asset: PHAsset
    let manager: PHCachingImageManager
    let isSelected: Bool
    let index: Int
    @Binding var imageCache: [String: UIImage]
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    @State private var isPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            
            ZStack {
                // Background to ensure consistent sizing
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: size, height: size)
                
                // Image or placeholder
                if let img = image {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipped()
                        .position(x: size/2, y: size/2) // Ensure perfect centering
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: size, height: size)
                        .overlay(
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 20))
                                        .foregroundColor(.secondary)
                                }
                            }
                        )
                }
                
                // Selection indicator
                if isSelected {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
                
                // Press state overlay
                if isPressed {
                    Rectangle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: size, height: size)
                }
            }
            .frame(width: size, height: size)
            .cornerRadius(8)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .contentShape(Rectangle()) // Ensures the entire rectangle is tappable
            .onTapGesture {
                // Haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
                
                withAnimation(.easeInOut(duration: 0.2)) {
                    onTap()
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }, perform: {})
        }
        .aspectRatio(1, contentMode: .fit) // Force square aspect ratio
        .onAppear(perform: loadThumbnail)
    }
    
    private func loadThumbnail() {
        guard image == nil else { return }
        
        // Check cache first for instant loading
        if let cachedImage = imageCache[asset.localIdentifier] {
            image = cachedImage
            isLoading = false
            return
        }
        
        isLoading = true
        
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat // Use high quality for clearer thumbnails
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        options.resizeMode = .exact // Ensure exact sizing for better quality
        
        // Calculate proper thumbnail size based on screen density for crisp images
        let scale = UIScreen.main.scale
        let targetSize = CGSize(width: 300 * scale, height: 300 * scale) // Increased size for better quality
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { img, info in
            DispatchQueue.main.async {
                // Only update if this is still the current asset
                if let img = img {
                    image = img
                    // Cache the image for future use
                    imageCache[asset.localIdentifier] = img
                }
                isLoading = false
            }
        }
    }
}

// MARK: - Album Picker View
struct AlbumPickerView: View {
    let albums: [PHAssetCollection]
    @Binding var selectedAlbum: PHAssetCollection?
    let onSelect: (PHAssetCollection?) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // All Photos option
                Button(action: {
                    onSelect(nil)
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 40)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Photo Library")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            
                            let allPhotosCount = PHAsset.fetchAssets(with: .image, options: nil).count
                            Text("\(allPhotosCount) photos")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedAlbum == nil {
                            Image(systemName: "checkmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                // User and Smart Albums
                ForEach(albums, id: \.localIdentifier) { album in
                    Button(action: {
                        onSelect(album)
                    }) {
                        HStack {
                            // Album icon
                            Image(systemName: albumIcon(for: album))
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(album.localizedTitle ?? "Album")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                let assetCount = PHAsset.fetchAssets(in: album, options: nil).count
                                Text("\(assetCount) photos")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if selectedAlbum?.localIdentifier == album.localIdentifier {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .listStyle(PlainListStyle())
            .navigationTitle("Select Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func albumIcon(for collection: PHAssetCollection) -> String {
        switch collection.assetCollectionSubtype {
        case .smartAlbumFavorites:
            return "heart"
        case .smartAlbumRecentlyAdded:
            return "clock"
        case .smartAlbumVideos:
            return "video"
        case .smartAlbumSelfPortraits:
            return "person.crop.square"
        case .smartAlbumScreenshots:
            return "camera.viewfinder"
        case .smartAlbumPanoramas:
            return "pano"
        case .smartAlbumBursts:
            return "square.stack.3d.down.forward"
        case .smartAlbumLivePhotos:
            return "livephoto"
        default:
            return "folder"
        }
    }
}
