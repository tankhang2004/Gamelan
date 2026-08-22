# Yuk, Nari!

A motion-tracking game for young Balinese dancers. The player walks in a steady
head-tilt rhythm (ngayog) and is interrupted at random to squat (nge'ed) or to
freeze into a held agem, all scored against a Taksu meter that ends the run when
it empties.

iPad only, landscape only. Deployment target iOS 17.

## Running

Open `Nari.xcodeproj` in Xcode and run on any iPad simulator or device.

From the command line:

```bash
xcodebuild -scheme Nari -destination 'generic/platform=iOS Simulator' build
```

## Architecture

MVVM with a thin service layer. Views hold no business state, view models hold
no view types, and services are the only things that touch persistence, audio,
or content.

```
Nari/
  App/                     Composition root and navigation
    NariApp.swift          Entry point, owns AppServices and AppRouter
    AppServices.swift      Builds the service graph once (no singletons)
    AppRouter.swift        Which screen is on stage
    RootView.swift         Hosts the current screen, injects the string table
    DebugLaunchOptions     DEBUG-only launch arguments for screenshots
  Core/
    Game/                  The loop: RunRules, RunPhase, RunEngine, ScoreHistory
    Models/                GameSettings, AppLanguage, MainMenuItem, GameMode
    Services/              SettingsStore, SettingsService, AudioService,
                           CreditsRepository
    Localization/          LocalizedKey, Localizer, environment plumbing
    Vision/                Camera capture, body pose detection, and the
                           ngayog / nge'ed detectors
    Poses/                 Pose definitions and the scoring rules
  DesignSystem/
    Theme.swift            Palette, metrics, motion timings, type styles
    Components/            PaintedShapes, PaintedButtonStyle, PopupCard
  Features/
    MainMenu/              MainMenuViewModel + stage views
    Settings/              SettingsViewModel + popup
    Credits/               CreditsViewModel + popup
    ScoreHistory/          Past runs, personal best highlighted
    Gameplay/              GameplayViewModel + the HUD
  Resources/
    Assets.xcassets
    Poses/poses.json
```

## The core loop

`RunEngine` owns the whole loop and knows nothing about cameras or views. It is
advanced one frame at a time with a `RunInput` — three booleans describing what
the body just did — and returns the list of `RunEvent`s that resulted.

| Phase | What happens |
|---|---|
| `ngayog` | The default. Each full left-right head tilt banks +5 points and +2% Taksu. One shared timer counts down to the next interrupt. |
| `squatCue` | 2 seconds to squat. Hit: +5 points, +5% Taksu. Miss: −8% Taksu. |
| `freezeGrace` | 3 seconds to get all nine points into the cued agem. Failing costs −20% Taksu. |
| `freezeHold` | 7 seconds of holding. +3% Taksu per second, and points drip at 20 × Taksu% per second, so a full meter pays more. Breaking early stops the drip with no penalty. |
| `gameOver` | Taksu hit 0. |

Squat and Freeze share **one** timer rather than having one each, which is what
makes "the two cues can never fire together" a property of the design instead of
a check somewhere in the code. Every 45 seconds survived, that timer's interval
shrinks by 10% (floor 2–5s) and the odds of it picking Freeze rise by 5 points
(cap 40%). No Freeze is cued in the first 10 seconds of a run.

Every number above lives in `RunRules` and nothing else hard-codes one.

### Where this departs from the design document

Two places, both deliberate, both one line to put back.

**The squat window is 2 seconds, not 1.** The GDD gives 1 second in the core loop
section and 2 in the mechanics section, and its scoring table contradicts itself
— success at 2 seconds, miss at 1. Two seconds is the number used. The cue is
unannounced, so the player spends a moment recognising it before a squat that
takes half a second to a second of travel on its own, and `SquatDetector` needs
the hips to actually cross its threshold on camera after that. One second leaves
no margin for the age group this is for. If you go back to 1, lower
`SquatDetector.depthThreshold` alongside it, or the window and the detector fight
each other.

**A missed Freeze costs Taksu instead of ending the run.** The GDD says both:
−20% Taksu *and* the round ends immediately. Those two clauses do not sit
together — if the round ends, the meter never gets to move on screen, so the
−20% is a number nobody sees. Ending the run there also quietly makes Freeze the
only real way to lose, which contradicts the document's own §5 ("the lose
condition is the Taksu meter reaching 0%"): ngayog pays about +1.1%/sec at a
steady rhythm while missing *every* squat costs about −1.2%/sec, so a player who
keeps tilting cannot drain the meter for minutes. So the run now continues and
`checkGameOver` decides, which puts every branch back on Taksu where the design
says it belongs.

**And Freeze is locked out for the first 10 seconds** (`RunRules.freezeLockout`).
The first interrupt can arrive at 4 seconds; without the lockout a player could
meet the hardest move in the game, and lose a fifth of the meter to it, before
finding the walking rhythm the rest of the loop is built on.

None of this is settled — it is reasoning about numbers, not playtesting. The
knobs are all in `RunRules`.

## Play session

`GameplayViewModel` owns one phase machine spanning the whole session:

| Phase | What happens |
|---|---|
| `tutorial` | Sketchbook page explaining where to put the iPad and where to stand. |
| `preparing` | Camera permission and capture session start up. |
| `calibrating` | The whole body has to stay inside the frame for 3 seconds. |
| `starting` | Green room: track name and a 3-second countdown. |
| `playing` | `RunEngine` and `MotionTracker` are stepped once per camera frame. |
| `paused` | Resume goes back through calibration so the player has time to get set. |
| `gameOver` | Final score, saved to Score History, with Play Again and Menu. |
| `unavailable` | No camera, or permission refused. |

Losing the body for two seconds during play drops back to `calibrating` rather
than quietly draining Taksu for something the player could not have scored.

## Body tracking

`CameraBodyPoseService` runs `VNDetectHumanBodyPoseRequest` on the front camera.
Frames are analysed and dropped — nothing is recorded or stored. `MotionTracker`
is the only place the joint data and the game rules meet.

Nothing is compared in raw camera coordinates. A body is first converted to
**body space** by `BodyFrame`: the origin is the hip centre and one unit is the
length of the torso. That makes every threshold independent of how far the
player stands from the camera, where they stand, and how tall they are.

- **Ngayog** — `NgayogDetector` measures how far the nose sits to one side of the
  shoulder centre. A cycle counts once both extremes have been visited, with a
  neutral band in the middle so a head parked on the boundary cannot rattle off
  cycles.
- **Nge'ed** — `SquatDetector` compares hip height against a slowly-adapting
  standing baseline. The baseline never follows the player downwards, so a slow
  recovery cannot be learned as the new normal.
- **Agem** — `PoseEvaluator` checks nine points (neck, wrists, elbows, knees,
  ankles) two ways: **targets**, where each point should sit with a tolerance in
  torso lengths, and **rules**, angles the body has to make. Positions alone are
  too weak — a player can hit both wrist targets with bent elbows.

### Adding or retuning a pose

Edit `Nari/Resources/Poses/poses.json` — no code change needed. The comments on
`PoseTarget` and `PoseRule` explain every field.

**The numbers in there are estimates and have not been tuned on a real body.**
To record real ones, run with `-debugPrintPose`, stand in the pose, and copy the
target lines printed to the console once per second:

```bash
xcrun simctl launch booted com.yuknari.Nari -debugPrintPose
```

The simulator has no camera, so `AppServices.makeBodyPoseSource()` hands back
`SimulatedBodyPoseSource` there: a fake dancer that tilts, squats, and drops into
agem kanan on three loops of different lengths. Because those loops drift against
the interrupt timer, a simulator run hits successes and failures on its own — but
pose tuning still needs a real iPad.

## Localisation

Strings live in `Localizer` as Swift dictionaries keyed by `LocalizedKey`, not in
`.lproj` bundles. The player can switch between Bahasa Indonesia and English in
the settings popup, and a dictionary lookup re-renders SwiftUI immediately, while
bundle localisation would only pick up the new language on relaunch.

To add a string: add a case to `LocalizedKey`, then add it to both tables in
`Localizer`. A missing translation is a compile error.

## Dropping in artwork

Image sets are wired up and empty. Add the PNGs in Xcode and the placeholders
disappear on their own — no code change needed.

| Image set         | Used by                | Placeholder while empty                |
|-------------------|------------------------|----------------------------------------|
| `Dancer`          | `DancerView`           | SF Symbol silhouette in a dashed frame |
| `GameTitle`       | `GameTitleView`        | Type-set "Yuk, Nari!" logo             |
| `TutorialStep1-3` | `TutorialSketchView`   | Pencil drawing rendered in code        |
| `PoseAgemKanan`   | `PoseCueCard`          | SF Symbol                              |
| `PoseAgemKiri`    | `PoseCueCard`          | SF Symbol                              |
| `PoseNgayog`      | `PoseCueCard`          | SF Symbol                              |

### Fonts

The Figma uses **Henny Penny** for display type and **Instrument Serif** for
buttons. Neither ships with iOS. `Theme.Fonts` looks for `HennyPenny-Regular` and
`InstrumentSerif-Regular` and falls back to the system serif when they are not in
the bundle, so the app runs either way. To use the real thing, add the `.ttf`
files to the target and list them under `UIAppFonts` in the Info plist.

### Painted surfaces

There are no texture images. `PaintedShapes.swift` draws them: `PaintTexture` for
the painted grounds, `TornEdgeShape` for the paper the meter and cue cards are
printed on, and `BrushSwatchShape` for the score, timer, and Game Over marks.
Each shape is seeded from a fixed number so its silhouette never changes between
redraws — an unseeded shape would boil.

## To do

- Real credits: replace the placeholder names in `StaticCreditsRepository`.
- Audio: `SilentAudioService` only remembers the volume levels. Swap in an
  `AVAudioPlayer`-backed implementation and add the gamelan loop plus the effect
  files listed in `SoundEffect`, which covers every cue in the GDD's sound list.
  The Freeze cue is meant to *cut* the music, not layer over it.
- Tune `poses.json` on a real iPad with `-debugPrintPose`.
- Accessibility: adjustable reaction windows (`RunRules` already isolates them);
  a reduce-flashing toggle for the Freeze frame.
- A skippable Training Stage teaching the five poses before the timed loop.
- (Stretch) GameKit leaderboard as a second tab beside Score History.

### About Foundation Models

The on-device Foundation Models framework is not used, on purpose. It needs
iOS 26, which would cut off every older iPad, and pose checking is geometry
rather than language — angles and distances, which Vision already provides.
Where it would earn its place later is coaching text: turning "left wrist is
20 cm low, shoulders tilted" into a sentence a child wants to read, in either
language. That can be added without touching the detection code, because
`PoseEvaluation` already carries which points failed and why.

## Debug launch arguments

Only compiled in `DEBUG`. Useful for grabbing screenshots without tapping:

```bash
xcrun simctl launch booted com.yuknari.Nari -debugPopup credits
xcrun simctl launch booted com.yuknari.Nari -debugAutoStart
xcrun simctl launch booted com.yuknari.Nari -debugPrintPose
```

`-debugPopup` accepts `settings`, `credits`, or `scores`. `-debugAutoStart` takes
no value and walks itself from the menu through the tutorial into a live session.
`-debugPrintPose` logs the player's joints in pose-definition coordinates once a
second.
