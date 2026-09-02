import SwiftUI
import MapKit

/// Live trail session. Distance, pace, splits and a route line when location is
/// on; a clean stopwatch when it isn't — switchable at any moment.
struct TrailSessionView: View {
    let exercise: Exercise
    let targetLow: Int
    let targetHigh: Int
    let onFinish: (RunTracker) -> Void

    @State private var tracker = RunTracker()
    @State private var showMap = true
    @State private var started = false
    @State private var camera: MapCameraPosition = .userLocation(fallback: .automatic)
    @Environment(\.scenePhase) private var scenePhase

    private var targetSeconds: Int { targetLow * 60 }
    private var progress: Double { min(1, Double(tracker.elapsed) / Double(max(targetSeconds, 1))) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                if !started {
                    startCard
                } else {
                    clockCard
                    if tracker.locationEnabled {
                        statsGrid
                        if showMap { routeMap }
                        if !tracker.splits.isEmpty { splitBars }
                    } else {
                        noLocationCard
                    }
                    if tracker.locationEnabled && tracker.backgroundCapable {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.iphone").foregroundStyle(Theme.accent)
                            Text("Keeps tracking with the screen off — pocket it and go.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Theme.textDim)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.accent.opacity(0.10)))
                    }

                    stateBanner
                    controls
                }
                Color.clear.frame(height: 20)
            }
            .padding(20)
        }
        // Coming back from the lock screen or another app: recompute from wall
        // time rather than trusting anything a suspended timer did.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { tracker.sync() }
        }
    }

    // MARK: Start

    private var startCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(exercise.name)
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("Target: \(targetLow)–\(targetHigh) minutes at an easy, talkable pace.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("With location", systemImage: "location.fill")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                Text("Tracks distance, pace over time and where you slow down, auto-pauses when you stop, and lets the coach set your next target from what actually happened.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.accent.opacity(0.10)))

            Button("Start with location") {
                Feedback.shared.tap()
                tracker.start(withLocation: true)
                started = true
            }
            .buttonStyle(ChunkyButtonStyle())

            Button {
                Feedback.shared.tap()
                tracker.start(withLocation: false)
                started = true
            } label: {
                Text("Just time me")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Theme.surfaceHigh))
            }
            .buttonStyle(.plain)

            Text("You can turn location on part way through — the clock keeps running.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim.opacity(0.8))
        }
        .padding(20)
        .card(Theme.surface)
    }

    // MARK: Live

    private var clockCard: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().stroke(Theme.locked, lineWidth: 12).frame(width: 200, height: 200)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 200, height: 200)
                    .shadow(color: ringColor.opacity(0.4), radius: 12)
                    .animation(.linear(duration: 0.9), value: tracker.elapsed)
                VStack(spacing: 2) {
                    Text(RunTracker.clock(tracker.elapsed))
                        .font(.system(size: 44, weight: .black, design: .rounded))
                        .foregroundStyle(ringColor)
                        .contentTransition(.numericText())
                    Text(elapsedCaption)
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.textDim)
                }
            }
            .frame(height: 210)
        }
    }

    private var ringColor: Color {
        let m = Double(tracker.elapsed) / 60
        if m >= Double(targetHigh) { return Theme.gold }
        if m >= Double(targetLow) { return Theme.accent }
        return Theme.teal
    }

    private var elapsedCaption: String {
        let m = Double(tracker.elapsed) / 60
        if m >= Double(targetHigh) { return "past the window" }
        if m >= Double(targetLow) { return "in the window" }
        return "of \(targetLow) min minimum"
    }

    private var statsGrid: some View {
        HStack(spacing: 10) {
            stat("\(String(format: "%.2f", tracker.meters / 1609.34))", "MILES", Theme.accent)
            stat(RunTracker.paceString(tracker.paceSecondsPerMile), "AVG /MI", Theme.teal)
            stat(RunTracker.paceString(tracker.currentPaceSecondsPerMile), "NOW /MI", Theme.gold)
        }
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card(Theme.surface)
    }

    private var routeMap: some View {
        Map(position: $camera) {
            UserAnnotation()
            if tracker.coordinates.count > 1 {
                MapPolyline(coordinates: tracker.coordinates)
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: Theme.corner, style: .continuous))
        .overlay(alignment: .topTrailing) {
            Button {
                Feedback.shared.tap(); showMap = false
            } label: {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.text)
                    .padding(8)
                    .background(Circle().fill(Theme.surface.opacity(0.9)))
            }
            .buttonStyle(.plain)
            .padding(10)
        }
    }

    private var splitBars: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PACE BY MINUTE")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundStyle(Theme.textDim)
            HStack(alignment: .bottom, spacing: 3) {
                let peak = max(tracker.splits.max() ?? 1, 1)
                ForEach(Array(tracker.splits.enumerated()), id: \.offset) { _, m in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(m < peak * 0.6 ? Theme.gold : Theme.accent)
                        .frame(height: max(4, 60 * m / peak))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 62)
            Text("Shorter bars are the minutes you slowed down.")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim.opacity(0.8))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(Theme.surface)
    }

    private var noLocationCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "location.slash.fill").font(.system(size: 24)).foregroundStyle(Theme.textDim)
            Text(tracker.authDenied ? "Location is off for StarterPlan" : "Timing only")
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.text)
            Text(tracker.authDenied
                 ? "Enable it in iOS Settings if you want distance and pace. The clock keeps running either way."
                 : "No distance or pace this session. You can switch tracking on right now without losing the clock.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)

            Button("Turn location on") {
                Feedback.shared.tap()
                tracker.enableLocation()
            }
            .font(.system(size: 14, weight: .heavy, design: .rounded))
            .foregroundStyle(Color(hex: 0x10221A))
            .padding(.horizontal, 22).padding(.vertical, 11)
            .background(Capsule().fill(Theme.accent))
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .card(Theme.surface)
    }

    private var stateBanner: some View {
        Group {
            switch tracker.state {
            case .autoPaused:
                banner("Auto-paused — you stopped moving", "pause.circle.fill", Theme.gold,
                       "Tap resume when you're going again. The paused time is logged separately.")
            case .paused:
                banner("Paused", "pause.circle.fill", Theme.teal, "Take the breather. Nothing is lost.")
            default:
                if tracker.accuracyPoor && tracker.locationEnabled {
                    banner("Weak GPS signal", "antenna.radiowaves.left.and.right.slash", Theme.textDim,
                           "Distance may drift under tree cover. The clock is still exact.")
                }
            }
        }
    }

    private func banner(_ title: String, _ icon: String, _ color: Color, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 14, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                Text(detail).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(color.opacity(0.12)))
    }

    private var controls: some View {
        VStack(spacing: 10) {
            if tracker.state == .running {
                Button("Pause") { Feedback.shared.tap(); tracker.pause(auto: false) }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.surfaceHigh, textColor: Theme.text))
            } else {
                Button("Resume") { Feedback.shared.tap(); tracker.resume() }
                    .buttonStyle(ChunkyButtonStyle())
            }

            Button {
                Feedback.shared.celebrate()
                tracker.finish()
                onFinish(tracker)
            } label: {
                Text(Double(tracker.elapsed) / 60 < Double(targetLow) ? "End early" : "Finish session")
            }
            .buttonStyle(ChunkyButtonStyle(
                color: Double(tracker.elapsed) / 60 < Double(targetLow) ? Theme.flame : Theme.accent,
                textColor: Color(hex: 0x10221A)))

            if !tracker.locationEnabled && !tracker.authDenied && tracker.state != .idle {
                Button("Switch on tracking") { Feedback.shared.tap(); tracker.enableLocation() }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textDim)
                    .buttonStyle(.plain)
            }
        }
    }
}
