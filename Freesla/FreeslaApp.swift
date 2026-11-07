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
            // Contenido del menú
            Button("Salir", systemImage: "power") {
                NSApp.terminate(nil)
            }.keyboardShortcut("q") // sender nil (null) porque no importa ahora mismo, atajo para cerrar con cmnd q
        }
    }
}
