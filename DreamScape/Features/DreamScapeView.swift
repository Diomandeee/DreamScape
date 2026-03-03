import SwiftUI
import ComposableArchitecture

// MARK: - DreamScape View

/// Root view that switches between phases: mood grid, scene generation, playback, and reflection.
struct DreamScapeView: View {
    @Bindable var store: StoreOf<DreamScapeFeature>

    var body: some View {
        ZStack {
            // Dynamic background gradient based on mood
            backgroundGradient
                .ignoresSafeArea()

            switch store.phase {
            case .moodSelection:
                MoodSelectionView(store: store)
                    .transition(.opacity)

            case .generating:
                GenerationView(store: store)
                    .transition(.opacity)

            case .playback:
                PlaybackView(store: store)
                    .transition(.opacity)

            case .reflection:
                ReflectionView(store: store)
                    .transition(.opacity)

            case .history:
                HistoryView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.phase)
    }

    private var backgroundGradient: some View {
        let colors: [Color] = {
            if let mood = store.selectedMood {
                return mood.gradientColors
            }
            return [Color(hex: "0D1B2A"), Color(hex: "1B2838"), Color(hex: "2C3E50")]
        }()

        return LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Mood Selection View

private struct MoodSelectionView: View {
    let store: StoreOf<DreamScapeFeature>

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "moon.stars.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.9))

                    Text("DreamScape")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)

                    Text("Choose a mood to begin your journey")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.top, 40)

                // Mood Grid
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Mood.allCases) { mood in
                        MoodCard(
                            mood: mood,
                            isSelected: store.selectedMood == mood
                        )
                        .onTapGesture {
                            store.send(.selectMood(mood))
                        }
                    }
                }
                .padding(.horizontal)

                // Intensity Picker
                if store.selectedMood != nil {
                    VStack(spacing: 12) {
                        Text("Intensity")
                            .font(.headline)
                            .foregroundStyle(.white)

                        HStack(spacing: 12) {
                            ForEach(MoodIntensity.allCases, id: \.rawValue) { intensity in
                                IntensityButton(
                                    intensity: intensity,
                                    isSelected: store.selectedIntensity == intensity
                                )
                                .onTapGesture {
                                    store.send(.selectIntensity(intensity))
                                }
                            }
                        }

                        Text("\(store.selectedIntensity.sessionDurationMinutes) min session")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .padding()
                    .background(.ultraThinMaterial.opacity(0.3))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Related moods
                if !store.relatedMoods.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related moods that may appear")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))

                        HStack(spacing: 8) {
                            ForEach(store.relatedMoods) { mood in
                                HStack(spacing: 4) {
                                    Image(systemName: mood.icon)
                                        .font(.caption2)
                                    Text(mood.rawValue)
                                        .font(.caption)
                                }
                                .foregroundStyle(.white.opacity(0.7))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.1))
                                .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    if store.selectedMood != nil {
                        Button {
                            store.send(.startGeneration)
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Begin Dream")
                            }
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(store.selectedMood?.color ?? .white)
                            .cornerRadius(16)
                        }
                        .transition(.scale.combined(with: .opacity))
                    }

                    Button {
                        store.send(.showHistory)
                    } label: {
                        HStack {
                            Image(systemName: "clock.fill")
                            Text("Session History")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .animation(.spring(duration: 0.4), value: store.selectedMood)
    }
}

// MARK: - Mood Card

private struct MoodCard: View {
    let mood: Mood
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isSelected ? mood.color : mood.color.opacity(0.3))
                    .frame(width: 56, height: 56)

                Image(systemName: mood.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? .black : .white)
            }

            Text(mood.rawValue)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? .white.opacity(0.15) : .white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? mood.color : .clear, lineWidth: 2)
        )
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(duration: 0.3), value: isSelected)
    }
}

// MARK: - Intensity Button

private struct IntensityButton: View {
    let intensity: MoodIntensity
    let isSelected: Bool

    var body: some View {
        Text(intensity.rawValue)
            .font(.subheadline)
            .fontWeight(isSelected ? .semibold : .regular)
            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : Color.white.opacity(0.1))
            .cornerRadius(12)
    }
}

// MARK: - Generation View

