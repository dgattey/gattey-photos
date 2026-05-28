import Foundation
import GatteyPhotosCore

@main
struct GatteyPhotosSyncHelperMain {
    static func main() async {
        await SyncLoop.runForever()
    }
}
