import SwiftUI
import UIKit

@main
struct HauntApp: App {
    init() {
        Analytics.track("app_open")
        UIPageControl.appearance().currentPageIndicatorTintColor = .white
        UIPageControl.appearance().pageIndicatorTintColor = UIColor.white.withAlphaComponent(0.25)
    }
    var body: some Scene {
        WindowGroup { RootView() }
    }
}
