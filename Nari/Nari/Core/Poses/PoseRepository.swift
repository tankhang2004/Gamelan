import Foundation
import OSLog

/// Supplies the poses the game can ask for.
protocol PoseProviding {
    var poses: [PoseDefinition] { get }
    func pose(id: String) -> PoseDefinition?
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
        guard let url = bundle.url(forResource: "poses", withExtension: "json") else {
            Logger.poses.error("poses.json is missing from the bundle; falling back to the built-in agem pose.")
            return [.fallbackAgem]
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(File.self, from: data)
            guard !file.poses.isEmpty else { return [.fallbackAgem] }
            return file.poses
        } catch {
            // A typo in the JSON should not take the game down mid-session.
            Logger.poses.error("poses.json could not be read: \(error.localizedDescription)")
            return [.fallbackAgem]
        }
    }
}

extension Logger {
    static let poses = Logger(subsystem: "com.yuknari.Nari", category: "poses")
}

extension PoseDefinition {
    /// Kept in code so the game still runs if the JSON is missing or broken.
    static let fallbackAgem = PoseDefinition(
        id: "agem",
        names: ["id": "Agem", "en": "Agem"],
        instructions: [
            "id": "Rentangkan kedua tangan lurus sejajar bahu, lutut sedikit mendak.",
            "en": "Stretch both arms level with the shoulders, knees slightly bent.",
        ],
        holdSeconds: 3,
        targets: [
            PoseTarget(point: .head, x: 0, y: -1.35, tolerance: 0.5),
            PoseTarget(point: .leftWrist, x: 0.95, y: -1.0, tolerance: 0.45),
            PoseTarget(point: .rightWrist, x: -0.95, y: -1.0, tolerance: 0.45),
            PoseTarget(point: .leftKnee, x: 0.35, y: 0.55, tolerance: 0.45),
            PoseTarget(point: .rightKnee, x: -0.35, y: 0.55, tolerance: 0.45),
        ],
        rules: [
            PoseRule(
                kind: .lineAngle,
                joints: [.rightWrist, .leftWrist],
                targetDegrees: 0,
                toleranceDegrees: 15,
                affects: [.leftWrist, .rightWrist]
            )
        ],
        artworkName: "PoseAgem"
    )
}
