import SwiftUI
import UIKit

/// Holds its content upright against gravity, however the window underneath
/// it happens to be lying.
///
/// The picture behind the HUD is levelled by `RotationCoordinator`, which
/// reads gravity and never asks the interface — so the camera follows the
/// phone whether or not the window does. The window stops following the
/// moment Portrait Orientation Lock is on, and what is left is a HUD on its
/// side over a level picture: score in the wrong corner, cue card down the
/// wrong edge, pause button nowhere near where a hand would reach for it.
///
/// This closes the gap by turning the stage the rest of the way itself —
/// where the phone is, less where the window already got to. The two agree
/// whenever iOS is free to rotate the app, so with the lock off this is a
/// no-op and the system's own rotation is left to do the work.
///
/// The content is handed the stage as the player sees it: on a quarter turn
/// width and height trade places, so a portrait window held sideways lays
/// out as the landscape stage it looks like.
struct UprightStage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    /// Read as it arrives, and never acted on directly — see `turn`.
    @State private var reading = OrientationReading()
    /// The turn actually applied, taken from a reading that has stopped
    /// moving. An unlocked rotation changes both halves of a reading a beat
    /// apart, and turning on the first half would swing the stage away and
    /// straight back again as the second arrived.
    @State private var turn = StageTurn.none

    /// Long enough for the window to have been told about a rotation, short
    /// enough that a locked stage does not visibly trail the picture.
    private let settleSeconds = 0.22

    var body: some View {
        GeometryReader { proxy in
            let stage = turn.stage(in: proxy.size)

            content()
                .frame(width: stage.width, height: stage.height)
                .rotationEffect(turn.angle)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .animation(Theme.Motion.screenChange, value: turn)
        }
        .background(
            InterfaceOrientationReader { reading.interface = $0 }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            readDevice()
        }
        .onAppear {
            UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            readDevice()
        }
        .onDisappear {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        .task(id: reading) {
            try? await Task.sleep(for: .seconds(settleSeconds))
            guard !Task.isCancelled else { return }
            turn = StageTurn(device: reading.device, interface: reading.interface)
        }
    }

    /// Flat on a table is not an orientation the stage can use — `.faceUp`
    /// says nothing about which edge is up — so the last real answer is kept
    /// rather than being overwritten with a shrug.
    private func readDevice() {
        let current = UIDevice.current.orientation
        guard current.isPortrait || current.isLandscape else { return }
        reading.device = current
    }
}

/// Where the phone is and where the window got to, so the two can be settled
/// together rather than one at a time.
private struct OrientationReading: Equatable {
    var device: UIDeviceOrientation = .unknown
    var interface: UIInterfaceOrientation = .portrait
}

/// The quarter turns still owed between the phone and the window.
struct StageTurn: Equatable {
    /// Clockwise, which is the direction `rotationEffect` counts in.
    let angle: Angle
    private let quarters: Int

    static let none = StageTurn(device: .unknown, interface: .portrait)

    init(device: UIDeviceOrientation, interface: UIInterfaceOrientation) {
        // Before the phone has reported an orientation it can stand behind,
        // the window is taken to be right — which it is, until it is locked.
        guard device.isPortrait || device.isLandscape else {
            quarters = 0
            angle = .zero
            return
        }

        quarters = (Self.quarters(of: device) - Self.quarters(of: interface) + 4) % 4
        angle = .degrees(Double(quarters) * 90)
    }

    /// The stage as the player sees it. Width and height trade places on a
    /// quarter turn: a portrait window held sideways is a landscape stage,
    /// and laying the HUD out against the window's own numbers is what would
    /// run its furniture down the long edge of a screen that is now wide.
    func stage(in window: CGSize) -> CGSize {
        quarters.isMultiple(of: 2)
            ? window
            : CGSize(width: window.height, height: window.width)
    }

    /// Clockwise quarter turns the content needs in order to stand up in a
    /// phone held this way. `.landscapeLeft` is the phone turned
    /// anticlockwise — home edge to the right — so the content has to come
    /// back the other way.
    private static func quarters(of device: UIDeviceOrientation) -> Int {
        switch device {
        case .landscapeLeft: 1
        case .portraitUpsideDown: 2
        case .landscapeRight: 3
        default: 0
        }
    }

    /// The same count for the turn the window has already been given. The two
    /// landscape cases are named from opposite ends — the window iOS puts up
    /// for a phone in `UIDeviceOrientation.landscapeLeft` is
    /// `UIInterfaceOrientation.landscapeRight` — which is exactly why this
    /// cannot be one shared table.
    private static func quarters(of interface: UIInterfaceOrientation) -> Int {
        switch interface {
        case .landscapeRight: 1
        case .portraitUpsideDown: 2
        case .landscapeLeft: 3
        default: 0
        }
    }
}

/// Reports the window's own orientation, and keeps reporting it as the window
/// turns.
///
/// `UIWindowScene.interfaceOrientation` is a plain property with nothing
/// published behind it, and the device notification fires while the window is
/// still on its way rather than after — so the moment worth reading it is
/// when the window has laid out again, which is what this waits for.
private struct InterfaceOrientationReader: UIViewRepresentable {
    let onChange: (UIInterfaceOrientation) -> Void

    func makeUIView(context: Context) -> ReaderView {
        let view = ReaderView()
        view.onChange = onChange
        return view
    }

    func updateUIView(_ view: ReaderView, context: Context) {
        view.onChange = onChange
    }

    final class ReaderView: UIView {
        var onChange: ((UIInterfaceOrientation) -> Void)?
        private var reported: UIInterfaceOrientation?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            report()
        }

        /// Only genuine changes are passed on, and never from inside the
        /// layout pass that noticed them: this drives SwiftUI state, and
        /// setting that mid-layout is how one rotation becomes a loop.
        private func report() {
            guard let orientation = window?.windowScene?.interfaceOrientation,
                  orientation != reported
            else { return }
            reported = orientation

            let onChange = self.onChange
            DispatchQueue.main.async { onChange?(orientation) }
        }
    }
}
