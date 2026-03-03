import Foundation
import ComposableArchitecture

// MARK: - DreamScape Feature

/// Root TCA reducer for DreamScape.
/// Drives the full flow: mood selection -> scene generation -> immersive playback -> reflection.
@Reducer
struct DreamScapeFeature {

    // MARK: - State

    @ObservableState
    struct State: Equatable {
        // Navigation phase
        var phase: AppPhase = .moodSelection

        // Mood selection
        var selectedMood: Mood? = nil
        var selectedIntensity: MoodIntensity = .moderate
        var relatedMoods: [Mood] = []

        // Scene generation
        var generationPhase: SceneGenerationPhase = .idle
        var generatedScenes: [SceneState] = []
        var moodArc: [MoodBlend] = []
        var generationProgress: Double = 0.0
        var generationError: String? = nil

        // Playback
        var session: DreamSession? = nil
        var currentSceneIndex: Int = 0
        var isPlaying: Bool = false
        var elapsedSeconds: Int = 0
        var ambientVolume: Float = 0.5
        var selectedAmbientSound: AmbientSound? = nil

        // Post-session
        var postMoodRating: Int = 3
        var reflectionNote: String = ""

        // Session history
        var sessionHistory: [DreamSession] = []
        var isLoadingHistory: Bool = false

        // Computed
        var currentScene: SceneState? {
            guard currentSceneIndex < generatedScenes.count else { return nil }
            return generatedScenes[currentSceneIndex]
        }

        var canAdvanceScene: Bool {
            currentSceneIndex < generatedScenes.count - 1
        }

        var canRewindScene: Bool {
            currentSceneIndex > 0
        }

        var overallProgress: Double {
            guard !generatedScenes.isEmpty else { return 0 }
            let sceneProgress = Double(currentSceneIndex) / Double(generatedScenes.count)
            return sceneProgress
        }

        var formattedElapsed: String {
            let mins = elapsedSeconds / 60
            let secs = elapsedSeconds % 60
            return String(format: "%d:%02d", mins, secs)
        }

        var formattedRemaining: String {
            guard let session = session else { return "0:00" }
            let total = session.scenes.reduce(0) { $0 + $1.duration }
            let remaining = max(0, total - elapsedSeconds)
            let mins = remaining / 60
            let secs = remaining % 60
            return String(format: "%d:%02d", mins, secs)
        }
    }

    // MARK: - App Phase

    enum AppPhase: Equatable {
        case moodSelection
        case generating
        case playback
        case reflection
        case history
    }

    // MARK: - Action

    enum Action: Equatable {
        // Mood selection
        case selectMood(Mood)
        case selectIntensity(MoodIntensity)
        case startGeneration

        // Scene generation
        case scenesGenerated([SceneState])
        case generationFailed(String)
        case generationProgressUpdated(Double)

        // Playback
        case startPlayback
        case togglePlayback
        case nextScene
        case previousScene
        case seekToScene(Int)
        case tick
        case sceneCompleted
        case selectAmbientSound(AmbientSound?)
        case setAmbientVolume(Float)
        case endSession

        // Reflection
        case setPostMoodRating(Int)
        case setReflectionNote(String)
        case submitReflection
        case reflectionSaved

        // History
        case showHistory
        case historyLoaded([DreamSession])
        case deleteSession(UUID)
        case sessionDeleted(UUID)

        // Navigation
        case returnToMoodSelection
        case dismissError
    }

    // MARK: - Dependencies

    @Dependency(\.sceneGenerator) var sceneGenerator
    @Dependency(\.audioLayer) var audioLayer
    @Dependency(\.sessionPersistence) var sessionPersistence
    @Dependency(\.continuousClock) var clock

    // Timer cancel ID
    private enum PlaybackTimerID: Hashable { case timer }

