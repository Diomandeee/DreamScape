import Foundation

// MARK: - Mood Propagation Engine

/// Emotional affinity graph that computes mood propagation and scene transitions.
/// Given a primary mood, this engine determines which related moods should bleed
/// into successive scenes to create an evolving emotional arc across a session.
///
/// The affinity graph encodes how moods influence each other:
/// - High affinity: moods flow naturally into each other
/// - Low affinity: moods create contrast/tension (used sparingly for depth)
struct MoodPropagationEngine: Sendable {

    // MARK: - Affinity Graph

    /// Affinity weights between mood pairs (0.0 = unrelated, 1.0 = deeply connected).
    /// The graph is symmetric: affinity(A,B) == affinity(B,A).
    private static let affinityMatrix: [Mood: [Mood: Double]] = [
        .calm: [
            .serenity: 0.9, .tenderness: 0.7, .hope: 0.6,
            .nostalgia: 0.5, .melancholy: 0.4, .focus: 0.6,
            .wonder: 0.3, .joy: 0.4, .awe: 0.3,
            .mystery: 0.2, .energy: 0.1
        ],
        .joy: [
            .energy: 0.8, .hope: 0.8, .wonder: 0.7,
            .tenderness: 0.5, .awe: 0.5, .calm: 0.4,
            .serenity: 0.4, .nostalgia: 0.3, .focus: 0.2,
            .mystery: 0.1, .melancholy: 0.1
        ],
        .wonder: [
            .mystery: 0.8, .awe: 0.9, .joy: 0.7,
            .hope: 0.6, .energy: 0.5, .serenity: 0.4,
            .calm: 0.3, .tenderness: 0.3, .nostalgia: 0.3,
            .focus: 0.2, .melancholy: 0.2
        ],
        .melancholy: [
            .nostalgia: 0.8, .tenderness: 0.6, .calm: 0.4,
            .hope: 0.4, .serenity: 0.3, .mystery: 0.3,
            .awe: 0.2, .wonder: 0.2, .focus: 0.2,
            .joy: 0.1, .energy: 0.1
        ],
        .energy: [
            .joy: 0.8, .awe: 0.6, .wonder: 0.5,
            .hope: 0.5, .focus: 0.5, .mystery: 0.2,
            .calm: 0.1, .serenity: 0.1, .tenderness: 0.2,
            .nostalgia: 0.1, .melancholy: 0.1
        ],
        .serenity: [
            .calm: 0.9, .tenderness: 0.7, .hope: 0.6,
            .nostalgia: 0.5, .focus: 0.5, .joy: 0.4,
            .wonder: 0.4, .awe: 0.4, .melancholy: 0.3,
            .mystery: 0.3, .energy: 0.1
        ],
        .mystery: [
            .wonder: 0.8, .awe: 0.7, .focus: 0.5,
            .melancholy: 0.3, .serenity: 0.3, .calm: 0.2,
            .nostalgia: 0.3, .energy: 0.2, .hope: 0.2,
            .tenderness: 0.1, .joy: 0.1
        ],
        .hope: [
            .joy: 0.8, .calm: 0.6, .serenity: 0.6,
            .tenderness: 0.6, .wonder: 0.6, .energy: 0.5,
            .awe: 0.5, .nostalgia: 0.4, .focus: 0.3,
            .melancholy: 0.4, .mystery: 0.2
        ],
        .nostalgia: [
            .melancholy: 0.8, .tenderness: 0.7, .calm: 0.5,
            .serenity: 0.5, .hope: 0.4, .wonder: 0.3,
            .joy: 0.3, .mystery: 0.3, .awe: 0.2,
            .focus: 0.2, .energy: 0.1
        ],
        .awe: [
            .wonder: 0.9, .mystery: 0.7, .energy: 0.6,
            .joy: 0.5, .hope: 0.5, .serenity: 0.4,
            .calm: 0.3, .focus: 0.3, .tenderness: 0.2,
            .nostalgia: 0.2, .melancholy: 0.2
        ],
        .tenderness: [
            .calm: 0.7, .serenity: 0.7, .hope: 0.6,
            .nostalgia: 0.7, .melancholy: 0.6, .joy: 0.5,
            .wonder: 0.3, .awe: 0.2, .focus: 0.2,
            .mystery: 0.1, .energy: 0.2
        ],
        .focus: [
            .calm: 0.6, .serenity: 0.5, .energy: 0.5,
            .mystery: 0.5, .awe: 0.3, .wonder: 0.2,
            .hope: 0.3, .tenderness: 0.2, .joy: 0.2,
            .nostalgia: 0.2, .melancholy: 0.2
        ],
    ]

    // MARK: - Propagation

