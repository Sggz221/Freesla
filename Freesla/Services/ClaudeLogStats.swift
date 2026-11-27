//
//  ClaudeLogStats.swift
//  Freesla
//
//  Tokens por día, por sesión y velocidad de salida (tok/s), calculados a partir de los
//  logs locales de Claude Code (~/.claude/projects/**/*.jsonl). Cada línea es un JSON;
//  las respuestas del modelo traen `message.usage` con los tokens.
//

import Foundation

nonisolated struct DayUsage: Sendable, Identifiable, Equatable {
    let day: Date
    var tokens = 0
    var output = 0
    var id: Date { day }
}

nonisolated struct SessionUsage: Sendable, Equatable {
    var project: String
    var started: Date
    var lastActivity: Date
    var input = 0
    var output = 0
    var cacheCreation = 0
    var cacheRead = 0
    /// tok/s de salida de la última respuesta.
    var lastResponseRate: Double?
    /// tok/s de salida medio de la sesión.
    var averageRate: Double?

    var total: Int { input + output + cacheCreation + cacheRead }
}

nonisolated struct UsageSnapshot: Sendable, Equatable {
    /// Últimos 7 días, del más antiguo a hoy.
    var days: [DayUsage] = []
    var session: SessionUsage?

    var today: DayUsage? { days.last }
    var weekTokens: Int { days.reduce(0) { $0 + $1.tokens } }
}

@Observable
final class ClaudeLogStats {
    private(set) var snapshot = UsageSnapshot()

    @ObservationIgnored private let scanner = LogScanner()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var scanning = false

    func start() {
        refresh()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        guard !scanning else { return }
        scanning = true
        Task {
            // `await` sobre un actor: el trabajo se hace en su propio hilo y volvemos aquí con el resultado.
            let result = await scanner.scan()
            if result != snapshot { snapshot = result }
            scanning = false
        }
    }
}

/// Un `actor` es una clase cuyo estado solo toca un hilo a la vez (como un objeto con un lock
/// en cada método, pero comprobado por el compilador). Lee los logs de forma incremental:
/// recuerda hasta qué byte leyó cada fichero y solo procesa lo nuevo.
actor LogScanner {
    private struct FileState {
        var offset: UInt64 = 0
        /// Hora de la última línea que no es del asistente (prompt o resultado de herramienta):
        /// la respuesta siguiente empieza a generarse ahí.
        var lastRequestTime: Date?
    }

    private struct Response {
        var time: Date
        var started: Date?
        var session: String
        var project: String
        var input = 0
        var output = 0
        var cacheCreation = 0
        var cacheRead = 0

        var tokens: Int { input + output + cacheCreation + cacheRead }
        var duration: TimeInterval? {
            guard let started else { return nil }
            let value = time.timeIntervalSince(started)
            return (0.3...900).contains(value) ? value : nil
        }
    }

    private var files: [String: FileState] = [:]
    /// Respuestas por requestId: Claude Code escribe una línea por bloque de contenido, con el
    /// mismo uso repetido, así que hay que deduplicar.
    private var responses: [String: Response] = [:]
    private let formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func scan() -> UsageSnapshot {
        let root = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects")
        let cutoff = Date.now.addingTimeInterval(-8 * 86_400)
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

        if let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) {
            for case let url as URL in enumerator where url.pathExtension == "jsonl" {
                guard let values = try? url.resourceValues(forKeys: Set(keys)),
                      let modified = values.contentModificationDate, modified > cutoff else { continue }
                read(url, size: UInt64(values.fileSize ?? 0))
            }
        }
        responses = responses.filter { $0.value.time > cutoff }
        return makeSnapshot()
    }

    private func read(_ url: URL, size: UInt64) {
        var state = files[url.path] ?? FileState()
        if size < state.offset { state = FileState() } // el fichero se reescribió: empezar de cero
        guard size > state.offset, let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        try? handle.seek(toOffset: state.offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }

        // Solo procesamos hasta el último salto de línea; una línea a medio escribir se lee la próxima vez.
        guard let lastNewline = data.lastIndex(of: UInt8(ascii: "\n")) else { return }
        let complete = data[data.startIndex...lastNewline]
        state.offset += UInt64(complete.count)

        let usageMarker = Data(#""usage""#.utf8)
        for line in complete.split(separator: UInt8(ascii: "\n")) where !line.isEmpty {
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let stamp = object["timestamp"] as? String,
                  let time = formatter.date(from: stamp) else { continue }

            guard object["type"] as? String == "assistant",
                  line.range(of: usageMarker) != nil,
                  let message = object["message"] as? [String: Any],
                  let usage = message["usage"] as? [String: Any] else {
                if object["type"] as? String == "user" { state.lastRequestTime = time }
                continue
            }

            let key = (object["requestId"] as? String) ?? (message["id"] as? String) ?? UUID().uuidString
            func int(_ name: String) -> Int { (usage[name] as? NSNumber)?.intValue ?? 0 }
            var response = responses[key] ?? Response(
                time: time,
                started: state.lastRequestTime,
                session: object["sessionId"] as? String ?? "",
                project: ((object["cwd"] as? String) as NSString?)?.lastPathComponent ?? "—"
            )
            response.time = max(response.time, time)
            response.input = max(response.input, int("input_tokens"))
            response.output = max(response.output, int("output_tokens"))
            response.cacheCreation = max(response.cacheCreation, int("cache_creation_input_tokens"))
            response.cacheRead = max(response.cacheRead, int("cache_read_input_tokens"))
            responses[key] = response
        }
        files[url.path] = state
    }

    private func makeSnapshot() -> UsageSnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var days = (0..<7).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map { DayUsage(day: $0) }
        }
        for response in responses.values {
            let day = calendar.startOfDay(for: response.time)
            if let index = days.firstIndex(where: { $0.day == day }) {
                days[index].tokens += response.tokens
                days[index].output += response.output
            }
        }

        // Sesión actual = la de la respuesta más reciente.
        var session: SessionUsage?
        if let latest = responses.values.max(by: { $0.time < $1.time }) {
            let items = responses.values.filter { $0.session == latest.session }.sorted { $0.time < $1.time }
            var usage = SessionUsage(
                project: latest.project,
                started: items.first?.started ?? items.first?.time ?? latest.time,
                lastActivity: latest.time
            )
            var timedOutput = 0
            var timedDuration: TimeInterval = 0
            for item in items {
                usage.input += item.input
                usage.output += item.output
                usage.cacheCreation += item.cacheCreation
                usage.cacheRead += item.cacheRead
                if let duration = item.duration {
                    timedOutput += item.output
                    timedDuration += duration
                }
            }
            if let last = items.last(where: { $0.duration != nil }), let duration = last.duration {
                usage.lastResponseRate = Double(last.output) / duration
            }
            if timedDuration > 0 { usage.averageRate = Double(timedOutput) / timedDuration }
            session = usage
        }
        return UsageSnapshot(days: days, session: session)
    }
}
