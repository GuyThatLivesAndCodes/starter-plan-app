import SwiftUI

/// A stylised front-and-back figure with each muscle group drawn as its own
/// shape, so the app can show what a movement works, what a session covers, and
/// where the week's volume actually landed.
struct BodyMap: View {
    /// 0 = untouched, 1 = fully worked. Anything in between shades toward the accent.
    var intensity: [Muscle: Double] = [:]
    var selectable = false
    var selected: Set<Muscle> = []
    var onTap: ((Muscle) -> Void)? = nil
    var showLabels = true

    var body: some View {
        HStack(spacing: 14) {
            figure(back: false, caption: "Front")
            figure(back: true, caption: "Back")
        }
    }

    private func figure(back: Bool, caption: String) -> some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let s = min(geo.size.width / BodyGeometry.width, geo.size.height / BodyGeometry.height)
                let ox = (geo.size.width - BodyGeometry.width * s) / 2
                let oy = (geo.size.height - BodyGeometry.height * s) / 2

                ZStack {
                    // Silhouette underneath everything.
                    BodyGeometry.silhouettePath(back: back, scale: s, origin: CGPoint(x: ox, y: oy))
                        .fill(Theme.surfaceHigh)

                    ForEach(BodyGeometry.regions(back: back), id: \.muscle) { region in
                        let m = region.muscle
                        BodyGeometry.path(for: region, scale: s, origin: CGPoint(x: ox, y: oy))
                            .fill(color(for: m))
                            .overlay(
                                BodyGeometry.path(for: region, scale: s, origin: CGPoint(x: ox, y: oy))
                                    .stroke(selected.contains(m) ? Theme.accent : Color.black.opacity(0.25),
                                            lineWidth: selected.contains(m) ? 2 : 1)
                            )
                            .contentShape(BodyGeometry.path(for: region, scale: s, origin: CGPoint(x: ox, y: oy)))
                            .onTapGesture {
                                guard selectable else { return }
                                Feedback.shared.tap()
                                onTap?(m)
                            }
                    }
                }
            }
            .aspectRatio(BodyGeometry.width / BodyGeometry.height, contentMode: .fit)

            if showLabels {
                Text(caption.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(Theme.textDim)
            }
        }
    }

    private func color(for m: Muscle) -> Color {
        if selected.contains(m) { return Theme.accent }
        let v = min(1, max(0, intensity[m] ?? 0))
        guard v > 0.001 else { return Theme.locked }
        // Cool teal for light work, through the accent, to gold for the heaviest.
        if v < 0.5 {
            return Theme.teal.opacity(0.35 + v * 0.9)
        }
        return Theme.accent.opacity(0.55 + (v - 0.5) * 0.9)
    }
}

// MARK: - Geometry

/// Muscle shapes laid out in a 100 x 210 space, mirrored for left and right.
enum BodyGeometry {
    static let width: CGFloat = 100
    static let height: CGFloat = 210

    struct Region {
        let muscle: Muscle
        let blobs: [Blob]
    }

    /// A rounded blob: centre, size, and corner rounding as a fraction of height.
    struct Blob {
        var x: CGFloat
        var y: CGFloat
        var w: CGFloat
        var h: CGFloat
        var r: CGFloat = 4
        var mirrored = false      // also draw the mirror image across the centre line
    }

    static func regions(back: Bool) -> [Region] {
        back ? backRegions : frontRegions
    }

    static let frontRegions: [Region] = [
        Region(muscle: .traps, blobs: [Blob(x: 50, y: 44, w: 34, h: 9, r: 4)]),
        Region(muscle: .frontDelts, blobs: [Blob(x: 31, y: 54, w: 15, h: 15, r: 7, mirrored: true)]),
        Region(muscle: .chest, blobs: [Blob(x: 43, y: 60, w: 13, h: 16, r: 5, mirrored: true)]),
        Region(muscle: .biceps, blobs: [Blob(x: 26, y: 74, w: 11, h: 20, r: 5, mirrored: true)]),
        Region(muscle: .forearms, blobs: [Blob(x: 22, y: 98, w: 10, h: 22, r: 5, mirrored: true)]),
        Region(muscle: .abs, blobs: [Blob(x: 50, y: 84, w: 18, h: 32, r: 6)]),
        Region(muscle: .obliques, blobs: [Blob(x: 38, y: 86, w: 8, h: 26, r: 4, mirrored: true)]),
        Region(muscle: .quads, blobs: [Blob(x: 41, y: 130, w: 16, h: 40, r: 8, mirrored: true)]),
        Region(muscle: .calves, blobs: [Blob(x: 41, y: 180, w: 13, h: 26, r: 6, mirrored: true)])
    ]

