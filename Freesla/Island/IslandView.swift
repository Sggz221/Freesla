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
        let shape = NotchShape(topRadius: model.shoulder, bottomRadius: model.isExpanded ? 30 : 12)

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
            .padding(.horizontal, model.shoulder)
            .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
        }
        .frame(width: size.width + 2 * model.shoulder, height: size.height)
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
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: model.shoulder)
    }
}

/// Fondo: siempre negro puro (#000000, como el notch físico); expandida, el 25 % inferior
/// se funde en el cristal del sistema (`glassEffect`).
struct IslandBackground: View {
    let isExpanded: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                if isExpanded {
                    // El cristal solo ocupa el cuarto inferior y entra con un degradado.
                    Rectangle()
                        .fill(.clear)
                        .frame(height: proxy.size.height * 0.25)
                        .glassEffect(.regular, in: Rectangle())
                        .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                }
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
