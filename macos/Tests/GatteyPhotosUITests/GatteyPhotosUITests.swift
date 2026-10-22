import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import GatteyPhotosCore
@testable import GatteyPhotosUI

@Suite("GatteyPhotosUI Component Views (ViewInspector)")
struct GatteyPhotosUITests {
    @Test("ConnectionPill renders title, status label, optional subtitle, and checking spinner")
    @MainActor
    func connectionPillInspection() throws {
        let connected = ConnectionPill(
            title: "Server",
            subtitle: "https://photos.gattey.com",
            status: .up
        )
        let inspectedConnected = try connected.inspect()
        #expect(try inspectedConnected.find(text: "Server").string() == "Server")
        #expect(
            try inspectedConnected.find(text: "https://photos.gattey.com").string()
                == "https://photos.gattey.com"
        )
        #expect(try inspectedConnected.find(text: "Connected").string() == "Connected")
        #expect(throws: (any Error).self) {
            _ = try inspectedConnected.find(ViewType.ProgressView.self)
        }

        let checking = ConnectionPill(
            title: "All frames",
            status: .checking
        )
        let inspectedChecking = try checking.inspect()
        #expect(try inspectedChecking.find(text: "All frames").string() == "All frames")
        #expect(try inspectedChecking.find(text: "Connecting").string() == "Connecting")
        _ = try inspectedChecking.find(ViewType.ProgressView.self)

        let down = ConnectionPill(title: "Server", status: .down)
        #expect(try down.inspect().find(text: "Disconnected").string() == "Disconnected")
    }

    @Test("ActivityLogListView renders empty state when log store has no entries and rows when populated")
    @MainActor
    func activityLogListViewInspection() throws {
        let emptyStore = ActivityLogStore(entries: [])
        let emptyView = ActivityLogListView().environment(emptyStore)
        let inspectedEmpty = try emptyView.inspect()
        #expect(try inspectedEmpty.find(text: "No activity yet").string() == "No activity yet")
        #expect(
            try inspectedEmpty.find(text: "Sync, uploads, and server events appear here.").string()
                == "Sync, uploads, and server events appear here."
        )

        let populatedStore = ActivityLogStore(
            entries: [
                LogEntry(
                    category: .sync,
                    level: .info,
                    message: "Pulled 12 photos",
                    detail: "200 OK"
                )
            ]
        )
        let populatedView = ActivityLogListView().environment(populatedStore)
        let inspectedPopulated = try populatedView.inspect()
        #expect(try inspectedPopulated.find(text: "Pulled 12 photos").string() == "Pulled 12 photos")
        #expect(try inspectedPopulated.find(text: "200 OK").string() == "200 OK")
    }

    @Test("GallerySelectionBar adapts for single vs multiple selection and respects delete constraints")
    @MainActor
    func gallerySelectionBarInspection() throws {
        let store = GalleryStore()
        let selection = GallerySelectionStore()
        selection.selectedIDs = ["photo-1"]

        var deletedIDs: Set<PhotoID>?
        let singleBar = GallerySelectionBar()
            .environment(store)
            .environment(selection)
            .environment(\.galleryDeleteRequest, { ids in deletedIDs = ids })

        let inspectedSingle = try singleBar.inspect()
        #expect(try inspectedSingle.find(text: "1 photo selected").string() == "1 photo selected")
        _ = try inspectedSingle.find(button: "Show for today")
        let deleteButton = try inspectedSingle.find(button: "Delete")
        #expect(!deleteButton.isDisabled())

        selection.selectedIDs = ["photo-1", "photo-2"]
        let multiBar = GallerySelectionBar()
            .environment(store)
            .environment(selection)
            .environment(\.galleryDeleteRequest, { ids in deletedIDs = ids })

        let inspectedMulti = try multiBar.inspect()
        #expect(try inspectedMulti.find(text: "2 photos selected").string() == "2 photos selected")
        #expect(throws: (any Error).self) {
            _ = try inspectedMulti.find(button: "Show for today")
        }
        try inspectedMulti.find(button: "Delete").tap()
        #expect(deletedIDs == ["photo-1", "photo-2"])
    }

    @Test("DevicePreviewChrome computes aspect-fitting dimensions and DevicePreviewFramed wraps content")
    @MainActor
    func devicePreviewChromeAndFramedInspection() throws {
        let overhead = 2 * DevicePreviewChrome.frameSideOverhead
        #expect(overhead == 84)

        let widthBound = DevicePreviewChrome.screenWidth(
            for: CGSize(width: 284, height: 600),
            screenAspectRatio: 0.75
        )
        #expect(widthBound == 200)

        let heightBound = DevicePreviewChrome.screenWidth(
            for: CGSize(width: 600, height: 284),
            screenAspectRatio: 0.75
        )
        #expect(heightBound == 150)

        let clampedMin = DevicePreviewChrome.screenWidth(
            for: CGSize(width: 90, height: 90),
            screenAspectRatio: 0.75,
            minScreenWidth: 80
        )
        #expect(clampedMin == 80)

        let framed = DevicePreviewFramed(screenWidth: 180, screenAspectRatio: 0.75) {
            Text("E-Ink Preview Content")
        }
        #expect(
            try framed.inspect().find(text: "E-Ink Preview Content").string()
                == "E-Ink Preview Content"
        )
    }

    @Test("PhotoFormatters formats uploader attribution and friendly rotation dates")
    func photoFormattersInspection() throws {
        let photo = PhotoEntry(
            id: "p1",
            filename: "sunset.jpg",
            blobPath: "photos/p1.jpg",
            sizeBytes: 1024,
            updatedAt: "2026-10-15T00:00:00Z",
            deletedAt: nil,
            uploaderId: "u1"
        )
        #expect(PhotoFormatters.addedBy(photo, uploaders: ["u1": "Alice"]) == "Added by Alice")
        #expect(
            PhotoFormatters.addedBy(photo, uploaders: ["u1": "  "])
                == "Added by \(defaultUploaderDisplayName)"
        )
        #expect(
            PhotoFormatters.addedBy(photo, uploaders: ["u1": "Unknown"])
                == "Added by \(defaultUploaderDisplayName)"
        )

        #expect(
            PhotoFormatters.deviceRegisteredAt("not-a-date", registeredBy: "Dylan")
                == "Added by Dylan"
        )
        #expect(
            PhotoFormatters.deviceRegisteredAt("not-a-date", registeredBy: nil)
                == "Date unknown"
        )
    }

    @Test("DeviceOwnerFilter and GalleryStore filter devices and statuses by owner case-insensitively")
    @MainActor
    func deviceOwnerFilteringInspection() throws {
        let bedroom = RegisteredDevicePublic(
            id: "cac2aed6-0d27-46e1-b021-cd837d312776",
            displayName: "Bedroom",
            registeredBy: "Dylan",
            registeredAt: "2026-06-02T03:18:40.054Z"
        )
        let casaLapa = RegisteredDevicePublic(
            id: "bfbe51b6-b476-4ed6-b005-1857fed3a93f",
            displayName: "Casa lapa",
            registeredBy: "Becca",
            registeredAt: "2026-08-30T18:29:56.431Z"
        )
        let allDevices = [bedroom, casaLapa]

        #expect(DeviceOwnerFilter.filterDevices(allDevices, owner: nil) == allDevices)
        #expect(DeviceOwnerFilter.filterDevices(allDevices, owner: "   ") == allDevices)
        #expect(DeviceOwnerFilter.filterDevices(allDevices, owner: "  dylan ") == [bedroom])
        #expect(DeviceOwnerFilter.filterDevices(allDevices, owner: "BECCA") == [casaLapa])

        let bedroomStatus = DeviceLiveStatus(
            id: bedroom.id,
            displayName: bedroom.displayName,
            registeredBy: "Dylan",
            reachable: true,
            width: 1200,
            height: 1600
        )
        let casaStatusWithoutRegistrant = DeviceLiveStatus(
            id: casaLapa.id,
            displayName: casaLapa.displayName,
            registeredBy: nil,
            reachable: true,
            width: 1600,
            height: 1200
        )
        let allStatuses = [bedroomStatus, casaStatusWithoutRegistrant]

        #expect(
            DeviceOwnerFilter.filterStatuses(
                allStatuses,
                owner: "Dylan",
                knownDevices: allDevices
            ) == [bedroomStatus]
        )
        #expect(
            DeviceOwnerFilter.filterStatuses(
                allStatuses,
                owner: "Becca",
                knownDevices: allDevices
            ) == [casaStatusWithoutRegistrant]
        )

        let store = GalleryStore()
        store.settings.displayName = "Dylan"
        store.replaceFetchedRegisteredFrames(allDevices)
        #expect(store.registeredFrames == [bedroom])

        store.settings.displayName = "Becca"
        #expect(store.registeredFrames == [casaLapa])

        store.settings.displayName = ""
        #expect(store.registeredFrames == allDevices)

        store.settings.displayName = "Dylan"
        store.applyDeviceStatusStatuses([bedroomStatus, casaStatusWithoutRegistrant])
        #expect(store.deviceLinkStatus == .up)
        #expect(!store.deviceScreenIsLandscape)

        let offlineBedroom = DeviceLiveStatus(
            id: bedroom.id,
            displayName: bedroom.displayName,
            registeredBy: "Dylan",
            reachable: false
        )
        store.applyDeviceStatusStatuses([offlineBedroom, casaStatusWithoutRegistrant])
        #expect(store.deviceLinkStatus == .down)
        #expect(!store.deviceScreenIsLandscape)
    }

    @Test("FramesSettingsSection renders only the current owner's registered frames")
    @MainActor
    func framesSettingsSectionOwnerFiltering() throws {
        let bedroom = RegisteredDevicePublic(
            id: "cac2aed6-0d27-46e1-b021-cd837d312776",
            displayName: "Bedroom",
            registeredBy: "Dylan",
            registeredAt: "2026-06-02T03:18:40.054Z"
        )
        let casaLapa = RegisteredDevicePublic(
            id: "bfbe51b6-b476-4ed6-b005-1857fed3a93f",
            displayName: "Casa lapa",
            registeredBy: "Becca",
            registeredAt: "2026-08-30T18:29:56.431Z"
        )

        let store = GalleryStore()
        store.settings.displayName = "Dylan"
        store.replaceFetchedRegisteredFrames([bedroom, casaLapa])

        let section = FramesSettingsSection().environment(store)
        let inspected = try section.inspect()
        #expect(try inspected.find(text: "Bedroom").string() == "Bedroom")
        #expect(throws: (any Error).self) {
            _ = try inspected.find(text: "Casa lapa")
        }
    }
}
