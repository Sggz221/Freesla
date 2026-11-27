//
//  AgentBadge.swift
//  Freesla
//
//  Logo del agente rodeado de un anillo con el % usado de la ventana de 5 h.
//  El logo es un SF Symbol genérico; si quieres el logo real, añádelo a Assets.xcassets
//  y cambia `Image(systemName:)` por `Image("NombreDelAsset")` en `AgentLogo`.
//

import SwiftUI

extension Color {
    /// Coral, el tono que usamos para el agente.
    static let agent = Color(red: 0.85, green: 0.47, blue: 0.34)

    /// Verde → amarillo → rojo según el % usado (0...1).
    static func usage(_ fraction: Double) -> Color {
        switch fraction {
        case ..<0.6: .green
        case ..<0.85: .yellow
        default: .red
        }
    }
}

struct AgentBadge: View {
    @Environment(IslandModel.self) private var model
    let diameter: CGFloat
    var lineWidth: CGFloat = 3

    var body: some View {
        let fraction = min(max((model.usage.fiveHour?.utilization ?? 0) / 100, 0), 1)

        ZStack {
            Circle().stroke(.white.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color.usage(fraction), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // que empiece arriba (las 12) y no a las 3

            if model.agent.justFinished {
                Image(systemName: "checkmark")
                    .font(.system(size: diameter * 0.42, weight: .bold))
                    .foregroundStyle(.green)
                    .transition(.scale.combined(with: .opacity))
            } else {
                AgentLogo(isWorking: model.agent.activity == .working, size: diameter * 0.5)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: diameter, height: diameter)
        .overlay(alignment: .topTrailing) {
            if model.agent.activity == .needsInput {
                Circle()
                    .fill(.orange)
                    .frame(width: diameter * 0.28, height: diameter * 0.28)
                    .offset(x: lineWidth, y: -lineWidth)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: model.agent.justFinished)
        .animation(.easeInOut, value: fraction)
    }
}

struct AgentLogo: View {
    let isWorking: Bool
    let size: CGFloat

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(Color.agent)
            // Mientras el agente trabaja, el logo "respira".
            .symbolEffect(.pulse, isActive: isWorking)
    }
}
