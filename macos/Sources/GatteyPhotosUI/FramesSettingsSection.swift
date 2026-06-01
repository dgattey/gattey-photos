import GatteyPhotosCore
import SwiftUI

/// Family frames registered on the server (any member can add/remove). Tokens stay on the server.
struct FramesSettingsSection: View {
    @EnvironmentObject private var store: GalleryStore
    @State private var setupPasteText = ""
    @State private var frameDisplayName = ""
    @State private var showBloomin8Help = false
    @State private var registerError: String?
    @State private var isRegistering = false

    var body: some View {
        GroupBox("Frames") {
            VStack(alignment: .leading, spacing: 10) {
                ConnectionPill(
                    title: "Frames",
                    subtitle: store.framesStatusLine,
                    status: store.deviceLinkStatus
                )

                if store.registeredFrames.isEmpty {
                    Text("No frames registered yet. Any family member can add one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.registeredFrames) { frame in
                        frameRow(frame)
                    }
                }

                Text(Bloomin8SetupClipboard.pasteInstructions)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Button("Copy setup instructions") {
                        Bloomin8SetupClipboard.copyPasteInstructions()
                    }
                    Button {
                        showBloomin8Help = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("How to get the setup block from Bloomin8")
                    .popover(isPresented: $showBloomin8Help, arrowEdge: .top) {
                        Bloomin8TokenHelpPopover()
                    }
                    Spacer(minLength: 0)
                }

                TextField("Frame name (optional)", text: $frameDisplayName)
                    .textFieldStyle(.roundedBorder)

                pasteField

                if let registerError {
                    Text(registerError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Button {
                    Task { await registerFrame() }
                } label: {
                    if isRegistering {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Register frame")
                    }
                }
                .disabled(isRegistering || setupPasteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            Task { await store.reloadRegisteredFrames() }
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

    #if os(macOS)
    private var pasteField: some View {
        TextEditor(text: $setupPasteText)
            .font(.system(.caption, design: .monospaced))
            .frame(height: 56)
            .scrollDisabled(true)
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
    #else
    private var pasteField: some View {
        TextField(
            "Paste Bloomin8 setup block",
            text: $setupPasteText,
            axis: .vertical
        )
        .textFieldStyle(.roundedBorder)
        .lineLimit(3...6)
    }
    #endif

    private func registerFrame() async {
        registerError = nil
        isRegistering = true
        defer { isRegistering = false }
        let paste = setupPasteText
        let name = frameDisplayName
        do {
            try await store.registerFrame(setupText: paste, displayName: name.isEmpty ? nil : name)
            setupPasteText = ""
            frameDisplayName = ""
        } catch {
            registerError = error.localizedDescription
        }
    }

    private func removeFrame(_ id: String) async {
        do {
            try await store.unregisterFrame(id: id)
        } catch {
            registerError = error.localizedDescription
        }
    }
}