    static let backRegions: [Region] = [
        Region(muscle: .traps, blobs: [Blob(x: 50, y: 50, w: 32, h: 20, r: 7)]),
        Region(muscle: .rearDelts, blobs: [Blob(x: 31, y: 56, w: 14, h: 13, r: 6, mirrored: true)]),
        Region(muscle: .lats, blobs: [Blob(x: 42, y: 76, w: 15, h: 26, r: 6, mirrored: true)]),
        Region(muscle: .triceps, blobs: [Blob(x: 26, y: 76, w: 11, h: 20, r: 5, mirrored: true)]),
        Region(muscle: .forearms, blobs: [Blob(x: 22, y: 100, w: 10, h: 22, r: 5, mirrored: true)]),
        Region(muscle: .lowerBack, blobs: [Blob(x: 50, y: 98, w: 20, h: 16, r: 6)]),
        Region(muscle: .glutes, blobs: [Blob(x: 43, y: 116, w: 15, h: 18, r: 7, mirrored: true)]),
        Region(muscle: .hamstrings, blobs: [Blob(x: 42, y: 145, w: 15, h: 34, r: 7, mirrored: true)]),
        Region(muscle: .calves, blobs: [Blob(x: 41, y: 182, w: 13, h: 26, r: 6, mirrored: true)])
    ]

    static func path(for region: Region, scale: CGFloat, origin: CGPoint) -> Path {
        var p = Path()
        for blob in region.blobs {
            add(blob, to: &p, scale: scale, origin: origin)
            if blob.mirrored {
                var m = blob
                m.x = width - blob.x
                add(m, to: &p, scale: scale, origin: origin)
            }
        }
        return p
    }

    private static func add(_ b: Blob, to path: inout Path, scale: CGFloat, origin: CGPoint) {
        let rect = CGRect(x: origin.x + (b.x - b.w / 2) * scale,
                          y: origin.y + (b.y - b.h / 2) * scale,
                          width: b.w * scale,
                          height: b.h * scale)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: b.r * scale, height: b.r * scale))
    }

    /// Head, torso and limbs, so the muscles read as a body rather than confetti.
    static func silhouettePath(back: Bool, scale: CGFloat, origin: CGPoint) -> Path {
        var p = Path()
        let parts: [Blob] = [
            Blob(x: 50, y: 22, w: 24, h: 28, r: 12),          // head
            Blob(x: 50, y: 38, w: 12, h: 12, r: 5),           // neck
            Blob(x: 50, y: 74, w: 40, h: 48, r: 12),          // chest / upper back
            Blob(x: 50, y: 100, w: 34, h: 30, r: 10),         // waist
            Blob(x: 50, y: 118, w: 38, h: 20, r: 10),         // hips
            Blob(x: 30, y: 62, w: 16, h: 18, r: 8, mirrored: true),   // shoulders
            Blob(x: 26, y: 84, w: 13, h: 40, r: 6, mirrored: true),   // upper arms
            Blob(x: 22, y: 108, w: 12, h: 34, r: 6, mirrored: true),  // forearms
            Blob(x: 19, y: 128, w: 10, h: 12, r: 5, mirrored: true),  // hands
            Blob(x: 41, y: 140, w: 20, h: 58, r: 10, mirrored: true), // thighs
            Blob(x: 41, y: 182, w: 16, h: 36, r: 8, mirrored: true),  // lower legs
            Blob(x: 41, y: 202, w: 14, h: 10, r: 4, mirrored: true)   // feet
        ]
        for b in parts {
            add(b, to: &p, scale: scale, origin: origin)
            if b.mirrored {
                var m = b
                m.x = width - b.x
                add(m, to: &p, scale: scale, origin: origin)
            }
        }
        return p
    }
}

// MARK: - Convenience wrappers

/// Small read-only map showing what a single exercise works.
struct ExerciseBodyMap: View {
    let exercise: Exercise

    private var intensity: [Muscle: Double] {
        var out: [Muscle: Double] = [:]
        for m in exercise.primary { out[m] = 1.0 }
        for m in exercise.secondary where out[m] == nil { out[m] = 0.42 }
        return out
    }

    var body: some View {
        VStack(spacing: 12) {
            BodyMap(intensity: intensity)
                .frame(height: 190)

            HStack(spacing: 14) {
                legend(color: Theme.accent, label: "Main")
                legend(color: Theme.teal.opacity(0.7), label: "Also works")
                Spacer()
            }

            Text(summary)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var summary: String {
        let main = Array(Set(exercise.primary.map(\.plainLabel))).sorted()
        guard !main.isEmpty else { return "Whole-body work." }
        return "Mainly \(list(main))."
    }

    private func list(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0].lowercased()
        case 2: return "\(items[0].lowercased()) and \(items[1].lowercased())"
        default:
            return items.dropLast().map { $0.lowercased() }.joined(separator: ", ")
                + " and " + items[items.count - 1].lowercased()
        }
    }

    private func legend(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(label).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(Theme.textDim)
        }
    }
}

/// Map of what a whole session covers.
struct SessionBodyMap: View {
    let day: WorkoutDay

    private var intensity: [Muscle: Double] {
        let load = day.muscleLoad
        guard let peak = load.values.max(), peak > 0 else { return [:] }
        return load.mapValues { min(1, $0 / peak) }
    }

    var body: some View {
        BodyMap(intensity: intensity, showLabels: false)
    }
}
