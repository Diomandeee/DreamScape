import Foundation
import SwiftUI

// MARK: - Scene State

/// Represents a single generated scene within a dream session.
/// Adapted from Serenity Soother's Scene and PrecomputedScene models,
/// tailored for DreamScape's mood-driven generation pipeline.
struct SceneState: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var title: String
    var description: String
    var mood: Mood
    var imageURL: String?
    var localImagePath: String?
    var narrationText: String
    var ambientSoundId: String?
    var duration: Int // seconds
    var orderIndex: Int
    var transition: SceneTransition
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        mood: Mood = .calm,
        narrationText: String = "",
        duration: Int = 60,
        orderIndex: Int = 0,
        transition: SceneTransition = .crossDissolve
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.mood = mood
        self.narrationText = narrationText
        self.duration = duration
        self.orderIndex = orderIndex
        self.transition = transition
        self.generatedAt = Date()
    }
}

// MARK: - Scene Transition

enum SceneTransition: String, Codable, CaseIterable, Sendable {
    case fadeIn = "Fade In"
    case crossDissolve = "Cross Dissolve"
    case slideLeft = "Slide Left"
    case zoomIn = "Zoom In"
    case blur = "Blur"
    case dreamWave = "Dream Wave"

    var animationDuration: Double {
        switch self {
        case .fadeIn: return 1.5
        case .crossDissolve: return 2.0
        case .slideLeft: return 1.0
        case .zoomIn: return 2.5
        case .blur: return 1.5
        case .dreamWave: return 3.0
        }
    }
}

// MARK: - Ambient Sound

struct AmbientSound: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let icon: String
    let fileName: String

    static let all: [AmbientSound] = [
        AmbientSound(id: "rain", name: "Gentle Rain", icon: "cloud.rain.fill", fileName: "rain_ambient"),
        AmbientSound(id: "forest", name: "Forest", icon: "leaf.fill", fileName: "forest_ambient"),
        AmbientSound(id: "ocean", name: "Ocean Waves", icon: "water.waves", fileName: "ocean_ambient"),
        AmbientSound(id: "fire", name: "Fireplace", icon: "flame.fill", fileName: "fire_ambient"),
        AmbientSound(id: "wind", name: "Soft Wind", icon: "wind", fileName: "wind_ambient"),
        AmbientSound(id: "birds", name: "Morning Birds", icon: "bird.fill", fileName: "birds_ambient"),
        AmbientSound(id: "stream", name: "Stream", icon: "drop.fill", fileName: "stream_ambient"),
        AmbientSound(id: "night", name: "Night", icon: "moon.stars.fill", fileName: "night_ambient"),
        AmbientSound(id: "bowls", name: "Singing Bowls", icon: "circle.hexagonpath.fill", fileName: "bowls_ambient"),
        AmbientSound(id: "cosmos", name: "Cosmic Drift", icon: "sparkles", fileName: "cosmos_ambient"),
    ]

    static func forMood(_ mood: Mood) -> AmbientSound {
        switch mood {
        case .calm: return all.first(where: { $0.id == "stream" })!
        case .joy: return all.first(where: { $0.id == "birds" })!
        case .wonder: return all.first(where: { $0.id == "cosmos" })!
        case .melancholy: return all.first(where: { $0.id == "rain" })!
        case .energy: return all.first(where: { $0.id == "wind" })!
        case .serenity: return all.first(where: { $0.id == "bowls" })!
        case .mystery: return all.first(where: { $0.id == "night" })!
        case .hope: return all.first(where: { $0.id == "birds" })!
        case .nostalgia: return all.first(where: { $0.id == "fire" })!
        case .awe: return all.first(where: { $0.id == "cosmos" })!
        case .tenderness: return all.first(where: { $0.id == "stream" })!
        case .focus: return all.first(where: { $0.id == "ocean" })!
        }
    }
}

// MARK: - Scene Generation Phase

enum SceneGenerationPhase: String, Codable, Sendable {
    case idle = "Idle"
    case generatingDescription = "Creating scene..."
    case generatingImage = "Painting dreamscape..."
    case generatingNarration = "Weaving narration..."
    case complete = "Ready"
    case failed = "Failed"
}
