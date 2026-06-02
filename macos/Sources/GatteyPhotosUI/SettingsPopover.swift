import GatteyPhotosCore
import SwiftUI

private enum SettingsField: Hashable {
    case displayName
}

struct SettingsPopover: View {
    @EnvironmentObject private var store: GalleryStore
    @EnvironmentObject private var session: AppSession
    @FocusState private var focusedField: SettingsField?
    @State private var didRefreshConnectionsOnOpen = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Your name")
                    .font(.headline)
                TextField("", text: $store.settings.displayName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .displayName)
            }

            FramesSettingsSection()

            VStack(alignment: .leading, spacing: 8) {
                Text("Server")
                    .font(.headline)
                ConnectionPill(
                    title: "Server",
                    subtitle: store.settings.serverBaseURL,
                    status: store.serverLinkStatus
                )
                if store.settings.debugMode {
                    Text("Run ./scripts/dev.sh in the repo to start the local API.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                session.lock(store: store)
            } label: {
                Text("Log out")
                    .frame(maxWidth: .infinity)
            }
            .galleryDestructiveButtonStyle()
            .galleryFullWidthButtonLayout()
        }
        .padding()
        .fixedSize(horizontal: false, vertical: true)
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
