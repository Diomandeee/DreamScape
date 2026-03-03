import Foundation
import ComposableArchitecture
#if canImport(Supabase)
import Supabase
#endif
import OpenClawCore

// MARK: - Session Persistence Client

/// TCA dependency for persisting dream sessions to Supabase.
@DependencyClient
struct SessionPersistenceClient: Sendable {
    var saveSession: @Sendable (DreamSession) async throws -> Void
    var loadHistory: @Sendable (Int) async throws -> [DreamSession]
    var deleteSession: @Sendable (UUID) async throws -> Void
}

extension SessionPersistenceClient: DependencyKey {
    static let liveValue: SessionPersistenceClient = {
        #if canImport(Supabase)
        let client = SupabaseClient(
            supabaseURL: URL(string: OpenClawConfig.supabaseUrlString)!,
            supabaseKey: OpenClawConfig.supabaseAnonKey
        )

        return SessionPersistenceClient(
            saveSession: { session in
                let record = DreamSessionRecord(from: session)
                try await client
                    .from("dream_sessions")
                    .upsert(record)
                    .execute()
            },
            loadHistory: { limit in
                let records: [DreamSessionRecord] = try await client
                    .from("dream_sessions")
                    .select()
                    .order("started_at", ascending: false)
                    .limit(limit)
                    .execute()
                    .value

                return records.compactMap { record in
                    guard let mood = Mood(rawValue: record.mood),
                          let intensity = MoodIntensity(rawValue: record.intensity),
                          let status = DreamSessionStatus(rawValue: record.status),
                          let id = UUID(uuidString: record.id) else {
                        return nil
                    }

                    let formatter = ISO8601DateFormatter()
                    var session = DreamSession(id: id, mood: mood, intensity: intensity)
                    session.status = status
                    session.durationSeconds = record.duration_seconds
                    session.completionPercentage = record.completion_percentage
                    session.postMoodRating = record.post_mood_rating
                    session.reflectionNote = record.reflection_note
                    if let started = formatter.date(from: record.started_at) {
                        session.startedAt = started
                    }
                    if let completed = record.completed_at {
                        session.completedAt = formatter.date(from: completed)
                    }
                    return session
                }
            },
            deleteSession: { id in
                try await client
                    .from("dream_sessions")
                    .delete()
                    .eq("id", value: id.uuidString)
                    .execute()
            }
        )
        #else
        // Fallback when Supabase is not available
        return SessionPersistenceClient(
            saveSession: { _ in },
            loadHistory: { _ in [] },
            deleteSession: { _ in }
        )
        #endif
    }()

    static let testValue = SessionPersistenceClient(
        saveSession: { _ in },
        loadHistory: { _ in [] },
        deleteSession: { _ in }
    )
}

extension DependencyValues {
    var sessionPersistence: SessionPersistenceClient {
        get { self[SessionPersistenceClient.self] }
        set { self[SessionPersistenceClient.self] = newValue }
    }
}
