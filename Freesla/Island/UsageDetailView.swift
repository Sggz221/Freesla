//
//  UsageDetailView.swift
//  Freesla
//
//  Detalle de uso de Claude: ventana de 5 h, semana, sesión actual, tok/s y gráfico diario.
//

import Charts
import SwiftUI

struct UsageDetailView: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let snapshot = model.stats.snapshot
        let session = snapshot.session

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button {
                    model.page = .home
                } label: {
                    Label("Volver", systemImage: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: model.notchSize.width + 24)
                Text("Uso de Claude")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(height: model.notchSize.height)

            HStack(spacing: 10) {
                PercentTile(title: "Ventana 5 h", window: model.usage.fiveHour)
                PercentTile(title: "Semana", window: model.usage.sevenDay)
                StatTile(
                    title: "Esta sesión",
                    value: session.map { Fmt.tokens($0.total) } ?? "—",
                    detail: session.map { "\($0.project) · salida \(Fmt.tokens($0.output))" } ?? "Sin sesiones"
                )
                StatTile(
                    title: "Salida",
                    value: session?.lastResponseRate.map { "\(Int($0.rounded())) tok/s" } ?? "—",
                    detail: session?.averageRate.map { "media \(Int($0.rounded())) tok/s" } ?? "última respuesta"
                )
            }
            .frame(height: 74)

            HStack(alignment: .top, spacing: 14) {
                Chart(snapshot.days) { day in
                    BarMark(
                        x: .value("Día", day.day, unit: .day),
                        y: .value("Tokens", day.tokens)
                    )
                    .foregroundStyle(Calendar.current.isDateInToday(day.day) ? Color.agent : Color.agent.opacity(0.5))
                    .cornerRadius(3)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(.white.opacity(0.1))
                        AxisValueLabel { Text(Fmt.tokens(value.as(Int.self) ?? 0)) }
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    Metric(title: "Hoy", value: Fmt.tokens(snapshot.today?.tokens ?? 0), detail: "salida \(Fmt.tokens(snapshot.today?.output ?? 0))")
                    Metric(title: "7 días", value: Fmt.tokens(snapshot.weekTokens), detail: nil)
                    if let session {
                        Metric(title: "Sesión", value: session.started.formatted(date: .omitted, time: .shortened),
                               detail: "caché \(Fmt.tokens(session.cacheRead + session.cacheCreation))")
                    }
                }
                .frame(width: 120, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }
}

private struct PercentTile: View {
    let title: String
    let window: UsageWindow?

    var body: some View {
        let fraction = min(max((window?.utilization ?? 0) / 100, 0), 1)
        Tile {
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(.white.opacity(0.15), lineWidth: 4)
                    Circle().trim(from: 0, to: fraction)
                        .stroke(Color.usage(fraction), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(window.map { "\(Int($0.utilization.rounded()))" } ?? "–")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                }
                .frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
                    Text("\(Int((window?.utilization ?? 0).rounded())) %").font(.system(size: 13, weight: .semibold))
                    Text(Fmt.remaining(until: window?.resetsAt)).font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        Tile {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 10)).foregroundStyle(.secondary)
                Text(value).font(.system(size: 15, weight: .semibold)).monospacedDigit()
                Text(detail).font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
    }
}

private struct Metric: View {
    let title: String
    let value: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 9)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 13, weight: .semibold)).monospacedDigit()
            if let detail { Text(detail).font(.system(size: 9)).foregroundStyle(.secondary) }
        }
        .lineLimit(1)
    }
}

/// Contenedor común de las tarjetas. `@ViewBuilder` permite pasarle vistas entre llaves.
private struct Tile<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .lineLimit(1)
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }
}
