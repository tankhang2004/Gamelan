**GAME DESIGN ONE-PAGER**

# **Agem: A Game**

*Working title*

# **1\. The Pitch**

An AR-powered kinetic dance game driven by the movements of traditional Balinese choreography.

# **2\. Core Loop**

Every branch in the game, no matter what happens, funnels through the same question before deciding what happens next: is the player's Energy still above 0%? That single check is what turns four separate flows into one continuous loop.

**Default state —** the player walks while tilting their head left and right in a steady rhythm (Ngayog). Each full left-right tilt cycle adds \+5 points and \+2% energy. Nothing interrupts this on its own, so it repeats until a cue fires.

**Squat interrupt —** at a random moment (never at the same time as a Freeze cue — see Mechanics for why), the game asks the player to squat (Nge'ed) within 1 second. Responding in time adds \+5 points and \+5% energy. Missing it costs \-8% energy. Either way, the game returns to Ngayog.

**Freeze interrupt —** at a random moment, the game asks the player to match a held pose (Agem Kanan or Agem Kiri) within a 3-second grace period. Failing to match it in time costs \-20% energy and the round ends immediately. Matching it in time starts a 7-second hold: holding the full duration adds up to \+21% energy (+3% per second) plus scaling points; breaking the pose early stops the gain with no energy penalty. Either way, the game returns to Ngayog.

**The wrapper —** after any interrupt resolves, the game checks Energy. Above 0%, it loops back to Ngayog. At 0%, the run ends.

# **3\. Mechanics**

* **Taksu (Energy) Meter —** starts at 50%, capped at 100%, floor at 0%. The only stat that can end a run.

* **Score —** starts at 0, uncapped, only ever increases.

* **Ngayog (walking) —** the default, always-active movement. The player's head tilts left and right in a steady rhythm as they walk. Each full left-right tilt cycle adds \+5 points and \+2% energy.

* **Nge'ed (squat) —** a cued interrupt. The game randomly prompts a squat, and the player has 2 seconds to respond. Squatting in time adds \+5 points and \+5% energy. Missing the window costs \-8% energy and no points.

* **Agem Kanan / Agem Kiri (freeze pose) —** a cued interrupt. The game randomly selects one of two mirrored held poses and checks 9 tracked body points (2 wrists, 2 elbows, neck, 2 knees, 2 ankles) against it.

* **Freeze structure —** the player has 3 seconds (the “grace period”) to align all 9 points into the chosen pose.

  * Fail to align all 9 points within 3 seconds: \-20% energy, no points, round ends immediately.

  * Align all 9 points in time: the player then holds the pose for 7 more seconds. While holding, energy increases by \+3% per second, and points drip in at 20 × (current Energy % ÷ 100\) per second — a fuller Energy Meter earns more points per second, similar to a combo multiplier.

  * Hold the full 7 seconds: banks all of that energy and score.

  * Break the pose early: no energy penalty, but the energy gain and point drip stop immediately, and whatever was earned up to that point stays.

* **Single interrupt scheduler —** Squat and Freeze are never two separate timers; there is exactly one shared timer, so the two cues can never fire at the same time. When the shared timer fires, the game picks between the two, starting at an 85% / 15% split in Squat's favor.

* **Difficulty ramp (time-based) —** every 45 seconds the player survives, two things get tighter: the shared timer's interval shrinks by 10% (starting range 4–9 seconds, down to a floor of 2–5 seconds), and the odds of picking Freeze increase by 5 percentage points (up to a cap of 40%). The longer a run lasts, the faster and scarier it gets.

**Scoring System Summary**

| Event | Trigger / Condition | Energy Change | Score Change |
| ----- | ----- | ----- | ----- |
| Ngayog tilt cycle | Passive, full left-right head tilt while walking | \+2% | \+5 pts |
| Squat success | Squat cue hit within 2 seconds | \+5% | \+5 pts |
| Squat miss | Squat cue not hit within 1 second | \-8% | — |
| Agem — never got in | Fail to align all 9 points within 3s grace period | \-20% | — (round ends immediately) |
| Agem — held full duration | All 9 points aligned in time, then held 7s without breaking | \+21% (+3%/sec × 7s) | \+20/sec × (Energy% ÷ 100), for 7 seconds |
| Freeze — broke pose early | Got into pose, then broke it before 7s was up | No change | Drip stops; points earned so far are kept |
| Energy hits 0% | Any point Energy drops to or below 0% | — | Game Over, run ends |

# **4\. Player Experience**

Each core system exists to make a specific moment feel better — here's what each one is doing for the player, and what the game would feel like without it.

**Taksu (Energy) Meter —** keeps up momentum. It makes every second of the run feel active, instead of static — even walking (Ngayog) is quietly building toward something, so there's never a moment the player feels like they're doing nothing.

**Infinite loop —** gives the game replayability. Each run feels like a personal-record attempt, instead of a fixed, one-time experience — there's always a reason to play again and try to beat a previous score.

**Score, scaled by Energy —** gives satisfaction and something to chase. A skilled player isn't just avoiding failure — keeping Energy high actively pays out in points, instead of Energy being only a survival requirement.

**Freeze interrupt —** keeps the moment-to-moment feel unpredictable. It makes the walking rhythm feel alive, instead of a scripted button-matching test — the player can never fully relax into autopilot.

# **5\. Win / Lose / Progression**

There is no win state — the game is an infinite loop and the player is chasing a high score, not a finish line.

Lose condition: the Taksu (Energy) Meter reaches 0%, which ends the run immediately.

Progression is entirely score-based. Score History is a required screen for the MVP, accessible directly from the main menu, showing the player's past scores with their highest score highlighted. An online Leaderboard (built with Apple's GameKit, letting players compare scores with friends) is a nice-to-have — it should only be attempted once the core game is finished with time to spare. Score History should be built first regardless, since it works entirely on its own and needs no internet connection or GameKit setup.

