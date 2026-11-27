//
//  NowPlayingService.swift
//  Freesla
//
//  Lee lo que se está reproduciendo (TIDAL o cualquier app que publique "Now Playing")
//  y permite controlarlo. Desde macOS 15.4 Apple solo deja usar MediaRemote a procesos
//  con un entitlement especial; mediaremote-adapter lo esquiva ejecutándose dentro de
//  /usr/bin/perl, que sí lo tiene. Lanzamos `perl adapter.pl framework stream` y leemos
//  una línea JSON por cada cambio.
//

import AppKit

nonisolated struct NowPlayingInfo: Equatable {
    var title: String
    var artist: String?
    var album: String?
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsed: TimeInterval?
    /// Momento en el que `elapsed` era cierto (para calcular el progreso sin preguntar cada segundo).
    var timestamp: Date?
    var playbackRate: Double
    var bundleIdentifier: String
    var artwork: NSImage?

    /// Posición estimada de la canción en `date`.
    func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        var value = elapsed
        if isPlaying, let timestamp {
            value += date.timeIntervalSince(timestamp) * playbackRate
        }
        if let duration { value = min(value, duration) }
        return max(0, value)
    }

    /// Nombre de la app que reproduce ("TIDAL", "Música"...).
    var playerName: String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleIdentifier
    }
}

/// `@Observable`: cuando cambia una propiedad, SwiftUI vuelve a pintar las vistas que la leen
/// (similar a INotifyPropertyChanged, pero sin escribir los eventos a mano).
@Observable
final class NowPlayingService {
    private(set) var info: NowPlayingInfo?
    /// false si el adaptador no se pudo preparar o lanzar.
    private(set) var isAvailable = true

    // `@ObservationIgnored`: estado interno que no debe provocar repintados.
    @ObservationIgnored private var process: Process?
    @ObservationIgnored private var frameworkURL: URL?
    @ObservationIgnored private var state: [String: Any] = [:]
    @ObservationIgnored private var artwork: NSImage?
    @ObservationIgnored private var restartDelay: TimeInterval = 1
    @ObservationIgnored private var stopped = false

