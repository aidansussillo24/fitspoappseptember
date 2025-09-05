//
//  PostCaptionView.swift
//  FitSpo
//
//  Create caption, face-tags, and manual outfit items & pins.
//

import SwiftUI
import CoreLocation

struct PostCaptionView: View {

    let image: UIImage
    var onComplete: (() -> Void)? = nil

    // caption & posting
    @State private var caption   = ""
    @State private var isPosting = false
    @State private var errorMsg: String?

    // face-tags
    @State private var tags: [UserTag] = []
    @State private var showTagOverlay  = false

    // outfit items & pins
    @State private var items:  [OutfitItem] = []
    @State private var oTags:  [OutfitTag]  = []

    @State private var showItemForm  = false
    @State private var editIndex: Int? = nil

    @State private var showTagPlacer   = false
    @State private var pendingItemId: String? = nil
    
    // Location
    @State private var selectedLocationName: String? = nil
    @State private var selectedLocationCoordinates: (latitude: Double, longitude: Double)? = nil
    @State private var showLocationSearch = false

    @Environment(\.dismiss) private var dismiss

    // MARK: - Computed Views
    private var imagePreviewSection: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .frame(maxHeight: 400)
                .background(Color.black)
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.top, 8)
    }
    
    private var mainContentCard: some View {
        VStack(spacing: 20) {
            captionSection
            locationSection
            outfitItemsSection
            
            if let err = errorMsg {
                Text(err)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Caption")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                
                Button { showTagOverlay = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.system(size: 14))
                        Text("Tag People")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                }
            }
            
            TextField("Write a caption...", text: $caption, axis: .vertical)
                .font(.system(size: 16))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .lineLimit(4, reservesSpace: false)
            
            if !tags.isEmpty {
                HStack {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)
                    Text("\(tags.count) \(tags.count == 1 ? "person" : "people") tagged")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.blue)
                    Spacer()
                }
            }
        }
    }
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Location")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Show current location if available, otherwise show option to use it
                if let locationName = selectedLocationName {
                    HStack {
                        Image(systemName: "location.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(locationName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                        Button {
                            selectedLocationName = nil
                            selectedLocationCoordinates = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button {
                        if let location = LocationManager.shared.location {
                            selectedLocationName = "Current Location"
                            selectedLocationCoordinates = (
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            )
                        }
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.blue)
                            Text("Use Current Location")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    Button {
                        showLocationSearch = true
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Text("Search for a location")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
        }
    }
    
    private var outfitItemsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center) {
                HStack(spacing: 8) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Outfit Items")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                }
                Spacer()
                
                Button {
                    editIndex = nil
                    showItemForm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text("Add Item")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
            }
            
            if items.isEmpty {
                emptyItemsView
            } else {
                itemsList
            }
        }
    }
    
    private var emptyItemsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "tshirt")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 4) {
                Text("No items added")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.secondary)
                Text("Add clothing items to help others discover your style")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .background(Color(.systemGray6).opacity(0.5))
        .cornerRadius(12)
    }
    
    private var itemsList: some View {
        VStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                HStack(spacing: 12) {
                    Image(systemName: "tshirt.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.label)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        if !item.brand.isEmpty {
                            Text(item.brand)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            editIndex = idx
                            showItemForm = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                                .frame(width: 32, height: 32)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        Button {
                            items.remove(at: idx)
                            oTags.removeAll { $0.itemId == item.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.red)
                                .frame(width: 32, height: 32)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
                
                if idx < items.count - 1 {
                    Divider()
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    imagePreviewSection
                    mainContentCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("New Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Post") { 
                        upload() 
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isPosting ? .secondary : .blue)
                    .disabled(isPosting)
                }
            }
        }

        // face-tag overlay
        .fullScreenCover(isPresented: $showTagOverlay) {
            TagOverlayView(
                baseImage: image,
                existing: tags,
                onDone: { tags = $0; showTagOverlay = false }
            )
        }

        // outfit item form
        .sheet(isPresented: $showItemForm) {
            OutfitItemFormView(
                initial: editIndex.flatMap { items[$0] },
                onSave: { newItem in
                    let id = newItem.id
                    if let i = editIndex {
                        items[i] = newItem
                    } else {
                        items.append(newItem)
                    }
                    pendingItemId = id
                    showItemForm  = false
                    showTagPlacer = true
                },
                onCancel: { showItemForm = false }
            )
        }

        // pin placement overlay
        .fullScreenCover(isPresented: $showTagPlacer) {
            TagPlacementOverlay(
                baseImage: image
            ) { x, y in
                guard let id = pendingItemId else { return }
                oTags.append(OutfitTag(
                    id: UUID().uuidString,
                    itemId: id,
                    xNorm: x, yNorm: y
                ))
                pendingItemId = nil
            }
        }
        
        // location search
        .sheet(isPresented: $showLocationSearch) {
            LocationSearchView { locationResult in
                selectedLocationName = locationResult.name
                selectedLocationCoordinates = (
                    latitude: locationResult.latitude,
                    longitude: locationResult.longitude
                )
            }
        }
    }

    // =========================================================
    // MARK: upload
    // =========================================================
    private func upload() {
        isPosting = true
        errorMsg  = nil

        // Use selected location coordinates if available, otherwise use current location
        let lat: Double?
        let lon: Double?
        
        if let selectedCoords = selectedLocationCoordinates {
            lat = selectedCoords.latitude
            lon = selectedCoords.longitude
        } else {
            let loc = LocationManager.shared.location
            lat = loc?.coordinate.latitude
            lon = loc?.coordinate.longitude
        }

        NetworkService.shared.uploadPost(
            image: image,
            caption: caption,
            latitude: lat,
            longitude: lon,
            tags: tags,
            outfitItems: items,
            outfitTags: oTags
        ) { res in
            isPosting = false
            switch res {
            case .success: dismissToRoot()
            case .failure(let err): errorMsg = err.localizedDescription
            }
        }
    }

    private func dismissToRoot() {
        dismiss()
        onComplete?()
    }
}
