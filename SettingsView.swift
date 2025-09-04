import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notifications_enabled") private var notificationsEnabled = true
    @AppStorage("autoplay_videos") private var autoplayVideos = true
    @AppStorage("private_account") private var privateAccount = false

    var body: some View {
        Form {
            Section(header: Text("Account")) {
                Toggle("Private account", isOn: $privateAccount)
                NavigationLink("Edit profile") { EditProfileView() }
                Button("Change password") { /* present change flow */ }
            }

            Section(header: Text("Content")) {
                Toggle("Autoplay videos", isOn: $autoplayVideos)
                Toggle("Notifications", isOn: $notificationsEnabled)
            }

            Section(header: Text("Support")) {
                Link("Help Center", destination: URL(string: "https://fitspo.app/help")!)
                Link("Terms of Service", destination: URL(string: "https://fitspo.app/terms")!)
                Link("Privacy Policy", destination: URL(string: "https://fitspo.app/privacy")!)
            }

            Section {
                Button(role: .destructive) { try? Auth.auth().signOut(); dismiss() } label: {
                    Text("Log Out")
                }
            }
        }
        .navigationTitle("Settings")
    }
} 
