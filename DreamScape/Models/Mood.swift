import Foundation
import SwiftUI

// MARK: - Mood

/// Core mood type representing emotional states that drive scene generation.
/// Extracted from Serenity Soother's EmotionType, simplified for DreamScape's
/// immersive session focus.
enum Mood: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm = "Calm"
    case joy = "Joy"
    case wonder = "Wonder"
    case melancholy = "Melancholy"
    case energy = "Energy"
    case serenity = "Serenity"
    case mystery = "Mystery"
    case hope = "Hope"
    case nostalgia = "Nostalgia"
    case awe = "Awe"
    case tenderness = "Tenderness"
    case focus = "Focus"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .calm: return "leaf.fill"
        case .joy: return "sun.max.fill"
        case .wonder: return "sparkles"
        case .melancholy: return "cloud.rain.fill"
        case .energy: return "bolt.fill"
        case .serenity: return "water.waves"
        case .mystery: return "moon.stars.fill"
        case .hope: return "sunrise.fill"
        case .nostalgia: return "clock.fill"
        case .awe: return "mountain.2.fill"
        case .tenderness: return "heart.fill"
        case .focus: return "eye.fill"
        }
    }

    var color: Color {
        switch self {
        case .calm: return Color(hex: "4ECDC4")
        case .joy: return Color(hex: "FFD700")
        case .wonder: return Color(hex: "9B59B6")
        case .melancholy: return Color(hex: "4A90A4")
        case .energy: return Color(hex: "E74C3C")
        case .serenity: return Color(hex: "2ECC71")
        case .mystery: return Color(hex: "2C003E")
        case .hope: return Color(hex: "3498DB")
        case .nostalgia: return Color(hex: "D4A574")
        case .awe: return Color(hex: "7209B7")
        case .tenderness: return Color(hex: "E91E63")
        case .focus: return Color(hex: "1ABC9C")
        }
    }

    var gradientColors: [Color] {
        switch self {
        case .calm: return [Color(hex: "0D1B2A"), Color(hex: "1B4965"), Color(hex: "4ECDC4")]
        case .joy: return [Color(hex: "F7971E"), Color(hex: "FFD200"), Color(hex: "FFF7AE")]
        case .wonder: return [Color(hex: "2C003E"), Color(hex: "512B58"), Color(hex: "9B59B6")]
        case .melancholy: return [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "4A90A4")]
        case .energy: return [Color(hex: "CB2D3E"), Color(hex: "EF473A"), Color(hex: "F7971E")]
        case .serenity: return [Color(hex: "1E3D2F"), Color(hex: "2D5A27"), Color(hex: "A4D17A")]
        case .mystery: return [Color(hex: "0D0628"), Color(hex: "1A0A3E"), Color(hex: "3A0CA3")]
        case .hope: return [Color(hex: "005C97"), Color(hex: "3498DB"), Color(hex: "AED6F1")]
        case .nostalgia: return [Color(hex: "3E2723"), Color(hex: "795548"), Color(hex: "D4A574")]
        case .awe: return [Color(hex: "240046"), Color(hex: "5A189A"), Color(hex: "9D4EDD")]
        case .tenderness: return [Color(hex: "880E4F"), Color(hex: "E91E63"), Color(hex: "F8BBD0")]
        case .focus: return [Color(hex: "0A3D62"), Color(hex: "1ABC9C"), Color(hex: "76D7C4")]
        }
    }

    /// Prompt fragment for AI scene generation
    var scenePromptHint: String {
        switch self {
        case .calm: return "serene, tranquil, soft light, gentle water, peaceful meadow"
        case .joy: return "warm sunlight, vibrant flowers, golden hour, celebration of life"
        case .wonder: return "mystical, ethereal glow, enchanted forest, magical particles"
        case .melancholy: return "gentle rain, misty landscape, soft blue tones, reflective waters"
        case .energy: return "dynamic, vivid colors, sunrise over mountains, flowing energy"
        case .serenity: return "zen garden, still lake, cherry blossoms, harmony, balance"
        case .mystery: return "deep cosmos, ancient temple, starlit paths, hidden knowledge"
        case .hope: return "dawn breaking, new growth, light through clouds, spring blossoms"
        case .nostalgia: return "warm amber light, vintage tones, cozy autumn, familiar paths"
        case .awe: return "vast mountains, northern lights, cosmic vista, infinite horizon"
        case .tenderness: return "soft petals, gentle embrace, warm glow, nurturing garden"
        case .focus: return "crystal clarity, geometric patterns, deep ocean, sharp peaks"
        }
    }
}

// MARK: - Mood Intensity

enum MoodIntensity: String, Codable, CaseIterable, Sendable {
    case gentle = "Gentle"
    case moderate = "Moderate"
    case deep = "Deep"
    case immersive = "Immersive"

    var multiplier: Double {
        switch self {
        case .gentle: return 0.4
        case .moderate: return 0.7
        case .deep: return 0.9
        case .immersive: return 1.0
        }
    }

    var sessionDurationMinutes: Int {
        switch self {
        case .gentle: return 5
        case .moderate: return 10
        case .deep: return 20
        case .immersive: return 30
        }
    }
}

// MARK: - Color Hex Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
