import SwiftUI

/// Two curtain panels meeting in the middle, plus a fixed valance across the top.
/// The panels swing aside on their outer edges when `phase` becomes `.open`.
struct CurtainView: View {
    let phase: CurtainPhase
    let valanceHeight: CGFloat

    /// The panels are each a little wider than half the stage so they overlap at
    /// the seam. Without it the idle breathing would open a hairline gap.
    private let seamOverlap: CGFloat = 18

    var body: some View {
        GeometryReader { proxy in
            let panelWidth = proxy.size.width / 2 + seamOverlap

            ZStack(alignment: .top) {
                ZStack {
                    CurtainPanelView(side: .leading, isOpen: phase.isOpen)
                        .frame(width: panelWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    CurtainPanelView(side: .trailing, isOpen: phase.isOpen)
                        .frame(width: panelWidth)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                CurtainValanceView()
                    .frame(height: valanceHeight)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Panel

struct CurtainPanelView: View {
    enum Side {
        case leading
        case trailing

        var hingeAnchor: UnitPoint { self == .leading ? .leading : .trailing }
        /// Sign used so both panels swing away from the centre seam.
        var direction: CGFloat { self == .leading ? -1 : 1 }
    }

    let side: Side
    let isOpen: Bool

    var body: some View {
        CurtainFabricView(side: side)
            .modifier(IdleBreathModifier(isActive: !isOpen, anchor: side.hingeAnchor))
            .rotation3DEffect(
                .degrees(isOpen ? 74 * side.direction : 0),
                axis: (x: 0, y: 1, z: 0),
                anchor: side.hingeAnchor,
                anchorZ: 0,
                perspective: 0.55
            )
            .offset(x: isOpen ? 48 * side.direction : 0)
    }
}

/// Slow horizontal breathing so the closed curtain never looks like a flat wall.
/// It pulls from the outer hinge only, so the seam in the middle stays put and
/// the hems on both panels keep lining up.
private struct IdleBreathModifier: ViewModifier {
    let isActive: Bool
    let anchor: UnitPoint
    @State private var isExpanded = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(x: isActive && isExpanded ? 1.0 : 0.994, anchor: anchor)
            .animation(
                isActive
                    ? .easeInOut(duration: 3.4).repeatForever(autoreverses: true)
                    : .default,
                value: isExpanded
            )
            .onAppear { isExpanded = true }
    }
}

// MARK: - Fabric

/// Vertical red / gold / cream bands with fold shading, a gold hem, and a darker
/// inner edge where the two panels meet.
struct CurtainFabricView: View {
    let side: CurtainPanelView.Side

    private let stripeCount = 9

    private static let bandColors: [Color] = [
        Theme.Palette.curtainRed,
        Theme.Palette.curtainGold,
        Theme.Palette.curtainCream,
        Theme.Palette.curtainGold,
    ]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ForEach(0..<stripeCount, id: \.self) { index in
                    bandColor(at: index)
                        .overlay(foldShading)
                        .frame(width: proxy.size.width / CGFloat(stripeCount))
                }
            }
            .overlay(seamShading)
            .overlay(alignment: .bottom) { hem }
        }
    }

    private func bandColor(at index: Int) -> Color {
        // Mirror the order on the right panel so the seam stays symmetrical.
        let position = side == .leading ? index : (stripeCount - 1 - index)
        return Self.bandColors[position % Self.bandColors.count]
    }

    /// Each band gets its own light-to-shadow ramp, which is what sells the
    /// pleats when the panel rotates.
    private var foldShading: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.42), location: 0.0),
                .init(color: .black.opacity(0.10), location: 0.22),
                .init(color: .white.opacity(0.16), location: 0.52),
                .init(color: .black.opacity(0.14), location: 0.80),
                .init(color: .black.opacity(0.40), location: 1.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .blendMode(.overlay)
    }

    /// Darkens the edge that meets the other panel, and lifts the outer edge.
    private var seamShading: some View {
        LinearGradient(
            colors: [.clear, .black.opacity(0.5)],
            startPoint: side == .leading ? .leading : .trailing,
            endPoint: side == .leading ? .trailing : .leading
        )
    }

    /// Straight gold band rather than scallops: the panels overlap at the seam,
    /// and two scalloped hems overlapping would show a visible notch there.
    private var hem: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [Theme.Palette.goldTrimBright, Theme.Palette.curtainGoldDeep],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 26)

            LinearGradient(
                colors: [Theme.Palette.curtainGoldDeep, Theme.Palette.woodDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 14)
        }
    }
}

// MARK: - Valance

/// The fixed pelmet across the top of the stage, with scalloped gold edging.
struct CurtainValanceView: View {
    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Theme.Palette.curtainRedDeep, Theme.Palette.curtainRed],
                startPoint: .top,
                endPoint: .bottom
            )
            .overlay(alignment: .top) {
                LinearGradient(
                    colors: [Theme.Palette.woodDark, .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 26)
            }

            ScallopedEdge(scallopWidth: 58)
                .fill(
                    LinearGradient(
                        colors: [Theme.Palette.goldTrimBright, Theme.Palette.curtainGoldDeep],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 30)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.black.opacity(0.25))
                .frame(height: 3)
                .blur(radius: 3)
                .offset(y: 12)
        }
        .shadow(color: .black.opacity(0.55), radius: 16, y: 8)
        .ignoresSafeArea(edges: .top)
    }
}

/// A row of half-circles hanging off the bottom edge, used for gold trim.
struct ScallopedEdge: Shape {
    let scallopWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height * 0.45))

        let count = max(1, Int((rect.width / scallopWidth).rounded()))
        let width = rect.width / CGFloat(count)
        let radius = min(width / 2, rect.height * 0.55)
        let baseline = rect.minY + rect.height * 0.45

        for index in 0..<count {
            let center = CGPoint(x: rect.minX + width * (CGFloat(index) + 0.5), y: baseline)
            path.addEllipse(
                in: CGRect(
                    x: center.x - radius,
                    y: center.y - radius,
                    width: radius * 2,
                    height: radius * 2
                )
            )
        }
        return path
    }
}

#Preview {
    GeometryReader { proxy in
        ZStack {
            StageBackdropView()
            CurtainView(phase: .closed, valanceHeight: MenuLayout(size: proxy.size).valanceHeight)
        }
    }
}
