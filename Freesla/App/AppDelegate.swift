//
//  AppDelegate.swift
//  Freesla
//
//  Created by Samuel Gómez Gutiérrez on 02/11/2026.
//
//  Raíz de composición: crea los servicios y el panel, y decide cuándo se expande la isla.
//

import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = IslandModel(
        nowPlaying: NowPlayingService(),
        usage: ClaudeUsageService(),
        stats: ClaudeLogStats(),
        agent: AgentEventWatcher(),
        shelf: ShelfStore()
    )

    // Propiedades: viven mientras viva el AppDelegate. Swift usa ARC (Automatic Reference Counting):
    // cuando las referencias fuertes llegan a 0, el objeto se libera al instante.
    private var panel: NotchPanel?
    private var observers: [NSObjectProtocol] = [] // tokens para poder desuscribirse
    private var mouseTimer: Timer?
    private var termSource: DispatchSourceSignal?
    private var collapseDeadline: Date?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = NotchPanel()
        let hostingView = FirstMouseHostingView(rootView: IslandView().environment(model))
        hostingView.sizingOptions = [] // que SwiftUI no intente redimensionar el panel
        panel.contentView = hostingView
        // Un clic sobre la isla contraída la expande (el hover ya no lo hace).
        panel.onLeftMouseDown = { [weak self] in
            guard let self, !model.isExpanded else { return }
            model.expand()
        }
        self.panel = panel
        place(on: NSScreen.main ?? NSScreen.screens.first)
        panel.orderFrontRegardless() // mostrar sin activar la app ni robar el foco

        model.agent.onEvent = { [weak self] event in
            guard let self, event == "Stop" else { return }
            model.usage.refresh()
            model.stats.refresh()
        }
        model.nowPlaying.start()
        model.usage.start()
        model.stats.start()
        model.agent.start()

        // Salta cuando OTRA app pasa a ser la activa (clic en otra app, ⌘Tab...):
        // la isla se va a la pantalla donde está el ratón.
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.place(on: NSScreen.underMouse) }
        })
        // Monitor conectado/desconectado o cambio de resolución.
        observers.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.place(on: NSScreen.underMouse ?? NSScreen.screens.first) }
        })

        // Comprobamos la posición del ratón 30 veces por segundo. Es más fiable que los eventos
        // de hover de SwiftUI en una ventana que nunca está activa, y funciona también mientras
        // arrastras un archivo desde Finder. `.common` hace que siga corriendo durante menús y arrastres.
        let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.trackMouse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        mouseTimer = timer

        // SIGTERM (pkill, botón Stop de Xcode) mataría la app sin pasar por applicationWillTerminate.
        // Lo convertimos en un cierre ordenado para parar también el adaptador de música.
        signal(SIGTERM, SIG_IGN)
        let termSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        termSource.setEventHandler { NSApp.terminate(nil) }
        termSource.resume()
        self.termSource = termSource
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.nowPlaying.stop()
    }

    private func place(on screen: NSScreen?) {
        guard let screen, let panel else { return }
        model.notchSize = screen.notchSize
        model.hasNotch = screen.hasNotch
        panel.move(to: screen)
    }

    /// Rectángulo de la isla en coordenadas de pantalla (Y hacia arriba), centrado arriba del panel.
    private func islandRect(in panelFrame: NSRect) -> NSRect {
        let size = model.currentSize
        let width = size.width + 2 * model.shoulder
        return NSRect(x: panelFrame.midX - width / 2, y: panelFrame.maxY - size.height, width: width, height: size.height)
    }

    private func trackMouse() {
        guard let panel else { return }
        let mouse = NSEvent.mouseLocation
        var rect = islandRect(in: panel.frame)
        rect.size.height += 2 // incluye el borde superior de la pantalla (contains() lo excluye)
        if model.isExpanded {
            rect = rect.insetBy(dx: -8, dy: -8) // pequeño margen para que no se cierre al rozar el borde
        }
        let inside = rect.contains(mouse)

        // Fuera de la isla el panel es "atravesable": los clics llegan a lo que haya debajo.
        if panel.ignoresMouseEvents == inside { panel.ignoresMouseEvents = !inside }

        let now = Date.now
        if inside {
            collapseDeadline = nil
            // La isla ya no se expande con el hover: solo con clic (ver IslandView) o al soltar archivos.
        } else {
            guard model.isExpanded, !model.isDropTargeted else { return }
            if let collapseDeadline {
                if now >= collapseDeadline {
                    model.collapse()
                    self.collapseDeadline = nil
                }
            } else {
                collapseDeadline = now.addingTimeInterval(0.25)
            }
        }
    }
}
