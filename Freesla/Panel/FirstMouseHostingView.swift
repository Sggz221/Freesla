//
//  FirstMouseHostingView.swift
//  Freesla
//

import SwiftUI

/// `NSHostingView` es el puente que mete una vista SwiftUI dentro de una ventana AppKit.
/// Esta subclase acepta el "primer clic": como el panel nunca es la ventana activa,
/// sin esto el primer clic en un botón solo serviría para "activar" la ventana y se perdería.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
