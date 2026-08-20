import Foundation
import OSLog

/// Supplies the poses the game can ask for.
protocol PoseProviding {
    var poses: [PoseDefinition] { get }
    func pose(id: String) -> PoseDefinition?
}

extension PoseProviding {
    /// The pose a Freeze cue asks for, falling back to the built-in definition
    /// so a broken JSON file cannot strand a run mid-cue.
    func pose(for side: AgemSide) -> PoseDefinition {
        pose(id: side.poseID) ?? .fallbackAgem(side)
    }
}

/// Reads `Resources/Poses/poses.json`.
///
/// Adding a pose means adding one entry to that file — no code change. See the
/// comments on `PoseTarget` for what the numbers mean, and run the game with
/// `-debugPrintPose` to have the current body printed in the right coordinates
/// while you stand in the pose you want to record.
struct PoseRepository: PoseProviding {
    private struct File: Decodable {
        let poses: [PoseDefinition]
    }

    let poses: [PoseDefinition]

    init(bundle: Bundle = .main) {
        poses = Self.load(from: bundle)
    }

    func pose(id: String) -> PoseDefinition? {
        poses.first { $0.id == id }
    }

    private static func load(from bundle: Bundle) -> [PoseDefinition] {
        let builtIn = AgemSide.allCases.map(PoseDefinition.fallbackAgem)

        guard let url = bundle.url(forResource: "poses", withExtension: "json") else {
            Logger.poses.error("poses.json is missing from the bundle; falling back to the built-in agem poses.")
            return builtIn
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(File.self, from: data)
            guard !file.poses.isEmpty else { return builtIn }
            return file.poses
        } catch {
            // A typo in the JSON should not take the game down mid-session.
            Logger.poses.error("poses.json could not be read: \(error.localizedDescription)")
            return builtIn
        }
    }
}

extension Logger {
    static let poses = Logger(subsystem: "com.yuknari.Nari", category: "poses")
}

extension PoseDefinition {
    /// Kept in code so the game still runs if the JSON is missing or broken.
    /// The two sides are mirror images, so one definition is written and the
    /// other is produced by flipping every x — there is no second set of numbers
    /// to keep in step.
    static func fallbackAgem(_ side: AgemSide) -> PoseDefinition {
        let kanan = PoseDefinition(
            id: AgemSide.kanan.poseID,
            names: ["id": "Agem Kanan", "en": "Agem Kanan"],
            instructions: [
                "id": "Berat badan ke kanan, tangan kanan setinggi bahu, lutut mendak.",
                "en": "Weight on the right, right arm level with the shoulder, knees bent.",
            ],
            holdSeconds: 7,
            targets: [
                PoseTarget(point: .neck, x: 0.05, y: -0.95, tolerance: 0.40),
                PoseTarget(point: .rightWrist, x: -1.05, y: -0.95, tolerance: 0.50),
                PoseTarget(point: .rightElbow, x: -0.60, y: -0.90, tolerance: 0.45),
                PoseTarget(point: .leftWrist, x: 0.35, y: -0.70, tolerance: 0.50),
                PoseTarget(point: .leftElbow, x: 0.45, y: -0.30, tolerance: 0.45),
                PoseTarget(point: .rightKnee, x: -0.45, y: 0.60, tolerance: 0.45),
                PoseTarget(point: .leftKnee, x: 0.40, y: 0.60, tolerance: 0.45),
                PoseTarget(point: .rightAnkle, x: -0.40, y: 1.35, tolerance: 0.50),
                PoseTarget(point: .leftAnkle, x: 0.45, y: 1.35, tolerance: 0.50),
            ],
            rules: [
                PoseRule(
                    kind: .lineAngle,
                    joints: [.rightShoulder, .leftShoulder],
                    targetDegrees: 0,
                    toleranceDegrees: 18,
                    affects: [.neck]
                )
            ],
            artworkName: "PoseAgemKanan"
        )

        return side == .kanan ? kanan : kanan.mirrored(
            id: AgemSide.kiri.poseID,
            names: ["id": "Agem Kiri", "en": "Agem Kiri"],
            artworkName: "PoseAgemKiri"
        )
    }

    /// The same pose seen in a mirror: every target crosses the centre line and
    /// every left joint swaps with its right.
    func mirrored(id: String, names: [String: String], artworkName: String?) -> PoseDefinition {
        PoseDefinition(
            id: id,
            names: names,
            instructions: instructions,
            holdSeconds: holdSeconds,
            targets: targets.map {
                PoseTarget(point: $0.point.mirrored, x: -$0.x, y: $0.y, tolerance: $0.tolerance)
            },
            rules: rules.map {
                PoseRule(
                    kind: $0.kind,
                    joints: $0.joints.map(\.mirrored),
                    targetDegrees: $0.targetDegrees,
                    toleranceDegrees: $0.toleranceDegrees,
                    affects: $0.affects.map(\.mirrored)
                )
            },
            artworkName: artworkName
        )
    }
}
