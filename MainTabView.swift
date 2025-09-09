//  Replace file: MainTabView.swift
//  FitSpo
//
//  Five-tab bar with an SF Symbol hanger-plus icon in the center.
//  • Home · Explore · ➀ Post(+) · Map · Profile
//  • Tapping the center icon opens NewPostView full-screen, then snaps
//    back to the previously active tab.
//
//  Works on iOS 17+ (hanger symbol is new). If you target iOS 16,
//  swap “hanger” for another symbol—e.g. “tray.and.arrow.up”.

import SwiftUI
import CoreLocation

extension Notification.Name {
    static let showMapLocation = Notification.Name("showMapLocation")
}

struct MainTabView: View {

    // 0-Home  1-Explore  2-Post  3-Map  4-Profile
    @State private var selected      = 0
    @State private var lastNonPost   = 0
    @State private var showNewPost   = false
    
    // Map focus state
    @State private var mapFocusCoordinate: CLLocationCoordinate2D?
    @State private var mapFocusPost: Post?

    var body: some View {
        TabView(selection: $selected) {

            HomeView()
                .tabItem { Label("Home", systemImage: "house") }
                .tag(0)

            ExploreView()
                .tabItem { Label("Explore", systemImage: "magnifyingglass") }
                .tag(1)

            // Center “Post” tab (no content, just launches picker)
            Color.clear
                .tabItem {
                    // ---------- SF Symbol composite ----------
                    Image(systemName: "hanger")
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.black, .black)
                        .overlay(
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 9))
                                .offset(x: 10, y: 10)
                        )
                        .offset(y: -2)  // optical centering tweak
                }
                .tag(2)

            MapView(focusOn: mapFocusCoordinate, post: mapFocusPost)
                .tabItem { Label("Map", systemImage: "map") }
                .tag(3)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(4)
        }
        // Monochrome look
        .onAppear {
            UITabBar.appearance().tintColor               = .black
            UITabBar.appearance().unselectedItemTintColor = .black
        }
        // Center-icon behaviour
        .onChange(of: selected) { new in
            if new == 2 {
                selected    = lastNonPost   // snap back
                showNewPost = true          // open post flow
            } else {
                lastNonPost = new
            }
        }
        .fullScreenCover(isPresented: $showNewPost) {
            NewPostView()
                .toolbar(.hidden, for: .tabBar)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showMapLocation)) { notification in
            if let userInfo = notification.userInfo,
               let lat = userInfo["latitude"] as? Double,
               let lon = userInfo["longitude"] as? Double {
                let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                let post = userInfo["post"] as? Post
                showMapLocation(coordinate: coordinate, post: post)
            }
        }
    }
    
    // MARK: - Map Navigation
    private func showMapLocation(coordinate: CLLocationCoordinate2D, post: Post?) {
        print("🗺️ Switching to map tab with coordinate: \(coordinate.latitude), \(coordinate.longitude)")
        
        // Clear previous focus and set new focus
        mapFocusCoordinate = nil
        mapFocusPost = nil
        
        // Set new focus after a brief delay to ensure view updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            mapFocusCoordinate = coordinate
            mapFocusPost = post
        }
        
        selected = 3 // Switch to map tab
    }
}
