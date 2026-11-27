//
//  ClaudeUsageService.swift
//  Freesla
//
//  % de uso de la suscripción de Claude (ventana de 5 h y semanal).
//  Usa el mismo endpoint que el comando /usage de Claude Code (no documentado), autenticado
//  con el token OAuth que Claude Code guarda en el Llavero. El token solo se lee en memoria
//  y solo se envía a api.anthropic.com. No lo renovamos nosotros: eso lo hace Claude Code.
//

import Foundation

nonisolated struct UsageWindow: Sendable, Equatable {
    /// Porcentaje usado, de 0 a 100.
    var utilization: Double
    var resetsAt: Date?
}

nonisolated struct UsageError: Error, Sendable {
    let message: String
}

@Observable
final class ClaudeUsageService {
    private(set) var fiveHour: UsageWindow?
    private(set) var sevenDay: UsageWindow?
    private(set) var lastUpdated: Date?
    /// Texto corto si la última consulta falló (se siguen mostrando los últimos datos buenos).
    private(set) var problem: String?

    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var inFlight = false
    @ObservationIgnored private var lastAttempt: Date?

    func start() {
        refresh(force: true)
        let timer = Timer(timeInterval: 180, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Consulta el uso. Sin `force`, como mucho una vez cada 30 s (se llama al terminar cada tarea).
    func refresh(force: Bool = false) {
        guard !inFlight else { return }
        if !force, let lastAttempt, Date.now.timeIntervalSince(lastAttempt) < 30 { return }
        inFlight = true
        lastAttempt = .now
        Task {
            defer { inFlight = false }
            do {
                let (five, seven) = try await Self.fetch()
                fiveHour = five
                sevenDay = seven
                lastUpdated = .now
                problem = nil
            } catch let error as UsageError {
                problem = error.message
            } catch {
                problem = "Sin conexión"
            }
        }
    }

    // `@concurrent`: se ejecuta fuera del hilo principal (leer el Llavero y la red no deben bloquear la UI).
    @concurrent
    private nonisolated static func fetch() async throws -> (UsageWindow?, UsageWindow?) {
        let token = try readToken()
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("Freesla", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200: break
        case 401: throw UsageError(message: "Token caducado: abre Claude Code")
        case 429: throw UsageError(message: "Demasiadas consultas")
        default: throw UsageError(message: "Error \(status)")
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return (window(json?["five_hour"]), window(json?["seven_day"]))
    }

    private nonisolated static func window(_ value: Any?) -> UsageWindow? {
        guard let dict = value as? [String: Any],
              let utilization = (dict["utilization"] as? NSNumber)?.doubleValue else { return nil }
        return UsageWindow(utilization: utilization, resetsAt: (dict["resets_at"] as? String).flatMap(parseDate))
    }

    /// Fechas tipo "2026-11-27T13:40:00.344728+00:00" (microsegundos, que ISO8601DateFormatter no entiende).
    private nonisolated static func parseDate(_ string: String) -> Date? {
        let trimmed = string.replacingOccurrences(of: #"\.\d+"#, with: "", options: .regularExpression)
        return ISO8601DateFormatter().date(from: trimmed)
    }

    /// Lee el token con /usr/bin/security. Claude Code creó la entrada con esa herramienta,
    /// así que el Llavero no nos pide permiso cada vez que recompilamos Freesla.
    private nonisolated static func readToken() throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        process.arguments = ["find-generic-password", "-s", "Claude Code-credentials", "-w"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        guard process.terminationStatus == 0,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let oauth = json["claudeAiOauth"] as? [String: Any],
              let token = oauth["accessToken"] as? String else {
            throw UsageError(message: "Inicia sesión en Claude Code")
        }
        if let expiresAt = (oauth["expiresAt"] as? NSNumber)?.doubleValue,
           Date(timeIntervalSince1970: expiresAt / 1000) < .now {
            throw UsageError(message: "Token caducado: abre Claude Code")
        }
        return token
    }
}
