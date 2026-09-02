# StarterPlan

A gamified 4-week workout tracker for iOS — Duolingo-style progression path, dark mode, streaks, XP and confetti.

Built with SwiftUI + SwiftData. No backend, no login, no third-party dependencies.

---

## What's in it

**Your plan is generated, not fixed.** Six short questions — goal, days per week, session length, equipment you can reach, muscles you want prioritised, anything you need to work around — and the app builds four weeks out of a tagged movement library. Change your mind any time in Settings; finished days are kept.

Every movement in the library carries its primary and secondary muscles, its movement pattern, the equipment it needs, the joints it loads and how demanding it is. The generator picks a split for your days per week, fills each session's pattern slots with movements you can actually do, weights the picks toward what you said you cared about, applies your goal's sets and reps, and varies the choices week to week so week 3 doesn't read like week 1.

**Features**

- Winding path of day nodes joined by curved connectors — future days locked, current day pulses, completed days get a checkmark badge
- Streak, XP and coin counters plus a weekly progress ring in the top bar
- A mood check and three real sessions to choose between, every single day
- Body maps showing what a movement works, what a session covers, and where your week's volume actually landed
- A coach that picks your weights instead of asking you to guess (see below)
- Linear session flow: set → rate the effort → rest → next set
- Rest counts down, alarms at zero, then keeps counting your overtime — a long breather is logged, not punished
- Mini-games during rest that hard-lock the second the timer runs out
- Full-screen "Lesson Complete" celebration with confetti, XP count-up and what the coach changed
- Plain-English how-to + form cue for every exercise via the info button
- Four reminders a day that stop the moment the day's session is done
- History calendar with completed days highlighted, plus per-set weight, effort and rest logs
- Settings: your plan, your details, rest arcade, notification and sound toggles, weight overrides, reset plan

---

## Which workout, not whether

Tapping today never asks "do you want to work out". It asks how you're feeling — Fresh, Normal, Low energy, Sore, No time — and then offers three real sessions shaped by that answer:

| Mood | What you're offered |
|---|---|
| Fresh | The plan, a bigger version with a conditioning finisher, a lighter option |
| Normal | The plan, a trimmed version, easy cardio instead |
| Low energy | The trimmed version first, easy cardio, the full plan |
| Sore | Mobility to move it out, the trimmed version, the full plan |
| No time | A two-movement express session, a twelve-minute burner, the full plan |

All three complete the day. There's no penalty for picking the small one, because a short session you actually do beats a perfect one you skip.

**Rest days work the same way.** Take the rest, or pick easy movers or a walk — both log as genuine sessions without costing you tomorrow.

**And you can always do more.** The "something extra" card sits on the home screen every day, including after the day's session is done. Tap the muscles you feel like working, pick 15, 25 or 40 minutes, and the app builds a session around them. Extras earn full credit and never move the plan, so wanting to train more is rewarded while cramming a week into one afternoon still isn't.

---

## Body maps

A front-and-back figure with every muscle group drawn separately, used in three places:

- **Exercise info** — what this movement mainly works, and what it also hits
- **Session cards** — a thumbnail of everything a session covers, so you can see at a glance whether it's a leg day
- **History** — a heat map of the last seven days' volume, which calls out what you've been quietly neglecting

It's also the input control: you pick your focus muscles by tapping the body, both in setup and when building an extra session.

---

## The schedule slides

The plan is a queue, not a fixed calendar. Whatever comes next is always dated **today**, and everything behind it sits one day per day after that. Nodes on the path show when they're due — Today, Tomorrow, a weekday — and completed ones show the date you actually did them.

Miss a day and nothing is lost or skipped: Tuesday's session simply becomes Wednesday's, and the rest of the plan shifts with it.

Working ahead is allowed but deliberately unrewarding. Once today's session is logged, later days unlock as **bonus sessions**: half XP, half coins, and the plan does *not* advance — that day is still owed on its own date. You get a confirmation before starting one, a banner during it, and a note on the finish screen. So you can't bank a week on Monday and coast.

Your streak counts any day you did work, bonus sessions included.

---

## Reminders

Four nudges a day at 10:30, 12:30, 15:30 and 19:30, each with sound, each naming the session that's waiting. The moment you log the day's session the rest of that day's nudges are cancelled — it never pesters you about something you've already done. The schedule is rebuilt on launch, whenever the app comes to the foreground, and on completion, so a missed day self-corrects.

---

## Every activity gets its own screen

Nothing in the plan is a generic checkbox list. Each exercise declares how it's actually performed, and the app opens the screen built for it.

**Trail cardio and the optional trail** run on live GPS. You get a route line on the map, distance, average and current pace, and a bar per elapsed minute so you can see exactly where you slowed. Drop below a walking pace and it chirps at you; flatline for eight seconds and it auto-pauses until you resume, with the stopped time logged separately. Location is entirely optional — "Just time me" gives you a clean stopwatch, and you can switch tracking on part way through a run without losing the clock.

The coach then reads the run, not just your rating:

| What the data shows | What happens to your next target |
|---|---|
| Bailed early, pace collapsed first | Target cut to around what you managed, then rebuilt |
| Bailed early, pace steady to the end | Trimmed 5 minutes — your legs weren't the limit |
| Went long, pace held or improved | Window moves up 5 minutes |
| Went long but faded badly | Window holds — fix the pacing first |
| In the window and it felt easy | Window moves up |

**Planks and hollow holds** get a start/pause stopwatch with a marker chime at the target. That clock is for you to watch, nothing else — the next hold target moves on how the hold felt, never on the seconds shown.

**Friday conditioning** has three different engines. AMRAP gives you a giant round-tapper, live per-round splits, an average round time and your personal best to chase, with a one-minute warning. The five-round day enforces its own rest between rounds. The for-time day is a stopwatch with round splits that colour-code when a round is slower than the one before, plus your best time to beat.

**Bodyweight rep work** (ring rows, pull-ups) gets a rep tally so a set of 7 out of 8 is logged as 7, not as a failure.

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
