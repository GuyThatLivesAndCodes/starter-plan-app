import AVFoundation
import AudioToolbox
import UIKit

/// Short, snappy sound + haptic feedback. Uses system sounds so the app ships
/// with no audio assets and no extra dependencies.
final class Feedback {
    static let shared = Feedback()
    var soundEnabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let medium = UIImpactFeedbackGenerator(style: .medium)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let notify = UINotificationFeedbackGenerator()

    private init() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        [light, medium, rigid].forEach { $0.prepare() }
    }

    private func play(_ id: SystemSoundID) {
        guard soundEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }

    /// Set checked — pop.
    func setChecked() { rigid.impactOccurred(intensity: 0.9); play(1104) }
    /// Exercise finished.
    func exerciseDone() { medium.impactOccurred(); play(1057) }
    /// Rest timer finished — ding.
    func timerDone() { notify.notificationOccurred(.success); play(1005) }
    /// Whole workout finished — celebration chime.
    func celebrate() { notify.notificationOccurred(.success); play(1025) }
    /// Streak milestone.
    func milestone() { notify.notificationOccurred(.success); play(1027) }
    /// Generic tap.
    func tap() { light.impactOccurred(intensity: 0.6) }
    /// Blocked / locked day.
    func denied() { notify.notificationOccurred(.warning); play(1053) }
}
