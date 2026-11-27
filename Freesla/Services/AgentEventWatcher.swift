//
//  AgentEventWatcher.swift
//  Freesla
//
//  Estado del agente (Claude Code) a partir de sus hooks. En ~/.claude/settings.json hay
//  hooks UserPromptSubmit / Stop / Notification / PostToolUse que escriben el JSON del evento como un
//  fichero en ~/Library/Application Support/Freesla/agent-events/. Aquí vigilamos esa
//  carpeta, leemos cada fichero y lo borramos.
//

import Foundation

nonisolated enum AgentActivity: Equatable, Sendable {
    case idle
    case working
    case needsInput
}

@Observable
final class AgentEventWatcher {
    private(set) var activity: AgentActivity = .idle
    private(set) var project: String?
    private(set) var lastFinishedAt: Date?
    /// true durante unos segundos tras terminar una tarea (para el aviso en la isla).
    private(set) var justFinished = false

    /// Se llama con el nombre del evento ("Stop", ...). El AppDelegate lo usa para refrescar el uso.
    @ObservationIgnored var onEvent: ((String) -> Void)?

    @ObservationIgnored private var sessions: [String: AgentActivity] = [:]
    @ObservationIgnored private var source: DispatchSourceFileSystemObject?
    @ObservationIgnored private var flashTask: Task<Void, Never>?
    @ObservationIgnored private var retryScheduled = false

    static let directory = URL.applicationSupportDirectory.appending(path: "Freesla/agent-events", directoryHint: .isDirectory)

    func start() {
        try? FileManager.default.createDirectory(at: Self.directory, withIntermediateDirectories: true)
        drain(discardOlderThan: 120) // eventos de cuando Freesla no estaba abierto: solo los recientes

        // Un DispatchSource sobre la carpeta avisa cuando se crea o borra un fichero dentro
        // (equivalente a FileSystemWatcher de .NET).
        let descriptor = open(Self.directory.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.drain() }
        }
        source.setCancelHandler { close(descriptor) }
        source.resume()
        self.source = source
    }

    private func drain(discardOlderThan maxAge: TimeInterval? = nil) {
        let fileManager = FileManager.default
        guard let urls = try? fileManager.contentsOfDirectory(at: Self.directory, includingPropertiesForKeys: [.creationDateKey]) else { return }
        var needsRetry = false

        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) where url.pathExtension == "json" {
            let created = (try? url.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? .distantPast
            let age = Date.now.timeIntervalSince(created)
            if let maxAge, age > maxAge {
                try? fileManager.removeItem(at: url)
                continue
            }
            guard let data = try? Data(contentsOf: url),
                  let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                // El hook crea el fichero y luego escribe: puede que aún esté vacío. Reintentamos.
                if age < 5 { needsRetry = true } else { try? fileManager.removeItem(at: url) }
                continue
            }
            try? fileManager.removeItem(at: url)
            apply(event)
        }

        if needsRetry && !retryScheduled {
            retryScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                MainActor.assumeIsolated {
                    self?.retryScheduled = false
                    self?.drain()
                }
            }
        }
    }

    private func apply(_ event: [String: Any]) {
        guard let name = event["hook_event_name"] as? String else { return }
        let session = event["session_id"] as? String ?? "?"
        if let cwd = event["cwd"] as? String { project = (cwd as NSString).lastPathComponent }

        switch name {
        case "UserPromptSubmit":
            sessions[session] = .working
        case "Stop":
            sessions[session] = .idle
            lastFinishedAt = .now
            flashFinished()
        case "Notification":
            // Solo cuenta si estaba trabajando (pedir permiso para una herramienta).
            // El aviso de "esperando tu respuesta" que llega tras un rato inactivo se ignora.
            if sessions[session] == .working { sessions[session] = .needsInput }
        case "PostToolUse":
            // Una herramienta acaba de ejecutarse: si estábamos esperando tu permiso, ya contestaste
            // y el agente sigue trabajando. Solo salimos de .needsInput (no de .idle) para que un
            // PostToolUse que llegue tarde, tras el Stop, no deje la isla "trabajando" para siempre.
            if sessions[session] == .needsInput { sessions[session] = .working }
        default:
            break
        }

        let states = sessions.values
        activity = states.contains(.needsInput) ? .needsInput : states.contains(.working) ? .working : .idle
        onEvent?(name)
    }

    private func flashFinished() {
        flashTask?.cancel()
        justFinished = true
        flashTask = Task {
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            justFinished = false
        }
    }
}
