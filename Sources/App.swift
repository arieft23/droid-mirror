import SwiftUI
import AppKit

@main
public struct DroidMirrorApp: App {
    public init() {
        // Set application activation policy
        NSApplication.shared.setActivationPolicy(.regular)
    }

    public var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 560)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Kontrol") {
                Button("Pindai Ulang Perangkat") {
                    ADBService.shared.refreshDevices()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Restart ADB Server") {
                    Task {
                        await ADBService.shared.restartServer()
                    }
                }
            }
        }
    }
}
