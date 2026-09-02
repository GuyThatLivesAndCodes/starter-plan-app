import CoreLocation
import Foundation
import Observation

/// Live trail tracking. Works with or without location — if the user says no
/// (or hasn't decided yet) it degrades to a plain stopwatch and can be upgraded
/// to full GPS mid-run without losing the clock.
@Observable
final class RunTracker: NSObject, CLLocationManagerDelegate {

    enum State { case idle, running, autoPaused, paused, finished }

    private(set) var state: State = .idle
    private(set) var elapsed = 0                 // seconds of moving time
    private(set) var pausedSeconds = 0
    private(set) var meters: Double = 0
    private(set) var autoPauses = 0
    private(set) var currentSpeed: Double = 0    // m/s, smoothed
    private(set) var splits: [Double] = []       // meters per elapsed minute
    private(set) var coordinates: [CLLocationCoordinate2D] = []
    private(set) var locationEnabled = false
    private(set) var authDenied = false
    private(set) var accuracyPoor = false

    var usedLocation: Bool { locationEnabled && meters > 0 }

    private let manager = CLLocationManager()
    private var timer: Timer?
    private var lastLocation: CLLocation?
    private var metersThisMinute: Double = 0
    private var slowSeconds = 0
    private var warnedSlow = false

    /// Below this (m/s) for a stretch and we call it stopped. ~0.6 m/s is a slow amble.
    private let stopThreshold: Double = 0.55
    private let autoPauseAfter = 8               // seconds under threshold

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .fitness
        manager.distanceFilter = 5
    }

    // MARK: Control

    func start(withLocation: Bool) {
        state = .running
        if withLocation { enableLocation() }
        startClock()
    }

    /// Can be called at any point mid-run.
    func enableLocation() {
        authDenied = false
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            authDenied = true
        default:
            beginUpdates()
        }
    }

    func disableLocation() {
        manager.stopUpdatingLocation()
        locationEnabled = false
    }

    func pause(auto: Bool) {
        guard state == .running else { return }
        state = auto ? .autoPaused : .paused
        if auto {
            autoPauses += 1
            Feedback.shared.timerDone()
        }
    }

    func resume() {
        guard state == .autoPaused || state == .paused else { return }
        state = .running
        slowSeconds = 0
        warnedSlow = false
    }

    func finish() {
        state = .finished
        timer?.invalidate(); timer = nil
        manager.stopUpdatingLocation()
        if metersThisMinute > 0 || !splits.isEmpty { splits.append(metersThisMinute) }
    }

    // MARK: Clock

    private func startClock() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        switch state {
        case .running:
            elapsed += 1
            if elapsed % 60 == 0 {
                splits.append(metersThisMinute)
                metersThisMinute = 0
            }
            if locationEnabled { watchForStopping() }
        case .autoPaused, .paused:
            pausedSeconds += 1
        default:
            break
        }
    }

    /// Two-stage: a nudge when the pace collapses, an auto-pause when it flatlines.
    private func watchForStopping() {
        if currentSpeed < stopThreshold {
            slowSeconds += 1
            if slowSeconds == 4 && !warnedSlow {
                warnedSlow = true
                Feedback.shared.denied()
            }
            if slowSeconds >= autoPauseAfter { pause(auto: true) }
        } else {
            slowSeconds = 0
            warnedSlow = false
        }
    }

    // MARK: CLLocationManagerDelegate

    private func beginUpdates() {
        locationEnabled = true
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ m: CLLocationManager) {
        switch m.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways: beginUpdates()
        case .denied, .restricted: authDenied = true; locationEnabled = false
        default: break
        }
    }

    func locationManager(_ m: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        for loc in locs {
            guard loc.horizontalAccuracy > 0 else { continue }
            accuracyPoor = loc.horizontalAccuracy > 35
            if accuracyPoor { continue }

            currentSpeed = max(0, loc.speed >= 0 ? loc.speed : currentSpeed)

            if let last = lastLocation, state == .running {
                let d = loc.distance(from: last)
                // Ignore GPS jitter and impossible jumps.
                if d > 1.5 && d < 90 {
                    meters += d
                    metersThisMinute += d
                    coordinates.append(loc.coordinate)
                }
            } else if state == .running {
                coordinates.append(loc.coordinate)
            }
            lastLocation = loc

            // A hard stop shows up as speed 0 straight away.
            if state == .running && loc.speed >= 0 && loc.speed < 0.2 {
                slowSeconds = max(slowSeconds, 3)
            }
        }
    }

    func locationManager(_ m: CLLocationManager, didFailWithError error: Error) {
        accuracyPoor = true
    }

    // MARK: Read-outs

    var paceSecondsPerMile: Double {
        let miles = meters / 1609.34
        guard miles > 0.02 else { return 0 }
        return Double(elapsed) / miles
    }

    var currentPaceSecondsPerMile: Double {
        guard currentSpeed > 0.2 else { return 0 }
        return 1609.34 / currentSpeed
    }

    static func paceString(_ secondsPerMile: Double) -> String {
        guard secondsPerMile > 0, secondsPerMile.isFinite, secondsPerMile < 5400 else { return "—" }
        let m = Int(secondsPerMile) / 60
        let s = Int(secondsPerMile) % 60
        return "\(m):\(String(format: "%02d", s))"
    }

    static func clock(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        return h > 0 ? "\(h):\(String(format: "%02d:%02d", m, s))"
                     : "\(m):\(String(format: "%02d", s))"
    }
}
