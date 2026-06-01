import GatteyPhotosCore
import SwiftUI

/// Family frames registered on the server (any member can add/remove). Tokens stay on the server.
struct FramesSettingsSection: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var setupPasteText = ""
    @State private var showBloomin8Help = false
    @State private var registerError: String?
    @State private var isRegistering = false
    @FocusState private var isPasteFieldFocused: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                ConnectionPill(
                    title: "Frames",
                    status: store.deviceLinkStatus
                )

                if !store.registeredFrames.isEmpty {
                    ForEach(store.registeredFrames) { frame in
                        frameRow(frame)
                    }
                }

                pasteField

                if isRegistering {
                    ProgressView()
                        .controlSize(.small)
                }

                if let registerError {
                    Text(registerError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text("Frames")
                Button {
                    showBloomin8Help = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.borderless)
                .help("How to register a Bloomin8 frame")
                .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                    Bloomin8TokenHelpPopover()
                }
            }
        }
        .onAppear {
            Task { await store.reloadRegisteredFrames() }
        }
        .onChange(of: isPasteFieldFocused) { wasFocused, isFocused in
            if wasFocused, !isFocused {
                Task { await registerOnBlurIfNeeded() }
            }
        }
    }

    @ViewBuilder
    private func frameRow(_ frame: RegisteredDevicePublic) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(frame.displayName)
                    .font(.subheadline.weight(.medium))
                Text("Added by \(frame.registeredBy)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let err = frame.lastPushError, !err.isEmpty {
                    Text(err)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if let at = frame.lastPushAt {
                    Text("Last push \(at)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                Task { await removeFrame(frame.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove frame from server")
        }
    }

    private var pasteField: some View {
        TextField(
            "Paste Bloomin8 setup block or API key",
            text: $setupPasteText,
            axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
        #if os(macOS)
        .font(.system(.caption, design: .monospaced))
        #endif
        .focused($isPasteFieldFocused)
        .disabled(isRegistering)
    }

    private func registerOnBlurIfNeeded() async {
        registerError = nil
        let paste = setupPasteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !paste.isEmpty else { return }

        guard Bloomin8TokenParser.parseToken(from: paste) != nil else {
            registerError = "Could not find a Bloomin8 API token. Paste the setup block or token only."
            return
        }

        isRegistering = true
        defer { isRegistering = false }
        do {
            try await store.registerFrame(setupText: paste)
            setupPasteText = ""
        } catch {
            registerError = error.localizedDescription
        }
    }

    private func removeFrame(_ id: String) async {
        do {
            try await store.unregisterFrame(id: id)
            registerError = nil
        } catch {
            registerError = error.localizedDescription
        }
    }
}
