//
//  NSScreen+Notch.swift
//  Freesla
//

import AppKit

/// `extension` añade miembros a un tipo existente (como los extension methods de C#,
/// pero también admite propiedades calculadas y miembros estáticos).
extension NSScreen {
    /// En pantallas con notch, `safeAreaInsets.top` es la altura del notch; en el resto vale 0.
    var hasNotch: Bool { safeAreaInsets.top > 0 }

    /// Tamaño del notch en puntos: el hueco entre las dos zonas usables de la barra de menús.
    /// Sin notch (monitor externo) devolvemos un tamaño de reserva con la altura de la barra de menús.
    var notchSize: CGSize {
        if hasNotch, let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea {
            return CGSize(width: right.minX - left.maxX, height: safeAreaInsets.top)
        }
        let menuBarHeight = frame.maxY - visibleFrame.maxY
        return CGSize(width: 190, height: max(menuBarHeight, 24))
    }

    /// Pantalla que contiene el puntero.
    static var underMouse: NSScreen? {
        let mouse = NSEvent.mouseLocation
        // `contains` excluye el borde superior, así que ampliamos 1 pt hacia arriba.
        return screens.first { $0.frame.insetBy(dx: 0, dy: -1).contains(mouse) }
    }
}
