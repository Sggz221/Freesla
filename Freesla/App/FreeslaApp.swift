//
//  FreeslaApp.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 01/11/2026.
//

import SwiftUI

@main
struct FreeslaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        
        MenuBarExtra("Freesla", systemImage: "capsule.fill") {
            Button("Actualizar uso de Claude", systemImage: "arrow.clockwise") {
                appDelegate.model.usage.refresh(force: true)
                appDelegate.model.stats.refresh()
            }
            Button("Vaciar estante", systemImage: "trash") {
                appDelegate.model.shelf.clear()
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
