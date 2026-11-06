import SwiftUI

@main
struct CompositorPadApp: App {
    /// The one place the iPad app names its platform. Everything below receives it as
    /// `PlatformServices`, so shared code never asks which operating system it is on.
    private let platform = PadPlatform()

    var body: some Scene {
        WindowGroup {
            EditorView(platform: platform)
                .preferredColorScheme(.dark)
        }
    }
}
