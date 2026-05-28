import GatteyPhotosCore
import SwiftUI

struct SettingsPopover: View {
    @EnvironmentObject private var store: GalleryStore
    @Binding var isPresented: Bool

    var body: some View {
        Form {
            Section("Bloomin8 device") {
                TextField("Device IP address", text: $store.settings.deviceIP)
                    .textFieldStyle(.roundedBorder)
                TextField("Gallery name", text: $store.settings.galleryName)
                    .textFieldStyle(.roundedBorder)
            }
            Section("Family sync server") {
                TextField("Server URL", text: $store.settings.serverBaseURL)
                    .textFieldStyle(.roundedBorder)
                SecureField("Sync password", text: $store.settings.syncPassword)
                    .textFieldStyle(.roundedBorder)
            }
            HStack {
                Button("Save") {
                    store.saveSettings()
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                Button("Cancel", role: .cancel) {
                    store.reloadSettings()
                    isPresented = false
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
