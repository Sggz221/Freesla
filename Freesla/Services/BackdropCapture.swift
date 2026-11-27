//
//  BackdropCapture.swift
//  Freesla
//
//  Captura lo que hay DETRÁS del panel (el escritorio y las demás ventanas) para que el cristal
//  de la isla pueda refractarlo. SwiftUI no puede leer los píxeles de detrás de una ventana,
//  así que usamos ScreenCaptureKit, excluyendo nuestra propia ventana de la captura.
//
//  Requiere el permiso de "Grabación de pantalla". macOS muestra el indicador de grabación
//  mientras la captura está activa, por eso solo capturamos con la isla expandida.
//

import AppKit
import CoreImage
import ScreenCaptureKit

@Observable
final class BackdropCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    /// Último fotograma de la zona detrás del panel (mismo tamaño que el panel). nil = sin captura.
    private(set) var image: CGImage?
    /// true si falta el permiso de grabación de pantalla.
    private(set) var needsPermission = false

    @ObservationIgnored private var stream: SCStream?
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored nonisolated(unsafe) private let ciContext = CIContext()
    @ObservationIgnored private var generation = 0 // para ignorar arranques que llegan tarde

    /// Empieza a capturar la zona que cubre `panel`. Si ya había una captura, la reinicia.
    func start(panel: NSPanel) {
        stop()
        guard CGPreflightScreenCaptureAccess() else {
            // Pide el permiso (macOS lo muestra una vez). Hasta que lo concedas, la isla usa el cristal normal.
            CGRequestScreenCaptureAccess()
            needsPermission = true
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

        generation += 1
        let myGeneration = generation
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
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
                config.showsCursor = false
                config.queueDepth = 3

                guard let self else { return }
                let stream = SCStream(filter: filter, configuration: config, delegate: self)
                try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
                try await stream.startCapture()
                if Task.isCancelled || myGeneration != self.generation {
                    try? await stream.stopCapture()
                    return
                }
                self.stream = stream
            } catch {
                NSLog("Freesla: no se pudo iniciar la captura del fondo: \(error)")
            }
        }
    }

    func stop() {
        generation += 1
        task?.cancel()
        task = nil
        let old = stream
        stream = nil
        image = nil
        if let old { Task { try? await old.stopCapture() } }
    }

    // MARK: - SCStreamOutput (se llama en un hilo en segundo plano)

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: pixels)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return }
        nonisolated(unsafe) let frame = cg
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated { self?.image = frame }
        }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: Error) {
        NSLog("Freesla: la captura del fondo se detuvo: \(error)")
    }
}