    // MARK: - Reducer

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {

            // MARK: Mood Selection

            case let .selectMood(mood):
                state.selectedMood = mood
                state.relatedMoods = MoodPropagationEngine.relatedMoods(to: mood)
                return .none

            case let .selectIntensity(intensity):
                state.selectedIntensity = intensity
                return .none

            case .startGeneration:
                guard let mood = state.selectedMood else { return .none }
                state.phase = .generating
                state.generationPhase = .generatingDescription
                state.generationProgress = 0
                state.generationError = nil
                state.generatedScenes = []

                let intensity = state.selectedIntensity
                let sceneCount = max(3, intensity.sessionDurationMinutes / 3)
                let arc = MoodPropagationEngine.computeArc(
                    primaryMood: mood,
                    sceneCount: sceneCount,
                    intensity: intensity
                )
                state.moodArc = arc

                return .run { send in
                    var scenes: [SceneState] = []
                    let total = Double(arc.count)

                    for (i, blend) in arc.enumerated() {
                        let scene = try await sceneGenerator.generateScene(blend, i)
                        scenes.append(scene)
                        await send(.generationProgressUpdated(Double(i + 1) / total))
                    }

                    await send(.scenesGenerated(scenes))
                } catch: { error, send in
                    await send(.generationFailed(error.localizedDescription))
                }

            case let .scenesGenerated(scenes):
                state.generatedScenes = scenes
                state.generationPhase = .complete
                state.generationProgress = 1.0

                // Create session
                if let mood = state.selectedMood {
                    var session = DreamSession(mood: mood, intensity: state.selectedIntensity)
                    session.scenes = scenes
                    session.status = .playing
                    state.session = session
                }

                state.phase = .playback
                state.currentSceneIndex = 0
                state.elapsedSeconds = 0
                state.isPlaying = true

                // Auto-select ambient sound for mood
                if let mood = state.selectedMood {
                    state.selectedAmbientSound = AmbientSound.forMood(mood)
                }

                return .merge(
                    // Start playback timer
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: PlaybackTimerID.timer),

                    // Start ambient audio
                    .run { [sound = state.selectedAmbientSound] _ in
                        if let sound = sound {
                            await audioLayer.playAmbient(sound)
                        }
                    },

                    // Narrate first scene
                    .run { [scene = scenes.first] _ in
                        if let scene = scene, !scene.narrationText.isEmpty {
                            await audioLayer.speakNarration(scene.narrationText)
                        }
                    }
                )

            case let .generationFailed(error):
                state.generationPhase = .failed
                state.generationError = error
                return .none

            case let .generationProgressUpdated(progress):
                state.generationProgress = progress
                if progress < 0.5 {
                    state.generationPhase = .generatingDescription
                } else if progress < 0.9 {
                    state.generationPhase = .generatingImage
                } else {
                    state.generationPhase = .generatingNarration
                }
                return .none

            // MARK: Playback

            case .startPlayback:
                state.isPlaying = true
                return .merge(
                    .run { send in
                        for await _ in clock.timer(interval: .seconds(1)) {
                            await send(.tick)
                        }
                    }
                    .cancellable(id: PlaybackTimerID.timer),

                    .run { _ in
                        await audioLayer.resumeAll()
                    }
                )

            case .togglePlayback:
                state.isPlaying.toggle()
                if state.isPlaying {
                    return .merge(
                        .run { send in
                            for await _ in clock.timer(interval: .seconds(1)) {
                                await send(.tick)
                            }
                        }
                        .cancellable(id: PlaybackTimerID.timer),

                        .run { _ in
                            await audioLayer.resumeAll()
                        }
                    )
                } else {
                    return .merge(
                        .cancel(id: PlaybackTimerID.timer),
                        .run { _ in
                            await audioLayer.pauseAll()
                        }
                    )
                }

            case .tick:
                guard state.isPlaying else { return .none }
                state.elapsedSeconds += 1

                // Check if current scene duration has elapsed
                if let scene = state.currentScene {
                    let sceneStart = state.generatedScenes.prefix(state.currentSceneIndex)
                        .reduce(0) { $0 + $1.duration }
                    let sceneElapsed = state.elapsedSeconds - sceneStart
                    if sceneElapsed >= scene.duration {
                        return .send(.sceneCompleted)
                    }
                }
                return .none