    /// Compute the emotional arc for a session given a primary mood.
    /// Returns an ordered array of (mood, weight) pairs for each scene.
    ///
    /// The arc follows a narrative structure:
    /// 1. Opening: primary mood at full intensity
    /// 2. Deepening: primary + highest-affinity secondary
    /// 3. Peak: blend of primary with richer secondary palette
    /// 4. Integration: secondary mood crests, primary recedes slightly
    /// 5. Closing: return to primary mood for grounding
    static func computeArc(
        primaryMood: Mood,
        sceneCount: Int,
        intensity: MoodIntensity = .moderate
    ) -> [MoodBlend] {
        guard sceneCount > 0 else { return [] }

        let affinities = affinityMatrix[primaryMood] ?? [:]
        let sorted = affinities.sorted { $0.value > $1.value }
        let secondary = sorted.first?.key ?? primaryMood
        let tertiary = sorted.dropFirst().first?.key ?? secondary

        var arc: [MoodBlend] = []

        for i in 0..<sceneCount {
            let progress = Double(i) / Double(max(1, sceneCount - 1))
            let blend: MoodBlend

            switch progress {
            case 0..<0.15:
                // Opening: pure primary
                blend = MoodBlend(
                    primary: primaryMood,
                    primaryWeight: 1.0,
                    secondary: secondary,
                    secondaryWeight: 0.0
                )
            case 0.15..<0.4:
                // Deepening: introduce secondary
                let secondaryInfluence = (progress - 0.15) / 0.25 * 0.3 * intensity.multiplier
                blend = MoodBlend(
                    primary: primaryMood,
                    primaryWeight: 1.0 - secondaryInfluence,
                    secondary: secondary,
                    secondaryWeight: secondaryInfluence
                )
            case 0.4..<0.65:
                // Peak: richest blend
                let peakBlend = 0.35 * intensity.multiplier
                let tertiaryBlend = 0.1 * intensity.multiplier
                blend = MoodBlend(
                    primary: primaryMood,
                    primaryWeight: 1.0 - peakBlend - tertiaryBlend,
                    secondary: secondary,
                    secondaryWeight: peakBlend,
                    tertiary: tertiary,
                    tertiaryWeight: tertiaryBlend
                )
            case 0.65..<0.85:
                // Integration: secondary crests then fades
                let fadeOut = (progress - 0.65) / 0.2
                let secondaryInfluence = (0.3 - fadeOut * 0.2) * intensity.multiplier
                blend = MoodBlend(
                    primary: primaryMood,
                    primaryWeight: 1.0 - secondaryInfluence,
                    secondary: secondary,
                    secondaryWeight: secondaryInfluence
                )
            default:
                // Closing: return to primary
                blend = MoodBlend(
                    primary: primaryMood,
                    primaryWeight: 1.0,
                    secondary: secondary,
                    secondaryWeight: 0.0
                )
            }

            arc.append(blend)
        }

        return arc
    }

    /// Get the top N moods related to the given mood by affinity.
    static func relatedMoods(to mood: Mood, count: Int = 3) -> [Mood] {
        let affinities = affinityMatrix[mood] ?? [:]
        return affinities
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map(\.key)
    }

    /// Affinity between two moods (0.0 - 1.0).
    static func affinity(between a: Mood, and b: Mood) -> Double {
        if a == b { return 1.0 }
        return affinityMatrix[a]?[b] ?? affinityMatrix[b]?[a] ?? 0.0
    }
}

// MARK: - Mood Blend

/// A weighted blend of moods for a single scene in the emotional arc.
struct MoodBlend: Equatable, Sendable {
    let primary: Mood
    let primaryWeight: Double
    let secondary: Mood
    let secondaryWeight: Double
    var tertiary: Mood?
    var tertiaryWeight: Double

    init(
        primary: Mood,
        primaryWeight: Double,
        secondary: Mood,
        secondaryWeight: Double,
        tertiary: Mood? = nil,
        tertiaryWeight: Double = 0.0
    ) {
        self.primary = primary
        self.primaryWeight = primaryWeight
        self.secondary = secondary
        self.secondaryWeight = secondaryWeight
        self.tertiary = tertiary
        self.tertiaryWeight = tertiaryWeight
    }

    /// Dominant mood (highest weight)
    var dominant: Mood { primaryWeight >= secondaryWeight ? primary : secondary }

    /// Combined prompt hint from all contributing moods
    var promptHint: String {
        var parts = [primary.scenePromptHint]
        if secondaryWeight > 0.1 {
            parts.append(secondary.scenePromptHint)
        }
        if let t = tertiary, tertiaryWeight > 0.05 {
            parts.append(t.scenePromptHint)
        }
        return parts.joined(separator: ", ")
    }
}
