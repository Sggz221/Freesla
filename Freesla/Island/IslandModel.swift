//
//  IslandModel.swift
//  Freesla
//
//  Estado de la isla (expandida o no, qué página) y acceso a los servicios.
//  Las vistas lo reciben con `.environment(model)` y lo leen con `@Environment(IslandModel.self)`
//  (parecido a la inyección de dependencias de .NET, pero por el árbol de vistas).
//

import SwiftUI

enum IslandPage {
    case home
    case usage
}

@Observable
final class IslandModel {
    let nowPlaying: NowPlayingService
    let usage: ClaudeUsageService
    let stats: ClaudeLogStats
    let agent: AgentEventWatcher
    let shelf: ShelfStore
    let backdrop = BackdropCapture()
    /// Lo llama la isla al expandirse/contraerse; el AppDelegate lo usa para arrancar/parar la captura del fondo.
    var onExpansionChange: ((Bool) -> Void)?

    var notchSize = CGSize(width: 190, height: 32)
    private(set) var isExpanded = false
    var page: IslandPage = .home
    var isDropTargeted = false

    /// Radio de los "hombros" cóncavos de arriba, que funden la isla con el borde de la pantalla.
    static let shoulder: CGFloat = 10
    static let homeSize = CGSize(width: 580, height: 232)
    static let usageSize = CGSize(width: 580, height: 330)
    /// Tamaño fijo del panel: cabe la isla más grande con margen para el rebote del spring.
    static let panelSize = CGSize(width: 580 + 2 * shoulder + 60, height: 330 + 40)

    init(nowPlaying: NowPlayingService, usage: ClaudeUsageService, stats: ClaudeLogStats,
         agent: AgentEventWatcher, shelf: ShelfStore) {
        self.nowPlaying = nowPlaying
        self.usage = usage
        self.stats = stats
        self.agent = agent
        self.shelf = shelf
    }

    /// Ancho de cada "oreja" que asoma a los lados del notch cuando está contraída.
    var earWidth: CGFloat { notchSize.height + 12 }
    var showsMusicEar: Bool { nowPlaying.info != nil }
    var showsAgentEar: Bool { usage.fiveHour != nil || agent.activity != .idle || agent.justFinished }

    var collapsedSize: CGSize {
        let hasEars = showsMusicEar || showsAgentEar
        return CGSize(width: notchSize.width + (hasEars ? earWidth * 2 : 0), height: notchSize.height)
    }
    var expandedSize: CGSize { page == .home ? Self.homeSize : Self.usageSize }
    /// Tamaño del cuerpo de la isla (sin contar los hombros).
    var currentSize: CGSize { isExpanded ? expandedSize : collapsedSize }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
        onExpansionChange?(true)
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        page = .home
        onExpansionChange?(false)
    }
}
