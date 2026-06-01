import GatteyPhotosCore
import SwiftUI

private enum SettingsField: Hashable {
    case displayName
}

struct SettingsPopover: View {
    @EnvironmentObject private var store: GalleryStore
    @EnvironmentObject private var session: AppSession
    @FocusState private var focusedField: SettingsField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Your name") {
                TextField("", text: $store.settings.displayName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .displayName)
            }

            FramesSettingsSection()

            GroupBox("Server") {
                VStack(alignment: .leading, spacing: 8) {
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
            Task { await store.updateConnectionStatus() }
        }
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
