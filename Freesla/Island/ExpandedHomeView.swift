//
//  ExpandedHomeView.swift
//  Freesla
//
//  Isla expandida: música + agente arriba, estante de archivos abajo (sobre el cristal).
//

import SwiftUI

struct ExpandedHomeView: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        VStack(spacing: 10) {
            // Fila a la altura del notch: el centro queda libre porque el notch lo tapa.
            HStack {
                Text(model.nowPlaying.info?.playerName ?? "Freesla")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: model.notchSize.width + 24)
                AgentStatusText()
                    .font(.system(size: 11, weight: .semibold))
            }
            .frame(height: model.notchSize.height)

            HStack(alignment: .center, spacing: 16) {
                NowPlayingCard()
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .fill(.white.opacity(0.12))
                    .frame(width: 1, height: 64)
                AgentCard()
                    .frame(width: 180, alignment: .leading)
            }
            .frame(height: 84)

            ShelfView()
                .frame(height: 64)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
    }
}

/// Texto de estado del agente para la fila superior.
struct AgentStatusText: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let agent = model.agent
        Group {
            if agent.justFinished {
                Label("Tarea terminada", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                switch agent.activity {
                case .working:
                    Label("Trabajando · \(agent.project ?? "")", systemImage: "sparkle").foregroundStyle(Color.agent)
                case .needsInput:
                    Label("Necesita tu atención", systemImage: "exclamationmark.circle.fill").foregroundStyle(.orange)
                case .idle:
                    if let finished = agent.lastFinishedAt {
                        Text("Última tarea \(finished, format: .relative(presentation: .named))")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Agente en reposo").foregroundStyle(.secondary)
                    }
                }
            }
        }
        .lineLimit(1)
    }
}

// MARK: - Música

struct NowPlayingCard: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        if let info = model.nowPlaying.info {
            HStack(spacing: 12) {
                Artwork(image: info.artwork, isPlaying: info.isPlaying)

                VStack(alignment: .leading, spacing: 3) {
                    Text(info.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(info.artist ?? info.album ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    PlaybackProgress(info: info)
                        .padding(.top, 2)
                    PlaybackControls(isPlaying: info.isPlaying)
                }
            }
        } else {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.08))
                    .frame(width: 64, height: 64)
                    .overlay { Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary) }
                VStack(alignment: .leading, spacing: 3) {
                    Text("No suena nada").font(.system(size: 13, weight: .semibold))
                    Text(model.nowPlaying.isAvailable ? "Pon algo en TIDAL" : "Adaptador de música no disponible")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct Artwork: View {
    let image: NSImage?
    let isPlaying: Bool

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                Color.white.opacity(0.08)
                Image(systemName: "music.note").font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .bottomTrailing) {
            MusicBarsView(isPlaying: isPlaying, height: 10)
                .padding(5)
                .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 5))
                .padding(4)
        }
    }
}

struct PlaybackProgress: View {
    let info: NowPlayingInfo

    var body: some View {
        // Redibuja cada medio segundo para que avance la barra.
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let elapsed = info.elapsed(at: context.date) ?? 0
            let duration = info.duration ?? 0
            HStack(spacing: 6) {
                Text(Fmt.clock(elapsed)).monospacedDigit()
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.18))
                        Capsule().fill(.white)
                            .frame(width: duration > 0 ? proxy.size.width * min(elapsed / duration, 1) : 0)
                    }
                }
                .frame(height: 3)
                Text(Fmt.clock(duration)).monospacedDigit()
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
        }
    }
}

struct PlaybackControls: View {
    @Environment(IslandModel.self) private var model
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 18) {
            ControlButton(systemImage: "backward.end.fill", help: "Reiniciar canción") { model.nowPlaying.restartTrack() }
            ControlButton(systemImage: isPlaying ? "pause.fill" : "play.fill", help: isPlaying ? "Pausa" : "Reproducir") {
                model.nowPlaying.togglePlayPause()
            }
            ControlButton(systemImage: "forward.fill", help: "Siguiente") { model.nowPlaying.nextTrack() }
        }
        .padding(.top, 1)
    }
}

struct ControlButton: View {
    let systemImage: String
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 22, height: 18)
                .contentShape(Rectangle())
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Agente

struct AgentCard: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        Button {
            model.page = .usage
        } label: {
            HStack(spacing: 12) {
                AgentBadge(diameter: 46, lineWidth: 4)
                VStack(alignment: .leading, spacing: 2) {
                    if let five = model.usage.fiveHour {
                        Text("5 h · \(Int(five.utilization.rounded())) %")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Reinicio en \(Fmt.remaining(until: five.resetsAt))")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Uso de Claude").font(.system(size: 13, weight: .semibold))
                        Text(model.usage.problem ?? "Cargando…")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Text("Ver detalle ›")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.agent)
                        .padding(.top, 2)
                }
                .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Estante

struct ShelfView: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let shelf = model.shelf
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.2, dash: shelf.items.isEmpty ? [5, 4] : []))
                .foregroundStyle(.white.opacity(model.isDropTargeted ? 0.9 : 0.25))
                .background(.white.opacity(model.isDropTargeted ? 0.12 : 0), in: RoundedRectangle(cornerRadius: 14))

            if shelf.items.isEmpty {
                Label("Suelta archivos aquí", systemImage: "tray.and.arrow.down")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                HStack(spacing: 0) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(shelf.items) { item in
                                ShelfItemView(item: item)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
                    Button {
                        shelf.clear()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 12))
                            .frame(width: 32, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Vaciar estante")
                }
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 4)
    }
}

struct ShelfItemView: View {
    @Environment(IslandModel.self) private var model
    let item: ShelfItem

    var body: some View {
        VStack(spacing: 2) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: item.url.path))
                .resizable()
                .frame(width: 34, height: 34)
            Text(item.url.lastPathComponent)
                .font(.system(size: 9))
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 58)
        }
        .help(item.url.path)
        // Arrastrar hacia fuera: entregamos el archivo real (Finder, Mail, Slack... lo aceptan).
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onTapGesture(count: 2) { NSWorkspace.shared.open(item.url) }
        .contextMenu {
            Button("Abrir") { NSWorkspace.shared.open(item.url) }
            Button("Mostrar en Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
            Divider()
            Button("Quitar del estante") { model.shelf.remove(item) }
        }
    }
}
