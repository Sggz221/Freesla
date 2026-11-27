//
//  CollapsedIslandView.swift
//  Freesla
//
//  Isla contraída: a la izquierda del notch las barras de música, a la derecha el agente.
//

import SwiftUI

struct CollapsedIslandView: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                if let info = model.nowPlaying.info {
                    MusicBarsView(isPlaying: info.isPlaying, height: 13)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: model.earWidth)

            Spacer(minLength: model.notchSize.width)

            ZStack {
                if model.showsAgentEar {
                    AgentBadge(diameter: model.notchSize.height - 10, lineWidth: 2.5)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(width: model.earWidth)
        }
        .frame(height: model.notchSize.height)
    }
}

/// Las tres barras animadas de "está sonando música", como en el iPhone.
/// `TimelineView(.animation)` redibuja en cada fotograma; la altura de cada barra sigue
/// una onda seno con velocidad y fase distintas. En pausa, las barras quedan bajas y quietas.
struct MusicBarsView: View {
    let isPlaying: Bool
    var height: CGFloat = 14
    var color: Color = .white

    private let speeds: [Double] = [5.1, 6.7, 4.3]
    private let phases: [Double] = [0, 1.7, 3.1]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2.5) {
                ForEach(0..<3, id: \.self) { index in
                    let level = isPlaying ? 0.3 + 0.7 * abs(sin(time * speeds[index] + phases[index])) : 0.25
                    Capsule()
                        .fill(color)
                        .frame(width: 3, height: height * level)
                }
            }
            .frame(height: height)
        }
    }
}
