//
//  AppDelegate.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 02/11/2026.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: NotchPanel! // Propiedad: vive mientras viva el AppDelegate. Swift usa ARC (Automatic Reference Counting): cuando las referencias fuertes llegan a 0, el objeto se libera al instante. Con una variable local, el panel moriría al terminar el método
    

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Salta cuando OTRA app pasa a ser la activa (clic en otra app, ⌘Tab...), no con cada clic del ratón
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) } ) else {return}
            self?.panel.move(to: screen)
        }
        panel = NotchPanel()
        panel.orderFrontRegardless()
    }
}
