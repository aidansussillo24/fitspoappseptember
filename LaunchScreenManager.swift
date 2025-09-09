//
//  LaunchScreenManager.swift
//  FitSpoo
//
//  Manages launch screen display timing like Instagram
//

import SwiftUI
import Foundation

class LaunchScreenManager: ObservableObject {
    @Published var shouldShowLaunchScreen = false
    
    private let appSessionKey = "appSessionActive"
    private let minimumBackgroundTimeMinutes: Double = 2 // Show launch screen if app was in background for 2+ minutes
    
    init() {
        checkShouldShowLaunchScreen()
        setupAppLifecycleObservers()
    }
    
    private func checkShouldShowLaunchScreen() {
        let wasAppSessionActive = UserDefaults.standard.bool(forKey: appSessionKey)
        
        // Show launch screen if:
        // 1. First time opening the app (!wasAppSessionActive)
        // 2. App was fully closed and reopened
        if !wasAppSessionActive {
            shouldShowLaunchScreen = true
            print("🚀 Showing launch screen - App was fully closed or first launch")
        } else {
            shouldShowLaunchScreen = false
            print("🚀 Skipping launch screen - App was already running")
        }
        
        // Mark app session as active
        UserDefaults.standard.set(true, forKey: appSessionKey)
    }
    
    private func setupAppLifecycleObservers() {
        // Listen for app going to background
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleAppDidEnterBackground()
        }
        
        // Listen for app becoming active
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleAppDidBecomeActive()
        }
        
        // Listen for app termination
        NotificationCenter.default.addObserver(
            forName: UIApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.handleAppWillTerminate()
        }
    }
    
    private func handleAppDidEnterBackground() {
        print("🚀 App entered background")
        // Store the time when app went to background
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "backgroundTime")
    }
    
    private func handleAppDidBecomeActive() {
        let backgroundTime = UserDefaults.standard.double(forKey: "backgroundTime")
        let currentTime = Date().timeIntervalSince1970
        let timeInBackground = currentTime - backgroundTime
        
        print("🚀 App became active - Background time: \(timeInBackground / 60) minutes")
        
        // If app was in background for more than minimum time, show launch screen next time
        if timeInBackground >= (minimumBackgroundTimeMinutes * 60) {
            UserDefaults.standard.set(false, forKey: appSessionKey)
            print("🚀 App was in background long enough - will show launch screen on next launch")
        }
    }
    
    private func handleAppWillTerminate() {
        print("🚀 App will terminate - clearing session")
        // Clear session when app is fully closed
        UserDefaults.standard.set(false, forKey: appSessionKey)
    }
    
    func dismissLaunchScreen() {
        withAnimation(.easeOut(duration: 0.5)) {
            shouldShowLaunchScreen = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - App State Manager
class AppStateManager: ObservableObject {
    @Published var isLaunchScreenActive = false
    
    private let launchScreenManager = LaunchScreenManager()
    
    init() {
        // Check if we should show launch screen
        isLaunchScreenActive = launchScreenManager.shouldShowLaunchScreen
    }
}