private struct GenerationView: View {
    let store: StoreOf<DreamScapeFeature>

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Animated orb
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(
                            (store.selectedMood?.color ?? .white)
                                .opacity(0.3 - Double(i) * 0.1)
                        )
                        .frame(width: 120 + CGFloat(i) * 40,
                               height: 120 + CGFloat(i) * 40)
                        .blur(radius: CGFloat(i) * 5)
                }

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 40))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 12) {
                Text(store.generationPhase.rawValue)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                ProgressView(value: store.generationProgress)
                    .tint(store.selectedMood?.color ?? .white)
                    .frame(maxWidth: 200)

                Text("\(Int(store.generationProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }

            if let error = store.generationError {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("Try Again") {
                        store.send(.dismissError)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.2))
                    .cornerRadius(8)
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
    }
}

// MARK: - Playback View

private struct PlaybackView: View {
    let store: StoreOf<DreamScapeFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Scene display
            ZStack {
                if let scene = store.currentScene {
                    // Scene image or gradient placeholder
                    if let imagePath = scene.localImagePath,
                       let uiImage = UIImage(contentsOfFile: imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipped()
                    } else {
                        // Gradient placeholder with scene mood
                        LinearGradient(
                            colors: scene.mood.gradientColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }

                    // Caption overlay
                    VStack {
                        Spacer()

                        VStack(spacing: 8) {
                            Text(scene.title)
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .shadow(radius: 4)

                            if !scene.description.isEmpty {
                                Text(scene.description)
                                    .font(.body)
                                    .foregroundStyle(.white.opacity(0.85))
                                    .multilineTextAlignment(.center)
                                    .lineLimit(3)
                                    .shadow(radius: 2)
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity)
                        .background(
                            LinearGradient(
                                colors: [.clear, .black.opacity(0.6)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height * 0.55)
            .clipped()

            // Controls
            VStack(spacing: 20) {
                // Progress bar
                VStack(spacing: 4) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.white.opacity(0.2))
                                .frame(height: 4)

                            Capsule()
                                .fill(store.selectedMood?.color ?? .white)
                                .frame(width: geo.size.width * store.overallProgress, height: 4)
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text(store.formattedElapsed)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("Scene \(store.currentSceneIndex + 1)/\(store.generatedScenes.count)")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text(store.formattedRemaining)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // Playback controls
                HStack(spacing: 40) {
                    Button {
                        store.send(.previousScene)
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title2)
                            .foregroundStyle(store.canRewindScene ? .white : .white.opacity(0.3))
                    }
                    .disabled(!store.canRewindScene)

                    Button {
                        store.send(.togglePlayback)
                    } label: {
                        ZStack {
                            Circle()
                                .fill(store.selectedMood?.color ?? .white)
                                .frame(width: 64, height: 64)

                            Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                                .font(.title)
                                .foregroundStyle(.black)
                        }
                    }

                    Button {
                        store.send(.nextScene)
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title2)
                            .foregroundStyle(store.canAdvanceScene ? .white : .white.opacity(0.3))
                    }
                    .disabled(!store.canAdvanceScene)
                }

                // Ambient sound selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        // None button
                        AmbientChip(
                            icon: "speaker.slash.fill",
                            name: "None",
                            isSelected: store.selectedAmbientSound == nil
                        ) {
                            store.send(.selectAmbientSound(nil))
                        }

                        ForEach(AmbientSound.all) { sound in
                            AmbientChip(
                                icon: sound.icon,
                                name: sound.name,
                                isSelected: store.selectedAmbientSound?.id == sound.id
                            ) {
                                store.send(.selectAmbientSound(sound))
                            }
                        }
                    }
                }

                // Volume slider
                if store.selectedAmbientSound != nil {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.caption)

                        Slider(
                            value: Binding(
                                get: { Double(store.ambientVolume) },
                                set: { store.send(.setAmbientVolume(Float($0))) }
                            ),
                            in: 0...1
                        )
                        .tint(store.selectedMood?.color ?? .white)

                        Image(systemName: "speaker.wave.3.fill")
                            .foregroundStyle(.white.opacity(0.4))
                            .font(.caption)
                    }
                }

                // End session
                Button {
                    store.send(.endSession)
                } label: {
                    Text("End Session")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Ambient Chip

private struct AmbientChip: View {
    let icon: String
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? .black : .white.opacity(0.7))
            .frame(width: 60)
            .padding(.vertical, 8)
            .background(isSelected ? Color.white : .white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// MARK: - Reflection View

private struct ReflectionView: View {
    @Bindable var store: StoreOf<DreamScapeFeature>

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                Image(systemName: "sparkle")
                    .font(.system(size: 48))
                    .foregroundStyle(store.selectedMood?.color ?? .white)

                Text("Session Complete")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                if let session = store.session {
                    VStack(spacing: 8) {
                        HStack {
                            Label("\(session.scenes.count) scenes", systemImage: "photo.stack")
                            Spacer()
                            Label(formatDuration(session.durationSeconds), systemImage: "clock")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Mood rating
                VStack(spacing: 12) {
                    Text("How do you feel now?")
                        .font(.headline)
                        .foregroundStyle(.white)

                    HStack(spacing: 16) {
                        ForEach(1...5, id: \.self) { rating in
                            Button {
                                store.send(.setPostMoodRating(rating))
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: ratingIcon(rating))
                                        .font(.system(size: 32))
                                    Text(ratingLabel(rating))
                                        .font(.caption2)
                                }
                                .foregroundStyle(
                                    store.postMoodRating == rating
                                        ? (store.selectedMood?.color ?? .white)
                                        : .white.opacity(0.4)
                                )
                            }
                        }
                    }
                }

                // Reflection note
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reflection (optional)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))

                    TextField(
                        "What did you notice during this session?",
                        text: Binding(
                            get: { store.reflectionNote },
                            set: { store.send(.setReflectionNote($0)) }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                    .padding()
                    .background(.white.opacity(0.1))
                    .cornerRadius(12)
                    .foregroundStyle(.white)
                }
                .padding(.horizontal)

                // Submit
                Button {
                    store.send(.submitReflection)
                } label: {
                    Text("Save & Return")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(store.selectedMood?.color ?? .white)
                        .cornerRadius(16)
                }
                .padding(.horizontal)

                Button {
                    store.send(.returnToMoodSelection)
                } label: {
                    Text("Skip")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer(minLength: 40)
            }
        }
    }

    private func ratingIcon(_ rating: Int) -> String {
        switch rating {
        case 1: return "cloud.rain"
        case 2: return "cloud"
        case 3: return "sun.haze"
        case 4: return "sun.max"
        case 5: return "sparkles"
        default: return "circle"
        }
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "Low"
        case 2: return "Okay"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Great"
        default: return ""
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - History View

private struct HistoryView: View {
    let store: StoreOf<DreamScapeFeature>

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    store.send(.returnToMoodSelection)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

                Spacer()

                Text("Session History")
                    .font(.headline)
                    .foregroundStyle(.white)

                Spacer()

                // Spacer for symmetry
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(.clear)
            }
            .padding()

            if store.isLoadingHistory {
                Spacer()
                ProgressView()
                    .tint(.white)
                Spacer()
            } else if store.sessionHistory.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No dream sessions yet")
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.sessionHistory) { session in
                            HistoryRow(session: session)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        store.send(.deleteSession(session.id))
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

// MARK: - History Row

private struct HistoryRow: View {
    let session: DreamSession

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(session.mood.color.opacity(0.3))
                    .frame(width: 44, height: 44)

                Image(systemName: session.mood.icon)
                    .foregroundStyle(session.mood.color)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(session.mood.rawValue)
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 8) {
                    Text(session.intensity.rawValue)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))

                    Text("--")
                        .foregroundStyle(.white.opacity(0.3))

                    Text(formatDate(session.startedAt))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.status.rawValue)
                    .font(.caption2)
                    .foregroundStyle(
                        session.status == .completed ? .green : .white.opacity(0.5)
                    )

                if let rating = session.postMoodRating {
                    HStack(spacing: 2) {
                        ForEach(0..<rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.yellow)
                        }
                    }
                }
            }
        }
        .padding()
        .background(.white.opacity(0.08))
        .cornerRadius(12)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    DreamScapeView(
        store: Store(initialState: DreamScapeFeature.State()) {
            DreamScapeFeature()
        }
    )
}
