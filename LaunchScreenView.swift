//
//  LaunchScreenView.swift
//  FitSpoo
//
//  Instagram-style launch screen with logo and slogan
//

import SwiftUI
import UIKit

// Extension to get app icon from bundle
extension Bundle {
    var icon: UIImage? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return nil
    }
}

struct LaunchScreenView: View {
    @State private var isLogoVisible = false
    @State private var isSloganVisible = false
    @State private var isAnimationComplete = false
    @Binding var isLaunchScreenActive: Bool
    
    var body: some View {
        ZStack {
            // Background gradient similar to Instagram
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.98, blue: 0.98), // Very light gray
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea(.all)
            
            VStack {
                Spacer()
                
                // Center content - Logo and App Name
                VStack(spacing: 24) {
                    // Logo with transparent background handling
                    Group {
                        if UIImage(named: "launch-logo") != nil {
                            // Your custom logo - no clipping to preserve transparency
                            Image("launch-logo")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        } else {
                            // Placeholder until you add your logo
                            ZStack {
                                RoundedRectangle(cornerRadius: 26)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.black,
                                                Color.gray.opacity(0.8)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 120, height: 120)
                                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                
                                // Camera icon representing fashion/photo app
                                Image(systemName: "camera.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    
                    // App name - same font as home page
                    Text("FitSpo")
                        .font(.system(size: 40, weight: .bold, design: .default))
                        .foregroundColor(.black)
                        .kerning(2)
                }
                .scaleEffect(isLogoVisible ? 1.0 : 0.8)
                .opacity(isLogoVisible ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.8), value: isLogoVisible)
                
                Spacer()
                
                // Bottom slogan section
                VStack(spacing: 16) {
                    Text("What are you wearing tonight?")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .opacity(isSloganVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(1.2), value: isSloganVisible)
                    
                    // Animated dots - more elegant
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(Color.gray.opacity(0.4))
                                .frame(width: 6, height: 6)
                                .scaleEffect(isSloganVisible ? 1 : 0.3)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                        .repeatForever(autoreverses: true)
                                        .delay(Double(index) * 0.3 + 1.8),
                                    value: isSloganVisible
                                )
                        }
                    }
                    .opacity(isSloganVisible ? 1 : 0)
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            startAnimationSequence()
        }
    }
    
    private func startAnimationSequence() {
        // Start logo animation immediately
        withAnimation {
            isLogoVisible = true
        }
        
        // Start slogan animation after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
                isSloganVisible = true
            }
        }
        
        // Mark animation as complete and dismiss after total time
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                isAnimationComplete = true
            }
        }
        
        // Dismiss launch screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(.easeOut(duration: 0.5)) {
                isLaunchScreenActive = false
            }
        }
    }
}

#if DEBUG
struct LaunchScreenView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchScreenView(isLaunchScreenActive: .constant(true))
    }
}
#endif
