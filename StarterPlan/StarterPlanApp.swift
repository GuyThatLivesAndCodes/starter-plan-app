import SwiftUI
import SwiftData

@main
struct StarterPlanApp: App {
    let container: ModelContainer
    @State private var store: Store

    init() {
        let container = try! ModelContainer(for: Profile.self, DayLog.self, ExerciseState.self, SessionEntry.self, SetRecord.self)
        self.container = container
        let store = Store(context: ModelContext(container))
        Feedback.shared.soundEnabled = store.profile.soundEnabled
        _store = State(initialValue: store)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
                .onAppear { Notifications.shared.refresh(store: store) }
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @Environment(Store.self) private var store
    @State private var tab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.bg.ignoresSafeArea()

            Group {
                switch tab {
                case 1: HistoryView()
                case 2: SettingsView()
                default: HomeView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            TabBar(selection: $tab)
        }
    }
}

struct TabBar: View {
    @Binding var selection: Int
    private let items: [(String, String)] = [("figure.run", "Plan"), ("calendar", "History"), ("gearshape.fill", "Settings")]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                Button {
                    Feedback.shared.tap()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selection = i }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: items[i].0).font(.system(size: 19, weight: .semibold))
                        Text(items[i].1).font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(selection == i ? Theme.accent : Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(selection == i ? 1.06 : 1)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .top)
    }
}
