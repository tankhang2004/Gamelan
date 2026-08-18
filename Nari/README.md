# Yuk, Nari!

A motion-tracking game for young Balinese dancers, built to complement studio
practice with body-awareness and strength exercises drawn from the basic
postures — agem, mendak, ngegol.

iPad only, landscape only. Deployment target iOS 17.

This repository contains the main menu and the first playable pose loop: a
placement tutorial, a camera calibration hold, and agem detection with Vision's
human body pose request.

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
    Models/                GameSettings, AppLanguage, MainMenuItem, GameMode,
                           CurtainPhase, CreditSection
    Services/              SettingsStore, SettingsService, AudioService,
                           CreditsRepository, PoseRepository
    Localization/          LocalizedKey, Localizer, environment plumbing
    Vision/                Camera capture and Vision body pose detection
    Poses/                 Pose definitions and the scoring rules
  DesignSystem/
    Theme.swift            Palette, metrics, motion timings, type styles
    Components/            PlaqueButtonStyle, PopupCard
  Features/
    MainMenu/              MainMenuViewModel + stage views
    Settings/              SettingsViewModel + popup
    Credits/               CreditsViewModel + popup
    Gameplay/              GameplayViewModel + empty screen
  Resources/
    Assets.xcassets
```

### Menu flow

`MainMenuViewModel` runs the whole choreography:

1. On appear the curtains start swung aside and fall shut, then the logo,
   dancer, and plaques fade in.
2. Tapping PLAY fades the menu out, swings the curtains open, and only then
   asks `AppRouter` to put `GameplayView` on stage. The gameplay screen uses
   the same `StageBackdropView` as the menu, so the swap is invisible.
3. SETTINGS and CREDITS open popups over the menu; the curtains stay shut.

### Play session

`GameplayViewModel` owns one phase machine:

| Phase | What happens |
|---|---|
| `tutorial` | Sketchbook page, one drawing per second, explaining where to put the iPad and where to stand. START moves on. |
| `preparing` | Camera permission and capture session start up. |
| `calibrating` | The whole body has to stay inside the frame for 3 seconds. The green bar around the screen fills while it does and drains when the player steps out. |
| `playing` | Five markers track the player. Holding the pose for `holdSeconds` counts as one rep. |
| `paused` | Resume goes back through calibration so the player has time to get set again. |
| `unavailable` | No camera, or permission refused. |

Losing the body for two seconds during play drops back to `calibrating`
rather than freezing the markers on screen.

### Pose detection

`CameraBodyPoseService` runs `VNDetectHumanBodyPoseRequest` on the front
camera. Frames are analysed and dropped — nothing is recorded or stored.

Poses are not compared in raw camera coordinates. A body is first converted to
**body space** by `BodyFrame`: the origin is the hip centre and one unit is the
length of the torso. That makes a pose definition independent of how far the
player stands from the camera, where they stand, and how tall they are.
Comparing raw coordinates would only match a player standing in exactly the
same spot as whoever recorded the pose.

Each pose is checked two ways, because either alone is too weak:

- **Targets** — where each of the five tracked points should sit, with a
  tolerance in torso lengths. These drive the coloured markers.
- **Rules** — angles the body has to make. Agem needs the arms to form one
  straight horizontal line, and a player can hit both wrist targets with bent
  elbows, so `lineAngle` and `jointAngle` rules catch what positions cannot.
  Each rule lists which markers turn red when it is broken.

### Adding a pose

Edit `Nari/Resources/Poses/poses.json` — no code change needed. The comments on
`PoseTarget` and `PoseRule` explain every field.

To record the numbers instead of guessing them, run with `-debugPrintPose`,
stand in the pose, and copy the target lines printed to the console once per
second:

```bash
xcrun simctl launch booted com.yuknari.Nari -debugPrintPose
```

The simulator has no camera, so `AppServices.makeBodyPoseSource()` hands back
`SimulatedBodyPoseSource` there: a fake dancer that stands still, then raises
its arms into agem. It exists so the whole flow can be exercised without a
device — pose tuning still needs a real iPad.

### Localisation

Strings live in `Localizer` as Swift dictionaries keyed by `LocalizedKey`, not
in `.lproj` bundles. The player can switch between Bahasa Indonesia and English
in the settings popup, and a dictionary lookup re-renders SwiftUI immediately,
while bundle localisation would only pick up the new language on relaunch.

To add a string: add a case to `LocalizedKey`, then add it to both tables in
`Localizer`. A missing translation is a compile error.

## Dropping in artwork

Two image sets are already wired up and empty. Add the PNGs in Xcode and the
placeholders disappear on their own — no code change needed.

| Image set         | Used by                | Placeholder while empty                |
|-------------------|------------------------|----------------------------------------|
| `Dancer`          | `DancerView`           | SF Symbol silhouette in a dashed frame |
| `GameTitle`       | `GameTitleView`        | Styled "Yuk, Nari!" text logo          |
| `TutorialStep1-3` | `TutorialSketchView`   | Pencil drawing rendered in code        |
| `PoseAgem`        | `PoseInstructionPanel` | SF Symbol in a dashed frame            |

Both views check `UIImage(named:)` at render time and prefer the artwork when it
is present.

## To do

- Real credits: replace the placeholder names in `StaticCreditsRepository`.
- Audio: `SilentAudioService` only remembers the volume levels. Swap in an
  `AVAudioPlayer`-backed implementation and add the gamelan loop plus the effect
  files listed in `SoundEffect`.
- Tune the agem numbers on a real iPad with `-debugPrintPose`; the values in
  `poses.json` are estimates.
- More poses: mendak and ngegol, then a sequence rather than one pose on repeat.
- Scoring and session results.

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

`-debugPopup` accepts `settings` or `credits`. `-debugAutoStart` takes no value
and walks itself from the menu through the curtain transition and the tutorial
into a live session. `-debugPrintPose` logs the player's joints in
pose-definition coordinates once a second.
