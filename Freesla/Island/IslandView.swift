//
//  IslandView.swift
//  Freesla
//
//  Vista raíz: la forma negra que cambia de tamaño con un spring.
//  Contraída muestra las "orejas" (música y agente); expandida, el contenido completo.
//

import SwiftUI

struct IslandView: View {
    @Environment(IslandModel.self) private var model

    var body: some View {
        let size = model.currentSize
        let shape = NotchShape(topRadius: IslandModel.shoulder, bottomRadius: model.isExpanded ? 30 : 12)

        ZStack(alignment: .top) {
            IslandBackground(isExpanded: model.isExpanded)

            Group {
                if model.isExpanded {
                    switch model.page {
                    case .home: ExpandedHomeView()
                    case .usage: UsageDetailView()
                    }
                } else {
                    CollapsedIslandView()
                }
            }
            .padding(.horizontal, IslandModel.shoulder)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        }
        .frame(width: size.width + 2 * IslandModel.shoulder, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        // Soltar archivos sobre la isla los añade al estante.
        .dropDestination(for: URL.self) { urls, _ in
            model.shelf.add(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            model.isDropTargeted = targeted
            if targeted { model.expand() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        // Anima cualquier cambio de tamaño/página con un spring.
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.isExpanded)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.page)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.collapsedSize)
    }
}

/// Fondo: negro; expandida, el 25 % inferior pasa de negro a Liquid Glass.
struct IslandBackground: View {
    @Environment(IslandModel.self) private var model
    let isExpanded: Bool

    var body: some View {
        GeometryReader { proxy in
            let glassHeight = proxy.size.height * 0.25
            ZStack(alignment: .bottom) {
                if isExpanded {
                    GlassSlab(islandSize: proxy.size, height: glassHeight, backdrop: model.backdrop.image)
                        .transition(.opacity)
                }
                // Negro que se desvanece hacia el cristal.
                Rectangle()
                    .fill(.black)
                    .mask {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: isExpanded ? 0.75 : 1),
                                .init(color: isExpanded ? .clear : .black, location: 1),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            }
        }
    }
}

/// La losa de cristal del cuarto inferior.
///
/// Con captura del fondo: pintamos lo que hay detrás del panel y lo deformamos con el shader
/// `liquidGlass` (lente en el borde, aberración cromática, desenfoque). Sin captura (falta el permiso
/// o aún no llegó el primer fotograma): cristal normal del sistema.
private struct GlassSlab: View {
    let islandSize: CGSize
    let height: CGFloat
    let backdrop: CGImage?

    var body: some View {
        let slab = UnevenRoundedRectangle(bottomLeadingRadius: 30, bottomTrailingRadius: 30)

        ZStack {
            if let backdrop {
                refracted(backdrop)
            } else {
                Rectangle().fill(.clear).glassEffect(.regular, in: Rectangle())
            }
            // Filo fino para definir el borde del cristal.
            slab.strokeBorder(
                LinearGradient(colors: [.white.opacity(0), .white.opacity(0.35)], startPoint: .top, endPoint: .bottom),
                lineWidth: 1
            )
        }
        .frame(width: islandSize.width, height: height)
        .clipShape(slab)
    }

    private func refracted(_ image: CGImage) -> some View {
        let panel = IslandModel.panelSize
        // La captura cubre justo el panel; la isla va centrada arriba. Desplazamos la imagen para que
        // el trozo que cae detrás de la losa quede dentro de ella.
        let dx = (panel.width - islandSize.width) / 2
        let dy = islandSize.height - height
        return ZStack(alignment: .topLeading) {
            Image(decorative: image, scale: 1)
                .resizable()
                .frame(width: panel.width, height: panel.height)
                .offset(x: -dx, y: -dy)
        }
        .frame(width: islandSize.width, height: height, alignment: .topLeading)
        .clipped()
        .layerEffect(
            ShaderLibrary.liquidGlass(
                .float2(CGSize(width: islandSize.width, height: height)),
                .float(30),   // radio de las esquinas inferiores
                .float(28),   // ancho de la franja que actúa como lente
                .float(16),   // desplazamiento máximo en el canto
                .float(0.35), // aberración cromática
                .float(2.5)   // desenfoque
            ),
            maxSampleOffset: CGSize(width: 48, height: 48)
        )
    }
}

/// Forma de la isla: hombros cóncavos arriba (como el notch real) y esquinas redondeadas abajo.
/// `animatableData` le dice a SwiftUI qué números interpolar durante la animación.
struct NotchShape: Shape {
    var topRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(topRadius, bottomRadius) }
        set {
            topRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = topRadius
        let bottom = min(bottomRadius, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top, y: rect.minY + top),
                          control: CGPoint(x: rect.minX + top, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + top, y: rect.maxY - bottom))
        path.addQuadCurve(to: CGPoint(x: rect.minX + top + bottom, y: rect.maxY),
                          control: CGPoint(x: rect.minX + top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top - bottom, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - top, y: rect.maxY - bottom),
                          control: CGPoint(x: rect.maxX - top, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - top, y: rect.minY + top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.maxX - top, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
