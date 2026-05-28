import GatteyPhotosCore
import SwiftUI

private enum SettingsField: Hashable {
    case deviceIP
    case serverURL
    case syncPassword
}

struct SettingsPopover: View {
    @EnvironmentObject private var store: GalleryStore
    @Binding var isPresented: Bool
    @FocusState private var focusedField: SettingsField?

    var body: some View {
        Form {
            Section("Bloomin8 device") {
                TextField("Device IP address", text: $store.settings.deviceIP)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .deviceIP)
            }
            Section("Family sync server") {
                TextField("Server URL", text: $store.settings.serverBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .serverURL)
                SecureField("Sync password", text: $store.settings.syncPassword)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .syncPassword)
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: focusedField) { previous, _ in
            if previous != nil {
                store.saveSettings()
            }
        }
        .onDisappear {
            store.saveSettings()
        }
    }
}
