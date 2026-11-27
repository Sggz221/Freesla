//
//  BackdropCapture.swift
//  Freesla
//
//  Captura lo que hay DETRÁS del panel (el escritorio y las demás ventanas) para que el cristal
//  de la isla pueda refractarlo. SwiftUI no puede leer los píxeles de detrás de una ventana,
//  así que usamos ScreenCaptureKit, excluyendo nuestra propia ventana de la captura.
//
//  Requiere el permiso de "Grabación de pantalla". Solo capturamos con la isla expandida, con una
//  captura puntual por segundo (no una grabación continua), y se puede apagar desde el menú.
//

import AppKit
import ScreenCaptureKit

@Observable
final class BackdropCapture {
    /// Último fotograma de la zona detrás del panel (mismo tamaño que el panel). nil = sin captura.
    private(set) var image: CGImage?
    /// true si falta el permiso de grabación de pantalla.
    private(set) var needsPermission = false

    /// Interruptor del menú: si está apagado, nunca se captura ni se pide permiso.
    var isEnabled: Bool = UserDefaults.standard.object(forKey: BackdropCapture.enabledKey) as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: Self.enabledKey)
            if isEnabled {
                UserDefaults.standard.removeObject(forKey: BackdropCapture.askedKey) // volverá a pedir el permiso si falta
            } else {
                stop()
            }
        }
    }

    private static let enabledKey = "glassRefraction.enabled"
    fileprivate static let askedKey = "glassRefraction.askedPermission"

    @ObservationIgnored private var task: Task<Void, Never>?

    /// Empieza a capturar la zona que cubre `panel`. Si ya había una captura, la reinicia.
    func start(panel: NSPanel) {
        stop()
        guard isEnabled else { return }
        guard CGPreflightScreenCaptureAccess() else {
            needsPermission = true
            // Pedimos el permiso UNA sola vez; si no, macOS volvería a preguntar en cada clic.
            // Para pedirlo otra vez: apagar y encender "Refracción del cristal" en el menú.
            if !UserDefaults.standard.bool(forKey: Self.askedKey) {
                UserDefaults.standard.set(true, forKey: Self.askedKey)
                CGRequestScreenCaptureAccess()
            }
            return
        }
        needsPermission = false
        guard let screen = panel.screen,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        else { return }

        let windowID = CGWindowID(panel.windowNumber)
        let scale = screen.backingScaleFactor
        // Rectángulo del panel en coordenadas de la pantalla con el origen ARRIBA a la izquierda (el de ScreenCaptureKit).
        let frame = panel.frame, screenFrame = screen.frame
        let rect = CGRect(x: frame.minX - screenFrame.minX, y: screenFrame.maxY - frame.maxY,
                          width: frame.width, height: frame.height)

        // En vez de una grabación continua (que activa el indicador de grabación de macOS todo el rato),
        // hacemos capturas puntuales una vez por segundo mientras la isla está expandida.
        task = Task { [weak self] in
            do {
                let content = try await SCShareableContent.current
                guard let display = content.displays.first(where: { $0.displayID == displayID }) else { return }
                let excluded = content.windows.filter { $0.windowID == windowID }
                let filter = SCContentFilter(display: display, excludingWindows: excluded)
                let config = SCStreamConfiguration()
                config.sourceRect = rect
                config.width = Int(rect.width * scale)
                config.height = Int(rect.height * scale)
                config.showsCursor = false

                while !Task.isCancelled {
                    let frame = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                    guard !Task.isCancelled else { return }
                    self?.image = frame
                    try await Task.sleep(for: .seconds(1))
                }
            } catch is CancellationError {
            } catch {
                NSLog("Freesla: no se pudo capturar el fondo: \(error)")
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        image = nil
    }
}
