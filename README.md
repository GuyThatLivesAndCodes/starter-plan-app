# StarterPlan

A gamified 4-week workout tracker for iOS — Duolingo-style progression path, dark mode, streaks, XP and confetti.

Built with SwiftUI + SwiftData. No backend, no login, no third-party dependencies.

---

## What's in it

**The plan** — 4 weeks × 7 days, hardcoded:

| Day | Session |
|-----|---------|
| Mon | Strength A — Back Squat, Bench Press, Ring Rows, DB Shoulder Press, Plank |
| Tue | Trail Cardio |
| Wed | Rest |
| Thu | Strength B — Romanian Deadlift, Banded/Jumping Pull-ups, DB Rows, Walking Lunges, Hollow Hold |
| Fri | Conditioning (rotates each week) |
| Sat | Optional Trail |
| Sun | Rest |

Friday conditioning rotation: Wk1 Scaled Cindy 12-min AMRAP · Wk2 5 rounds (goblet squats / push-ups / plank) · Wk3 Scaled Cindy 15-min · Wk4 3 rounds for time (squats / push-ups / 400m).

**Features**

- Winding path of day nodes joined by curved connectors — future days locked, current day pulses, completed days get a checkmark badge
- Streak, XP and coin counters plus a weekly progress ring in the top bar
- A coach that picks your weights instead of asking you to guess (see below)
- Linear session flow: set → rate the effort → rest → next set
- Rest counts down, alarms at zero, then keeps counting your overtime — a long breather is logged, not punished
- Mini-games during rest that hard-lock the second the timer runs out
- Full-screen "Lesson Complete" celebration with confetti, XP count-up and what the coach changed
- Plain-English how-to + form cue for every exercise via the info button
- Daily reminder (9:00) and streak-at-risk warning (19:30) local notifications
- History calendar with completed days highlighted, plus per-set weight, effort and rest logs
- Settings: your details, rest arcade, notification and sound toggles, weight overrides, reset plan

---

## The coach

On first launch the app asks for age, height, body weight, sex (used only to scale starting loads) and lifting experience. From that it estimates a starting weight for every barbell and dumbbell lift, deliberately on the light side.

After that it stops guessing and starts reading. Every set you log carries three things: the weight you actually used, how it felt (Easy / Just right / Hard / Couldn't finish) and how long you actually rested. Those drive the next suggestion:

| What happened last session | What the coach does |
|---|---|
| You couldn't finish a set | Drops two increments |
| Sets graded hard, or you stopped short | Drops one increment |
| You needed a lot of extra rest | Holds the weight until rest tightens up |
| Everything felt easy | Adds two increments |
| Two clean sessions in a row | Adds one increment |
| Solid but not easy | Holds — one more clean session earns the jump |

It also reacts mid-workout: an easy first set bumps the weight before set 2, a failed set takes weight off the next one. Change the weight yourself any time — the coach reads what you actually lifted, not what it asked for.

The home screen shows a 0–100 read on how you're tracking against the estimate for your body, and surfaces cautions only when they apply to you (age, BMI, first-timer, a long streak with no rest day). It is not medical advice, and it says so.

---

## Coins and the rest arcade

Sets pay coins, scaled by honest effort — a hard set pays more than an easy one, and sticking to the prescribed rest pays a bonus. Finishing a session pays a lump sum. XP works the same way, so a genuinely hard week outscores a coasting one.

Coins buy mini-games you can play during rest: **Tap Rush** is free, **Snake** costs 150, **Flap** costs 400. Every game locks itself the instant the rest timer hits zero, so the arcade can't turn a 90-second rest into a five-minute one.

---

## Requirements

- iOS 17.0 or later (SwiftData requires iOS 17 — the rest of the app is plain SwiftUI)
- Xcode 16 or later to build

Open `StarterPlan.xcodeproj` and run. That's it.

---

## Getting it on your iPhone with Sideloadly

Every push builds an **unsigned IPA** in GitHub Actions.

1. Go to the repo's **Actions** tab, open the most recent **Build StarterPlan IPA** run, and download the `StarterPlan-unsigned-ipa` artifact. Unzip it to get `StarterPlan.ipa`.
2. Install [Sideloadly](https://sideloadly.io) on your Mac or PC and plug in your iPhone (trust the computer when prompted).
3. Open Sideloadly. Drag `StarterPlan.ipa` onto the window.
4. Enter your Apple ID. A free account works — the app will need re-signing every 7 days. A paid developer account lasts a year.
5. Leave the bundle ID as-is (or set your own if you hit a conflict) and click **Start**. Enter your Apple ID password if asked; if you use 2FA, generate an [app-specific password](https://appleid.apple.com) and use that instead.
6. On the iPhone: **Settings → General → VPN & Device Management**, tap your Apple ID, and tap **Trust**.
7. Launch StarterPlan and allow notifications when it asks.

**If the install fails:** the most common cause is a bundle-ID collision with an existing app — change it in Sideloadly's Bundle ID field to something like `com.yourname.starterplan`. Free Apple accounts are also limited to 3 sideloaded apps at a time.

---

## Project layout

```
StarterPlan/
  StarterPlanApp.swift        app entry, root tabs
  Models/
    Plan.swift                the hardcoded 4-week plan + exercise explanations
    Store.swift               SwiftData models, streak/XP logic, progression rules
  Services/
    Theme.swift               dark palette, card + chunky button styles
    Feedback.swift            haptics + system sounds (mute-aware)
    Notifications.swift       daily reminder + streak-at-risk scheduling
  Views/
    HomeView.swift            the winding day path, top bar
    WorkoutView.swift         one-exercise-at-a-time flow
    ExerciseCard.swift        set checkboxes, weight stepper, info sheet
    RestTimerOverlay.swift    circular countdown
    CelebrationView.swift     lesson-complete screen + confetti
    HistoryView.swift         calendar, streak stats, day details
    SettingsView.swift        toggles, weight editor, reset
```
