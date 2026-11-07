//
//  NotchPanel.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 07/11/2026.
//

import AppKit

final class NotchPanel: NSPanel {
    init() {
        let rect: NSRect
        if let screen = NSScreen.main {
            rect = NotchPanel.calculateRect(for: screen)
        } else {
            rect = NSRect(x: 0, y: 0, width: 200, height: 40)
        }
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.level = .screenSaver // Nivel muy alto (no el máximo): queda por encima de casi todo, incluidos menús desplegables, Spotlight y notificaciones. TODO: comparar con .statusBar
        self.collectionBehavior = [.canJoinAllSpaces, .stationary] // no quiero algo muy invasivo a pantalla completa asi que fullScreenAuxiliary no lo pongo
        self.isOpaque = false // Indica al sistema que la ventana puede tener zonas transparentes (necesario para un fondo .clear). El efecto cristal irá aparte, en SwiftUI
        self.backgroundColor = .red // vamos a depurar asi que para verlo bien red, luego clear o black
        self.hasShadow = false // Sin sombra, que quede integrado
        hidesOnDeactivate = false // Por defecto un panel se oculta cuando su app no está activa; la nuestra casi nunca lo está, así que desactivamos ese comportamiento
        
    }
    
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    
    private static func calculateRect(for screen: NSScreen) -> NSRect {
        
        let frame = screen.frame // Rectángulo de la pantalla en coordenadas globales (NSRect es un struct, así que es una copia). OJO: en AppKit el origen es la esquina inferior izquierda y la Y crece hacia arriba
        
        // Medidas del notch
        let width: CGFloat = 200
        let height: CGFloat = 40
        
        let x = frame.midX - width / 2 // Obtenemos el medio del ancho de la pantalla y le restamos la mitad de lo que mide el notch de ancho para que quede en el centro exacto
        let y = frame.maxY - height // Obtenemos lo que mide la pantalla de alto y le restamos lo que mide de alto el notch para que no se salga de la pantalla
        let rect = NSRect(x: x, y: y, width: width, height: height) // Solo es un valor (posición + tamaño); no dibuja nada. Se aplica al panel en super.init o en setFrame
        return rect
    }
    
    func move(to screen: NSScreen) {
        let rect = NotchPanel.calculateRect(for: screen)
        setFrame(rect, display: true)
    }
}
