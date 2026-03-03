import Foundation

// MARK: - Dream Session

/// Represents a complete DreamScape session from mood selection through playback.
/// Persisted to Supabase for session history and analytics.
struct DreamSession: Codable, Identifiable, Equatable, Sendable {
    var id: UUID
    var mood: Mood
    var intensity: MoodIntensity
    var scenes: [SceneState]
    var status: DreamSessionStatus
    var startedAt: Date
    var completedAt: Date?
    var durationSeconds: Int
    var completionPercentage: Double

    // Post-session reflection
    var postMoodRating: Int? // 1-5
    var reflectionNote: String?

    init(
        id: UUID = UUID(),
        mood: Mood,
        intensity: MoodIntensity = .moderate
    ) {
        self.id = id
        self.mood = mood
        self.intensity = intensity
        self.scenes = []
        self.status = .preparing
        self.startedAt = Date()
        self.durationSeconds = 0
        self.completionPercentage = 0.0
    }

    mutating func complete() {
        self.completedAt = Date()
        self.status = .completed
        self.completionPercentage = 100.0
        if let start = Calendar.current.dateComponents(
            [.second], from: startedAt, to: completedAt ?? Date()
        ).second {
            self.durationSeconds = start
        }
    }

    mutating func cancel() {
        self.completedAt = Date()
        self.status = .cancelled
    }
}

// MARK: - Dream Session Status

enum DreamSessionStatus: String, Codable, CaseIterable, Sendable {
    case preparing = "Preparing"
    case generating = "Generating"
    case playing = "Playing"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var isActive: Bool {
        switch self {
        case .preparing, .generating, .playing, .paused:
            return true
        case .completed, .cancelled:
            return false
        }
    }
}

// MARK: - Supabase DTO

/// Flat structure for Supabase persistence. Maps to `dream_sessions` table.
struct DreamSessionRecord: Codable, Sendable {
    let id: String
    let mood: String
    let intensity: String
    let status: String
    let started_at: String
    let completed_at: String?
    let duration_seconds: Int
    let completion_percentage: Double
    let post_mood_rating: Int?
    let reflection_note: String?
    let scene_count: Int

    init(from session: DreamSession) {
        let formatter = ISO8601DateFormatter()
        self.id = session.id.uuidString
        self.mood = session.mood.rawValue
        self.intensity = session.intensity.rawValue
        self.status = session.status.rawValue
        self.started_at = formatter.string(from: session.startedAt)
        self.completed_at = session.completedAt.map { formatter.string(from: $0) }
        self.duration_seconds = session.durationSeconds
        self.completion_percentage = session.completionPercentage
        self.post_mood_rating = session.postMoodRating
        self.reflection_note = session.reflectionNote
        self.scene_count = session.scenes.count
    }
}
