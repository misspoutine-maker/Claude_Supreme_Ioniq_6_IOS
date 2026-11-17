import SwiftUI

@main
struct SupremeApp: App {
    @StateObject private var obd = ObdBle()
    @StateObject private var gps = LocationTracker()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(obd)
                .environmentObject(gps)
                .preferredColorScheme(.dark)
        }
    }
}
