//
//  Fmt.swift
//  Freesla
//
//  Pequeñas utilidades de formato para las vistas.
//

import Foundation

nonisolated enum Fmt {
    /// 1234567 → "1,2 M" (según el idioma del sistema).
    static func tokens(_ value: Int) -> String {
        value.formatted(.number.notation(.compactName).precision(.fractionLength(0...1)))
    }

    /// 125 → "2:05"
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Tiempo que falta hasta `date`: "2 h 10 min", "3 d 4 h", "ahora".
    static func remaining(until date: Date?) -> String {
        guard let date else { return "—" }
        let seconds = Int(date.timeIntervalSinceNow)
        guard seconds > 60 else { return "ahora" }
        let days = seconds / 86_400
        let hours = seconds % 86_400 / 3600
        let minutes = seconds % 3600 / 60
        if days > 0 { return "\(days) d \(hours) h" }
        if hours > 0 { return "\(hours) h \(minutes) min" }
        return "\(minutes) min"
    }
}
