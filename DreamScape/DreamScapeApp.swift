import SwiftUI
import ComposableArchitecture
import OpenClawCore

@main
struct DreamScapeApp: App {
    init() {
        KeychainHelper.service = "com.openclaw.dreamscape"
    }

    var body: some Scene {
        WindowGroup {
            DreamScapeView(
                store: Store(initialState: DreamScapeFeature.State()) {
                    DreamScapeFeature()
                }
            )
        }
    }
}
