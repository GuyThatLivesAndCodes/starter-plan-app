import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var showReset = false
    @State private var editingWeights = false
    @State private var editingProfile = false
    @State private var showArcade = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    Feedback.shared.tap(); editingProfile = true
                } label: {
                    row(icon: "person.fill", title: "Your details",
                        subtitle: profileSubtitle, color: Theme.gold, chevron: true)
                }
                .buttonStyle(.plain)
                .card(Theme.surface)

                Button {
                    Feedback.shared.tap(); showArcade = true
                } label: {
                    row(icon: "gamecontroller.fill", title: "Rest arcade",
                        subtitle: "\(store.profile.coins) coins · \(store.profile.unlockedGames.count) of \(GameCatalog.all.count) games",
                        color: Theme.teal, chevron: true)
                }
                .buttonStyle(.plain)
                .card(Theme.surface)

                VStack(spacing: 0) {
                    toggleRow(icon: "bell.fill", title: "Daily reminders",
                              subtitle: "Four a day until the session is done",
                              color: Theme.flame,
                              isOn: Binding(get: { store.profile.notificationsEnabled },
                                            set: { store.setNotifications($0); Feedback.shared.tap() }))
                    divider
                    toggleRow(icon: "speaker.wave.2.fill", title: "Sound effects",
                              subtitle: "Pops, dings and chimes",
                              color: Theme.teal,
                              isOn: Binding(get: { store.profile.soundEnabled },
                                            set: { store.toggleSound($0); Feedback.shared.soundEnabled = $0; Feedback.shared.tap() }))
                }
                .card(Theme.surface)

                Button {
                    Feedback.shared.tap(); editingWeights = true
                } label: {
                    row(icon: "scalemass.fill", title: "Exercise weights",
                        subtitle: "Edit the weight saved for each lift", color: Theme.accent, chevron: true)
                }
                .buttonStyle(.plain)
                .card(Theme.surface)

                Button {
                    Feedback.shared.denied(); showReset = true
                } label: {
                    row(icon: "arrow.counterclockwise", title: "Reset plan",
                        subtitle: "Clears progress, streak and XP", color: Theme.danger, chevron: false)
                }
                .buttonStyle(.plain)
                .card(Theme.surface)

                VStack(spacing: 4) {
                    Text("StarterPlan").font(.system(size: 13, weight: .heavy, design: .rounded)).foregroundStyle(Theme.textDim)
                    Text("4 weeks. One day at a time.").font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textDim.opacity(0.7))
                }
                .padding(.top, 10)

                Color.clear.frame(height: 100)
            }
            .padding(20)
        }
        .sheet(isPresented: $editingWeights) { WeightEditor() }
        .sheet(isPresented: $editingProfile) { BodyProfileForm(isOnboarding: false) }
        .sheet(isPresented: $showArcade) { GameShopView() }
        .alert("Reset everything?", isPresented: $showReset) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) { store.resetPlan(); Feedback.shared.tap() }
        } message: {
            Text("Your streak, XP, coins and every logged set will be cleared. Your details and unlocked games stay.")
        }
    }

    private var profileSubtitle: String {
        let p = store.profile
        guard p.hasBody else { return "Add age, height and weight for smart weights" }
        return "\(p.age) · \(Int(p.heightIn) / 12)'\(Int(p.heightIn) % 12)\" · \(Int(p.bodyWeightLb)) lb · \(p.experience.label)"
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 62)
    }

    private func toggleRow(icon: String, title: String, subtitle: String, color: Color, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textDim)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().tint(Theme.accent)
        }
        .padding(16)
    }

    private func row(icon: String, title: String, subtitle: String, color: Color, chevron: Bool) -> some View {
        HStack(spacing: 14) {
            iconBox(icon, color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .heavy, design: .rounded)).foregroundStyle(Theme.text)
                Text(subtitle).font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(Theme.textDim)
            }
            Spacer()
            if chevron {
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.textDim)
            }
        }
        .padding(16)
    }

    private func iconBox(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(color)
            .frame(width: 34, height: 34)
            .background(RoundedRectangle(cornerRadius: 11).fill(color.opacity(0.15)))
    }
}

struct WeightEditor: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    private var lifts: [Exercise] { (Plan.strengthA + Plan.strengthB).filter(\.tracksWeight) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Exercise weights")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.text)
                Text("The coach picks these from your body stats and how your sets go. Override any of them here.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textDim)

                ForEach(lifts) { ex in
                    WeightRow(exercise: ex, store: store)
                }

                Button("Done") { Feedback.shared.tap(); dismiss() }
                    .buttonStyle(ChunkyButtonStyle())
                    .padding(.top, 8)
            }
            .padding(24)
        }
        .background(Theme.bg)
        .presentationDetents([.large])
        .presentationBackground(Theme.bg)
    }
}

private struct WeightRow: View {
    let exercise: Exercise
    let store: Store
    @State private var weight: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            Text(exercise.name)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.text)
            Spacer()
            step("minus") { weight = max(0, weight - 5) }
            Text(weight == 0 ? "—" : "\(Int(weight))")
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 48)
            step("plus") { weight += 5 }
        }
        .padding(14)
        .card(Theme.surface)
        .onAppear { weight = store.state(for: exercise.id).lastWeight }
    }

    private func step(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button {
            Feedback.shared.tap()
            action()
            store.setWeight(weight, for: exercise.id)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Theme.text)
                .frame(width: 32, height: 32)
                .background(Circle().fill(Theme.surfaceHigh))
        }
        .buttonStyle(.plain)
    }
}
