import SwiftUI

@main
struct GMGNTraderNativeApp: App {
    @StateObject private var model = TraderViewModel()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        MenuBarExtra {
            MenuBarView {
                openWindow(id: "settings")
            }
            .environmentObject(model)
            .task {
                model.bootstrap()
            }
        } label: {
            Text(model.menuBarTitle)
        }
        .menuBarExtraStyle(.window)

        Window("设置", id: "settings") {
            SettingsWindow()
                .environmentObject(model)
                .frame(width: 420, height: 360)
                .task {
                    model.bootstrap()
                }
        }
        .windowStyle(.titleBar)
    }
}
