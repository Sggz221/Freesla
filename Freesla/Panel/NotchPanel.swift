//
//  NotchPanel.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 07/11/2026.
//

import AppKit

/// Ventana sin bordes y transparente que flota sobre la barra de menús y contiene la isla.
/// El panel es más grande que la isla (cabe la isla expandida); las zonas transparentes
/// no reciben clics porque `ignoresMouseEvents` se activa/desactiva según dónde está el ratón
/// (ver `AppDelegate.trackMouse`).
final class NotchPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: IslandModel.panelSize),
            styleMask: [.borderless, .nonactivatingPanel], // sin bordes; interactuar con él no activa la app
            backing: .buffered,
            defer: false
        )
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle] // en todos los Spaces, fuera de ⌘`; sin fullScreenAuxiliary a propósito
        isOpaque = false // la ventana puede tener zonas transparentes
        backgroundColor = .clear
        hasShadow = false
        hidesOnDeactivate = false // nuestra app casi nunca está activa; si no, el panel se ocultaría
        isMovable = false
        isFloatingPanel = true
        // OJO: va después de isFloatingPanel, que resetea el nivel a .floating (por debajo de la barra de menús,
        // que se comería los clics sobre el notch).
        level = .statusBar // por encima de la barra de menús, pero por debajo de menús desplegables, Spotlight, etc.
        isReleasedWhenClosed = false // la memoria la gestiona ARC (el AppDelegate guarda una referencia fuerte)
        ignoresMouseEvents = true // empieza "atravesable"; se activa al pasar el ratón por la isla
    }

    /// Se llama en cada clic izquierdo que recibe el panel (antes de repartirlo a SwiftUI).
    var onLeftMouseDown: (() -> Void)?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown { onLeftMouseDown?() }
        super.sendEvent(event)
    }

    // Nunca ser ventana key/main: el teclado sigue en la app que estés usando.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // AppKit intenta que las ventanas no tapen la barra de menús; queremos estar justo ahí.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    /// Coloca el panel centrado horizontalmente y pegado al borde superior de `screen`.
    func move(to screen: NSScreen) {
        let size = IslandModel.panelSize
        let frame = screen.frame // OJO: en AppKit el origen es abajo a la izquierda y la Y crece hacia arriba
        let rect = NSRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height, // "arriba del todo" es maxY
            width: size.width,
            height: size.height
        )
        setFrame(rect, display: true)
    }
}