            case .sceneCompleted:
                if state.canAdvanceScene {
                    return .send(.nextScene)
                } else {
                    return .send(.endSession)
                }

            case .nextScene:
                guard state.canAdvanceScene else { return .none }
                state.currentSceneIndex += 1

                return .run { [scene = state.currentScene] _ in
                    if let scene = scene, !scene.narrationText.isEmpty {
                        await audioLayer.speakNarration(scene.narrationText)
                    }
                }

            case .previousScene:
                guard state.canRewindScene else { return .none }
                state.currentSceneIndex -= 1

                return .run { [scene = state.currentScene] _ in
                    if let scene = scene, !scene.narrationText.isEmpty {
                        await audioLayer.speakNarration(scene.narrationText)
                    }
                }

            case let .seekToScene(index):
                guard index >= 0, index < state.generatedScenes.count else { return .none }
                state.currentSceneIndex = index

                return .run { [scene = state.generatedScenes[index]] _ in
                    if !scene.narrationText.isEmpty {
                        await audioLayer.speakNarration(scene.narrationText)
                    }
                }

            case let .selectAmbientSound(sound):
                state.selectedAmbientSound = sound
                return .run { _ in
                    if let sound = sound {
                        await audioLayer.playAmbient(sound)
                    } else {
                        await audioLayer.stopAmbient()
                    }
                }

            case let .setAmbientVolume(volume):
                state.ambientVolume = volume
                return .run { _ in
                    await audioLayer.setAmbientVolume(volume)
                }

            case .endSession:
                state.isPlaying = false
                state.phase = .reflection

                if var session = state.session {
                    session.complete()
                    state.session = session
                }

                return .merge(
                    .cancel(id: PlaybackTimerID.timer),
                    .run { _ in
                        await audioLayer.stopAll()
                    }
                )

            // MARK: Reflection

            case let .setPostMoodRating(rating):
                state.postMoodRating = rating
                return .none

            case let .setReflectionNote(note):
                state.reflectionNote = note
                return .none

            case .submitReflection:
                guard var session = state.session else { return .none }
                session.postMoodRating = state.postMoodRating
                session.reflectionNote = state.reflectionNote.isEmpty ? nil : state.reflectionNote
                state.session = session

                return .run { [session] send in
                    try await sessionPersistence.saveSession(session)
                    await send(.reflectionSaved)
                } catch: { _, send in
                    await send(.reflectionSaved) // Navigate anyway
                }

            case .reflectionSaved:
                return .send(.returnToMoodSelection)

            // MARK: History

            case .showHistory:
                state.phase = .history
                state.isLoadingHistory = true

                return .run { send in
                    let sessions = try await sessionPersistence.loadHistory(50)
                    await send(.historyLoaded(sessions))
                } catch: { _, send in
                    await send(.historyLoaded([]))
                }

            case let .historyLoaded(sessions):
                state.sessionHistory = sessions
                state.isLoadingHistory = false
                return .none

            case let .deleteSession(id):
                return .run { send in
                    try await sessionPersistence.deleteSession(id)
                    await send(.sessionDeleted(id))
                } catch: { _, _ in }

            case let .sessionDeleted(id):
                state.sessionHistory.removeAll(where: { $0.id == id })
                return .none

            // MARK: Navigation

            case .returnToMoodSelection:
                state.phase = .moodSelection
                state.selectedMood = nil
                state.generatedScenes = []
                state.session = nil
                state.currentSceneIndex = 0
                state.elapsedSeconds = 0
                state.isPlaying = false
                state.generationPhase = .idle
                state.generationProgress = 0
                state.generationError = nil
                state.postMoodRating = 3
                state.reflectionNote = ""
                return .none

            case .dismissError:
                state.generationError = nil
                state.phase = .moodSelection
                return .none
            }
        }
    }
}
