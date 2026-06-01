import GatteyPhotosCore
import SwiftUI

private enum SettingsField: Hashable {
    case displayName
    case bloomin8Token
}

#if os(macOS)
private let bloomin8TokenFieldHeight: CGFloat = 56
#endif

struct SettingsPopover: View {
    @EnvironmentObject private var store: GalleryStore
    @EnvironmentObject private var session: AppSession
    @FocusState private var focusedField: SettingsField?
    @State private var showBloomin8Help = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Your name") {
                TextField("", text: $store.settings.displayName)
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .displayName)
            }

            #if os(macOS)
            GroupBox("Device") {
                VStack(alignment: .leading, spacing: 10) {
                    ConnectionPill(
                        title: devicePillTitle,
                        subtitle: devicePillSubtitle,
                        status: store.deviceLinkStatus
                    )
                    HStack(spacing: 6) {
                        Text("API token")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button {
                            showBloomin8Help = true
                        } label: {
                            Image(systemName: "questionmark.circle")
                        }
                        .buttonStyle(.borderless)
                        .help("How to get your API token")
                        .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                            Bloomin8TokenHelpPopover()
                        }
                        Spacer(minLength: 0)
                    }
                    bloomin8TokenField
                        .focused($focusedField, equals: .bloomin8Token)
                }
            }
            #else
            GroupBox("Device") {
                VStack(alignment: .leading, spacing: 10) {
                    ConnectionPill(
                        title: devicePillTitle,
                        subtitle: iosDevicePillSubtitle,
                        status: store.deviceLinkStatus
                    )
                }
            }
            #endif

            GroupBox("Server") {
                ConnectionPill(
                    title: "Server",
                    subtitle: store.settings.serverBaseURL,
                    status: store.serverLinkStatus
                )
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
            #if os(macOS)
            store.applyBloomin8TokenFromPaste()
            Task { await store.refreshBloomin8SettingsStatus() }
            #endif
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

    #if os(macOS)
    private var bloomin8TokenField: some View {
        TextEditor(text: $store.settings.bloomin8ApiToken)
            .font(.system(.caption, design: .monospaced))
            .frame(height: bloomin8TokenFieldHeight)
            .scrollDisabled(true)
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
    #endif

    private var devicePillTitle: String {
        if let label = store.bloomin8DeviceLabel, !label.isEmpty {
            return label
        }
        if let name = deviceNameSegment(in: store.bloomin8SettingsStatus) {
            return name
        }
        return "Bloomin8"
    }

    private var devicePillSubtitle: String? {
        guard let status = store.bloomin8SettingsStatus, !status.isEmpty else {
            return nil
        }
        if Self.isFullLineDeviceStatus(status) {
            return status
        }
        if let detail = deviceDetailSegment(in: status, excludingName: devicePillTitle) {
            return detail.isEmpty ? nil : detail
        }
        if status == devicePillTitle {
            return nil
        }
        return status
    }

    #if !os(macOS)
    private var iosDevicePillSubtitle: String? {
        if let detail = devicePillSubtitle, !detail.isEmpty {
            return detail
        }
        return "Configure the e-ink frame on your Mac"
    }
    #endif

    private func deviceNameSegment(in status: String?) -> String? {
        guard let status, !status.isEmpty, !Self.isFullLineDeviceStatus(status) else { return nil }
        guard status.contains(" · ") else { return nil }
        let name = status.components(separatedBy: " · ").first?.trimmingCharacters(in: .whitespaces)
        guard let name, !name.isEmpty else { return nil }
        return name
    }

    private func deviceDetailSegment(in status: String, excludingName name: String) -> String? {
        guard status.contains(" · ") else { return nil }
        var parts = status.components(separatedBy: " · ")
        if parts.first?.trimmingCharacters(in: .whitespaces) == name {
            parts.removeFirst()
            let detail = parts.joined(separator: " · ").trimmingCharacters(in: .whitespaces)
            return detail.isEmpty ? nil : detail
        }
        return nil
    }

    private static func isFullLineDeviceStatus(_ status: String) -> Bool {
        status == "Paste Bloomin8 token from the device app"
            || status == "Token OK"
            || status.hasPrefix("Token saved —")
    }
}