A separate, skippable Training Stage teaches the five core poses (Standing Posture, Ngayog, Nge'ed, Agem Kanan, Agem Kiri) before the player enters the timed loop, so a new player's first “progression” is graduating from that untimed tutorial into the real game.

# **6\. Games With Similar Mechanics.**

| Game | What we're pulling from it |
| :---- | :---- |
| Just Dance | Cued, on-screen prompts telling the player exactly which move to perform next, and scoring that rewards matching the cue rather than freeform movement. |
| Dance Dance Revolution | Timing windows and grace periods — rewarding a move that lands close to the cue rather than only a frame-perfect match. |
| Kinect Sports / Wii Sports | Camera-based pose validation against a target skeleton, and forgiving detection tuned for approachability over precision. |

# **7\. The Why, In One Place**

This game exists to introduce people to the fun and physical challenge of Balinese dance. The core loop is built so that learning the choreography feels like play, not instruction.

# **8\. Sound Design — SFX Cue List**

Moments in the loop that need their own sound effect, separate from the background music track:

| Moment | Suggested sound direction |
| :---- | :---- |
| Squat cue appears | A short, distinct alert (e.g. a woodblock hit) that stands apart from the music track so it can't be missed. |
| Squat completed successfully | A light, positive chime. |
| Squat missed | A soft "miss" sound — not harsh, since this failure is meant to feel minor. |
| Freeze cue triggers (music cuts) | A distinct sting or gong hit marking the exact moment of silence, so the player registers “Freeze started” instantly. |
| 3-second grace period counting down | Optional: a subtle rhythmic tick or pulse so players feel the countdown without staring at a timer. |
| All 9 pose points matched | A confirming chime when the pose locks in and the 7-second hold begins. |
| Freeze held the full 7 seconds | A bigger, triumphant success sound, distinct from the smaller Squat-success chime. |
| Pose broken during the hold | A neutral tone — not punishing, since there's no Taksu (Energy) penalty for this outcome. |
| Freeze failed entirely (never matched in time) | A clear, low "failure" tone. |
| Taksu (Energy) running low (e.g. under 20%) | A subtle, repeating warning pulse so players notice danger without watching the meter. |
| Taksu (Energy) hits 0% / Game Over | A distinct game-over stinger, different from every other sound in the game. |
| Menu navigation / button taps | One consistent, light UI click used across every menu. |
| Calibration complete | A short confirmation sound once the floor/AR tracking is successfully set up. |

# **9\. Accessibility Features**

* **Freeze cue has a visual signal, not just audio.** When the music cuts for a Freeze, a clear on-screen graphic (a flash, icon, or banner) should appear at the same moment, so players who are hard of hearing or in a noisy room aren't relying on silence alone.

* **Tracking circles show progress without relying on color alone.** When a player hits one of the 9 tracked points (or the squat threshold), the circle should change shape or icon — for example an empty ring becoming a filled checkmark — in addition to changing color, so colorblind players can tell hit from unhit.

* **Separate SFX and Music volume sliders.** Already planned in Settings — keep them as two independent sliders, not one combined volume, so players relying on SFX cues can keep them audible even with music turned down.

* **High-contrast, readable HUD text.** State prompts (WALK, SQUAT, FREEZE) and the score should stay clearly readable against any camera background — use a solid text outline or backing shape rather than relying on the live camera feed underneath for contrast.

* **Numeric Energy readout next to the meter bar.** Showing the Energy percentage as a number, not just a colored bar, helps players who have difficulty judging bar length or color alone.

* **Adjustable reaction windows (stretch goal).** Consider an accessibility setting that slightly lengthens the Squat's 1-second window and the Freeze's 3-second grace period for players who need more time to react physically, without changing the scoring numbers themselves.

* **Avoid uncomfortable flashing.** If any fail/Game Over effect includes a screen flash, keep it brief and low-contrast, or provide a “reduce flashing” toggle — AR games sit close to the face, so screen flicker can be uncomfortable.

# **10\. Screens & Components Checklist**

Everything that needs to be designed, organized by where it appears.

**Main Menu**

* Main Menu screen — Play, Settings, Credit, Score History

**Play Flow**

* “Place your device on the floor” instruction screen

* Motion tracking calibration screen, with a visual guide showing the player where to stand

* Training Stage screens — one per pose (Standing Posture, Ngayog, Nge'ed, Agem Kanan, Agem Kiri), using a split-view layout: live camera on one side, reference pose on the other, instruction text below, plus a visible “Skip Training” button

* Green Room screen — track name & “GAME START” over a live camera preview, with a timer leading to game starting

* Gameplay HUD — Energy Meter (left), Score (top right), state prompt like WALK / SQUAT / FREEZE (top center), reference pose thumbnail (bottom right), AR tracking overlay in the center

* Freeze visual cue overlay — the graphic that appears the instant a Freeze starts (see Section 10\)

* Game Over screen — blurred camera background, final score, Retry and Main Menu buttons

**Settings**

* Settings screen — SFX volume slider, Music volume slider, Accessibility toggles grouped together here

**Credit**

* Credit screen — text crediting Mekar Bhuana with a tappable link (opens in Safari)

**Score History / Leaderboard**

* Score History screen — list of past scores, highest score visually highlighted

* Leaderboard screen (nice-to-have) — only design this if MVP time allows; if designed, structure it as a second tab next to Score History rather than a separate menu button

**Shared Components (used across multiple screens)**

* Tracking circle component — needs a “not yet hit” state and a “hit” state that differ in shape/icon, not just color

* Reference pose thumbnail set — one image per pose, used in both Training and the Gameplay HUD

* Energy Meter component — bar plus a numeric percentage readout

* Low-energy warning treatment — the visual state the Energy Meter switches to when running low

# **11\. Build Notes for the Dev Team**

This section explains how the systems above map onto actual code, written for the whole team — not just the strongest programmer. Treat this as a checklist of what needs to exist, not a demand to understand every term immediately.

* **The whole game is one state machine.** Think of the app as always being in exactly one “mode” at a time: Main Menu, Calibration, Training, Green Room, Playing (itself either Walking, Squat Cue, or Freeze), or Game Over. In Swift, the cleanest way to represent this is a single enum (a fixed list of named options) stored in one shared variable. Every button tap, timer, or successful/failed move just changes this one variable, and SwiftUI automatically shows whichever screen matches. Get this right first — everything else attaches to it.

* **Timers drive the interrupts.** The Squat/Freeze scheduler (Section 3\) needs one repeating timer that “rolls the dice” each time it fires — deciding whether to trigger Squat or Freeze, then picking a new random wait time for the next fire. Because it's one timer, not two, the “never fire at the same time” rule is automatic — there's nothing extra to code for that.

* **Energy and Score are just two shared numbers.** Both can be simple variables any part of the game can read and change. The important rule to enforce in code is the cap: after every change, check if Energy is above 100 and clamp it back down, or at/below 0 and trigger Game Over.

* **Vision framework gives you body positions; your code decides what they mean.** Apple's Vision framework hands the app the on-screen position of each tracked body joint, every frame, once the camera is running. The “did they squat” or “did they hit the pose” logic is just comparing those positions against thresholds or against each other (for example, “is the hip's height below this line,” or “is this wrist close enough to this target point”). This is usually the fiddliest part to get right, so budget extra time to test it against real people moving, not just diagrams.

* **Sound and visual cues are separate from game logic.** Every SFX and accessibility visual from Sections 9 and 10 should be triggered by the state machine, not written into the tracking code itself. That keeps sound and visual design changeable later without touching gameplay logic at all.

* **Suggested build order.** Get the state machine and the Energy/Score numbers working first, using simple button presses to fake Squat/Freeze results — before Vision tracking is hooked up at all. This lets the team test the whole loop's feel (pacing, numbers, difficulty ramp) without the camera tracking being finished, and lets game-logic work and body-tracking work happen in parallel.

### **Dev Notes — Actionable Checklist**

| \# | Task | What "done" looks like |
| ----- | ----- | ----- |
| 1 | Build the central state machine | A single `enum` (Main Menu, Calibration, Training, Green Room, Walking, Squat Cue, Freeze, Game Over) stored in one shared variable, with SwiftUI switching screens based on its value |
| 2 | Build the shared interrupt timer | One repeating timer that, on each fire, randomly picks Squat or Freeze (starting 85%/15%) and schedules its own next fire (starting 4–9s range) |
| 3 | Wire up the difficulty ramp | Every 45 seconds survived: shrink the timer's interval range by 10% (floor 2–5s) and raise the Freeze pick-odds by 5 points (cap 40%) |
| 4 | Build Energy and Score as shared state | Two variables any system can read/modify, with a clamp check after every change (Energy capped 0–100%, trigger Game Over at 0%) |
| 5 | Fake the gameplay loop with buttons first | Before Vision tracking exists, wire dummy "Squat Success / Squat Fail / Freeze Success / Freeze Fail" buttons to the state machine so pacing and numbers can be tested early |
| 6 | Implement Vision tracking for Squat | Compare hip Y-position against a threshold line, within the 1-second window |
| 7 | Implement Vision tracking for Freeze | Track 9 joints (wrists, elbows, neck, knees, ankles) against target positions for Agem Kanan/Kiri; validate within the 3-second grace period, then hold for 7s |
| 8 | Hook up SFX triggers | Attach each sound in the SFX list to its matching state-machine transition, not to the tracking code directly |
| 9 | Hook up accessibility visuals | Freeze pop-up graphic on Freeze state entry; tracking circle shape/icon change (not color-only) on hit |
| 10 | Build Score History storage | Local persistence of past run scores, with the highest score flagged for display |
| 11 | (Stretch) GameKit Leaderboard | Only after 1–10 are functional and there's spare MVP time |

