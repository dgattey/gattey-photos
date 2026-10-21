import GatteyPhotosCore
import SwiftUI

private enum SettingsField: Hashable {
    case displayName
}

/// Grouped settings form shared by the iOS sheet and the macOS toolbar popover.
struct SettingsView: View {
    @Environment(GalleryStore.self) private var store
    @Environment(AppSession.self) private var session
    @FocusState private var focusedField: SettingsField?
    @State private var didRefreshConnectionsOnOpen = false

    var body: some View {
        @Bindable var store = store
        Form {
            Section {
                TextField("Name", text: $store.settings.displayName, prompt: Text("Your name"))
                    .labelsHidden()
                    .textContentType(.name)
                    .focused($focusedField, equals: .displayName)
            } header: {
                Text("Your Name")
            } footer: {
                Text("Shown on photos you add.")
                    .settingsFooterAlignment()
            }

            FramesSettingsSection()

            Section {
                LinkStatusRow(
                    title: "Server",
                    subtitle: store.settings.serverBaseURL,
                    status: store.serverLinkStatus
                )
            } header: {
                Text("Server")
            } footer: {
                if store.settings.debugMode {
                    Text("Run ./scripts/dev.sh in the repo to start the local API.")
                        .settingsFooterAlignment()
                }
            }

            Section {
                Button("Log Out", role: .destructive) {
                    session.lock(store: store)
                }
                #if os(macOS)
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                #endif
            }
        }
        .formStyle(.grouped)
        .onAppear {
            guard !didRefreshConnectionsOnOpen else { return }
            didRefreshConnectionsOnOpen = true
            Task { await store.updateConnectionStatus(showCheckingUI: true) }
        }
        .onChange(of: focusedField) { previous, _ in
            if previous != nil {
                store.saveSettings()
            }
        }
        .onDisappear {
            didRefreshConnectionsOnOpen = false
            store.saveSettings()
        }
    }
}

extension View {
    /// macOS grouped forms trail-align footers (meant for buttons); explanatory text reads as a caption under the group.
    func settingsFooterAlignment() -> some View {
        #if os(macOS)
        frame(maxWidth: .infinity, alignment: .leading)
        #else
        self
        #endif
    }
}

#if os(iOS)
/// Settings presented as a native sheet from the gallery toolbar.
struct SettingsSheet: View {
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            SettingsView()
                .navigationTitle("Settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { isPresented = false }
                    }
                }
        }
        .presentationDragIndicator(.visible)
    }
}
#endif