    private static let perl = URL(fileURLWithPath: "/usr/bin/perl")
    private var scriptURL: URL? { Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl") }

    // MARK: - Ciclo de vida

    func start() {
        stopped = false
        guard let script = scriptURL, let framework = Self.installFramework() else {
            isAvailable = false
            return
        }
        frameworkURL = framework
        Self.killOrphan()
        launch(script: script, framework: framework)
    }

    func stop() {
        stopped = true
        process?.terminate()
        process = nil
        try? FileManager.default.removeItem(at: Self.pidFile)
    }

    /// PID del adaptador en marcha. Si Freesla se cae, el proceso perl seguiría vivo;
    /// al volver a arrancar lo buscamos aquí y lo cerramos.
    private static let pidFile = URL.applicationSupportDirectory.appending(path: "Freesla/adapter.pid")

    private static func killOrphan() {
        guard let text = try? String(contentsOf: pidFile, encoding: .utf8),
              let pid = pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
        // Solo si ese PID sigue siendo nuestro adaptador (los PID se reutilizan).
        let ps = Process()
        ps.executableURL = URL(fileURLWithPath: "/bin/ps")
        ps.arguments = ["-o", "command=", "-p", String(pid)]
        let pipe = Pipe()
        ps.standardOutput = pipe
        guard (try? ps.run()) != nil else { return }
        let command = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        ps.waitUntilExit()
        if command.contains("mediaremote-adapter.pl") { kill(pid, SIGTERM) }
        try? FileManager.default.removeItem(at: pidFile)
    }

    // MARK: - Controles (IDs de comando de MediaRemote: 2 = play/pausa, 4 = siguiente)

    func togglePlayPause() {
        info?.isPlaying.toggle() // respuesta inmediata en la UI; el adaptador confirmará después
        if let current = info { info?.elapsed = current.elapsed(at: .now); info?.timestamp = .now }
        run(["send", "2"])
    }

    func nextTrack() { run(["send", "4"]) }

    /// Reinicia la canción actual (vuelve al segundo 0).
    func restartTrack() {
        info?.elapsed = 0
        info?.timestamp = .now
        // La posición va en microsegundos. OJO: "0" lo ignora el reproductor (TIDAL no se mueve),
        // así que pedimos 1 µs, que a efectos prácticos es el principio de la canción.
        run(["seek", "1"])
    }

    // MARK: - Proceso del adaptador

    private func launch(script: URL, framework: URL) {
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [
            script.path, framework.path, "stream", "--micros", "--debounce=50",
            // TIDAL publica a veces metadatos mezclados de dos canciones; el adaptador lo corrige con esto.
            "--experimental-peculiar-debounce:com.tidal.desktop=1000",
        ]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        // La salida llega a trozos en un hilo de fondo. Partimos en líneas allí y mandamos
        // cada línea completa al hilo principal (DispatchQueue.main mantiene el orden).
        let splitter = LineSplitter()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            for line in splitter.append(data) {
                DispatchQueue.main.async { MainActor.assumeIsolated { self?.handle(line: line) } }
            }
        }
        process.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { self?.processEnded() } }
        }

        do {
            try process.run()
            self.process = process
            try? String(process.processIdentifier).write(to: Self.pidFile, atomically: true, encoding: .utf8)
        } catch {
            isAvailable = false
        }
    }

    /// Si el adaptador muere, lo relanzamos con espera creciente (1 s, 2 s, 4 s... hasta 60 s).
    private func processEnded() {
        process = nil
        guard !stopped, let script = scriptURL, let framework = frameworkURL else { return }
        let delay = restartDelay
        restartDelay = min(restartDelay * 2, 60)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.stopped, self.process == nil else { return }
                self.launch(script: script, framework: framework)
            }
        }
    }

    private func handle(line: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              let payload = object["payload"] as? [String: Any] else { return }
        restartDelay = 1

        // Con `diff = true` solo llegan los campos que cambian (y NSNull = campo eliminado).
        if object["diff"] as? Bool == true {
            for (key, value) in payload {
                if value is NSNull { state.removeValue(forKey: key) } else { state[key] = value }
            }
        } else {
            state = payload
        }
        // Solo decodificamos la carátula cuando llega una nueva (son cientos de KB en base64).
        if object["diff"] as? Bool != true || payload.keys.contains("artworkData") {
            artwork = (state["artworkData"] as? String)
                .flatMap { Data(base64Encoded: $0) }
                .flatMap { NSImage(data: $0) }
        }
        info = Self.makeInfo(from: state, artwork: artwork)
    }

    private static func makeInfo(from state: [String: Any], artwork: NSImage?) -> NowPlayingInfo? {
        guard let title = state["title"] as? String, !title.isEmpty,
              let bundle = state["bundleIdentifier"] as? String else { return nil }
        func seconds(_ key: String) -> TimeInterval? { (state[key] as? NSNumber).map { $0.doubleValue / 1_000_000 } }
        let isPlaying = state["playing"] as? Bool ?? false
        return NowPlayingInfo(
            title: title,
            artist: state["artist"] as? String,
            album: state["album"] as? String,
            isPlaying: isPlaying,
            duration: seconds("durationMicros"),
            elapsed: seconds("elapsedTimeMicros"),
            timestamp: seconds("timestampEpochMicros").map { Date(timeIntervalSince1970: $0) },
            playbackRate: (state["playbackRate"] as? NSNumber)?.doubleValue ?? (isPlaying ? 1 : 0),
            bundleIdentifier: bundle,
            artwork: artwork
        )
    }

    /// Ejecuta un comando puntual del adaptador (send/seek) en un proceso aparte.
    private func run(_ arguments: [String]) {
        guard let script = scriptURL, let framework = frameworkURL else { return }
        let process = Process()
        process.executableURL = Self.perl
        process.arguments = [script.path, framework.path] + arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
    }

    /// El framework viaja comprimido dentro de la app (si no, Xcode lo enlazaría con Freesla).
    /// Lo descomprimimos en ~/Library/Application Support/Freesla la primera vez o si cambia.
    private static func installFramework() -> URL? {
        guard let zip = Bundle.main.url(forResource: "MediaRemoteAdapter.framework", withExtension: "zip") else { return nil }
        let fileManager = FileManager.default
        let support = URL.applicationSupportDirectory.appending(path: "Freesla", directoryHint: .isDirectory)
        let framework = support.appending(path: "MediaRemoteAdapter.framework", directoryHint: .isDirectory)
        let stampURL = support.appending(path: "MediaRemoteAdapter.stamp")

        let attributes = try? fileManager.attributesOfItem(atPath: zip.path)
        let size = (attributes?[.size] as? NSNumber)?.intValue ?? 0
        let modified = (attributes?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let stamp = "\(size)-\(modified)"

        if fileManager.fileExists(atPath: framework.appending(path: "MediaRemoteAdapter").path),
           (try? String(contentsOf: stampURL, encoding: .utf8)) == stamp {
            return framework
        }

        try? fileManager.removeItem(at: framework)
        try? fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        let ditto = Process()
        ditto.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        ditto.arguments = ["-x", "-k", zip.path, support.path]
        do {
            try ditto.run()
            ditto.waitUntilExit()
        } catch {
            return nil
        }
        guard ditto.terminationStatus == 0 else { return nil }
        try? stamp.write(to: stampURL, atomically: true, encoding: .utf8)
        return framework
    }
}

/// Acumula bytes y devuelve las líneas completas. Solo se usa desde el hilo del readabilityHandler,
/// que AppKit llama de uno en uno; por eso `@unchecked Sendable` es seguro aquí.
nonisolated final class LineSplitter: @unchecked Sendable {
    private var buffer = Data()

    func append(_ data: Data) -> [Data] {
        buffer.append(data)
        var lines: [Data] = []
        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<newline]
            if !line.isEmpty { lines.append(Data(line)) }
            buffer.removeSubrange(buffer.startIndex...newline)
        }
        return lines
    }
}
