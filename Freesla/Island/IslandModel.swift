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

    var notchSize = CGSize(width: 190, height: 32)
    /// false en monitores sin notch: ahí no hay cámara que tape el centro, así que mostramos la hora.
    var hasNotch = true
    private(set) var isExpanded = false
    var page: IslandPage = .home
    var isDropTargeted = false

    /// Radio de los "hombros" cóncavos de arriba, que funden la isla con el borde de la pantalla.
    static let shoulderMax: CGFloat = 10
    static let homeSize = CGSize(width: 580, height: 232)
    static let usageSize = CGSize(width: 580, height: 330)
    /// Tamaño fijo del panel: cabe la isla más grande con margen para el rebote del spring.
    static let panelSize = CGSize(width: 580 + 2 * shoulderMax + 60, height: 330 + 40)

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
    /// Solo hay "oreja" cuando hay algo que contar: música sonando o el agente activo/terminando.
    /// Si no, la isla se encoge al tamaño del notch para no tapar el menú de las apps.
    var showsMusicEar: Bool { nowPlaying.info?.isPlaying == true }
    var showsAgentEar: Bool { agent.activity != .idle || agent.justFinished }
    var hasEars: Bool { showsMusicEar || showsAgentEar }

    /// Radio de los "hombros" de arriba. En un Mac con notch y sin orejas es 0: la isla mide exactamente
    /// lo mismo que el notch y queda oculta tras él, sin asomar por los lados.
    var shoulder: CGFloat { !isExpanded && hasNotch && !hasEars ? 0 : Self.shoulderMax }

    var collapsedSize: CGSize {
        return CGSize(width: notchSize.width + (hasEars ? earWidth * 2 : 0), height: notchSize.height)
    }
    var expandedSize: CGSize { page == .home ? Self.homeSize : Self.usageSize }
    /// Tamaño del cuerpo de la isla (sin contar los hombros).
    var currentSize: CGSize { isExpanded ? expandedSize : collapsedSize }

    func expand() {
        guard !isExpanded else { return }
        isExpanded = true
    }

    func collapse() {
        guard isExpanded else { return }
        isExpanded = false
        page = .home
    }
}
