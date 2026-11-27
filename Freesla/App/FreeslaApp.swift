//
//  FreeslaApp.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 01/11/2026.
//

import ServiceManagement
import SwiftUI

@main
struct FreeslaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    
    var body: some Scene {
        
        // "MenuBarIcon" es una imagen "template": macOS usa solo su silueta y la pinta en blanco o negro
        // según el modo claro/oscuro, así que basta una versión del logo.
        MenuBarExtra("Freesla", image: "MenuBarIcon") {
            Button("Actualizar uso de Claude", systemImage: "arrow.clockwise") {
                appDelegate.model.usage.refresh(force: true)
                appDelegate.model.stats.refresh()
            }
            Button("Vaciar estante", systemImage: "trash") {
                appDelegate.model.shelf.clear()
            }
            Toggle("Abrir al iniciar sesión", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    do {
                        if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled // no se pudo: volvemos al estado real
                    }
                }
            Divider()
            // sender nil (null) porque no importa; atajo ⌘Q (solo con el menú abierto: la app es agent)
            Button("Salir", systemImage: "power") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
