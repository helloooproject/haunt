import SwiftUI

@main
struct HauntApp: App {
    init() { Analytics.track("app_open") }
    var body: some Scene {
        WindowGroup { GhostCamView() }
    }
}
