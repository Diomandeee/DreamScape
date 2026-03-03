import Foundation
import ComposableArchitecture

// MARK: - Scene Generator Client

/// TCA dependency client that generates scene descriptions and images via Gemini API.
/// Modeled after Serenity Soother's VertexAIService, adapted as a TCA DependencyKey.
@DependencyClient
struct SceneGeneratorClient: Sendable {
    /// Generate a complete scene description from a mood blend
    var generateScene: @Sendable (MoodBlend, Int) async throws -> SceneState
    /// Generate an image URL for a scene description
    var generateImage: @Sendable (String) async throws -> String?
    /// Generate narration text for a scene
    var generateNarration: @Sendable (SceneState) async throws -> String
}

extension SceneGeneratorClient: DependencyKey {
    static let liveValue: SceneGeneratorClient = {
        let apiKey = ProcessInfo.processInfo.environment["GOOGLE_API_KEY"] ?? ""

        return SceneGeneratorClient(
            generateScene: { blend, index in
                let prompt = buildScenePrompt(blend: blend, index: index)
                let response = try await callGemini(prompt: prompt, apiKey: apiKey)
                return parseSceneResponse(response, blend: blend, index: index)
            },
            generateImage: { description in
                try await generateImageWithImagen(description: description, apiKey: apiKey)
            },
            generateNarration: { scene in
                let prompt = buildNarrationPrompt(scene: scene)
                return try await callGemini(prompt: prompt, apiKey: apiKey)
            }
        )
    }()

    static let testValue = SceneGeneratorClient(
        generateScene: { blend, index in
            SceneState(
                title: "Dream Scene \(index + 1)",
                description: "A \(blend.primary.rawValue.lowercased()) dreamscape unfolds...",
                mood: blend.dominant,
                narrationText: "Close your eyes and breathe deeply...",
                duration: 60,
                orderIndex: index
            )
        },
        generateImage: { _ in nil },
        generateNarration: { scene in
            "In this \(scene.mood.rawValue.lowercased()) space, let yourself drift..."
        }
    )
}

extension DependencyValues {
    var sceneGenerator: SceneGeneratorClient {
        get { self[SceneGeneratorClient.self] }
        set { self[SceneGeneratorClient.self] = newValue }
    }
}

// MARK: - Gemini API Integration

private func callGemini(prompt: String, apiKey: String) async throws -> String {
    guard !apiKey.isEmpty else {
        // Fallback for development without API key
        return generateFallbackScene(prompt: prompt)
    }

    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=\(apiKey)")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 30

    let body: [String: Any] = [
        "contents": [
            [
                "parts": [
                    ["text": prompt]
                ]
            ]
        ],
        "generationConfig": [
            "temperature": 0.8,
            "maxOutputTokens": 1024,
            "topP": 0.9,
        ]
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        throw SceneGenerationError.apiError("Gemini API returned non-200 status")
    }

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let candidates = json["candidates"] as? [[String: Any]],
          let content = candidates.first?["content"] as? [String: Any],
          let parts = content["parts"] as? [[String: Any]],
          let text = parts.first?["text"] as? String else {
        throw SceneGenerationError.parseError("Failed to parse Gemini response")
    }

    return text
}

private func generateImageWithImagen(description: String, apiKey: String) async throws -> String? {
    guard !apiKey.isEmpty else { return nil }

    // Use Imagen 4.0 (NOT 3.0 which 404s)
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:generateImages?key=\(apiKey)")!

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.timeoutInterval = 60

    let imagePrompt = "Dreamlike immersive scene: \(description). Style: ethereal digital art, high detail, atmospheric lighting, 16:9 aspect ratio, no text or UI elements."

    let body: [String: Any] = [
        "instances": [
            ["prompt": imagePrompt]
        ],
        "parameters": [
            "sampleCount": 1
        ]
    ]

    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse,
          (200...299).contains(httpResponse.statusCode) else {
        return nil
    }

    // Parse image response and return base64 data URI or URL
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let predictions = json["predictions"] as? [[String: Any]],
          let base64Image = predictions.first?["bytesBase64Encoded"] as? String else {
        return nil
    }

    // Save to local file for playback
    let fileName = "dreamscape_\(UUID().uuidString.prefix(8)).png"
    let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let fileURL = documentsDir.appendingPathComponent(fileName)

    if let imageData = Data(base64Encoded: base64Image) {
        try imageData.write(to: fileURL)
        return fileURL.path
    }

    return nil
}

// MARK: - Prompt Builders

private func buildScenePrompt(blend: MoodBlend, index: Int) -> String {
    """
    You are a dreamscape architect. Generate a vivid scene description for an immersive \
    meditation experience.

    Scene number: \(index + 1)
    Primary mood: \(blend.primary.rawValue) (weight: \(String(format: "%.0f%%", blend.primaryWeight * 100)))
    Secondary mood: \(blend.secondary.rawValue) (weight: \(String(format: "%.0f%%", blend.secondaryWeight * 100)))
    Visual hints: \(blend.promptHint)

    Respond with ONLY a JSON object (no markdown):
    {
      "title": "short evocative title (3-5 words)",
      "description": "rich visual description of the scene (2-3 sentences)",
      "narration": "soothing guided meditation narration for this scene (3-4 sentences, second person)"
    }
    """
}

private func buildNarrationPrompt(scene: SceneState) -> String {
    """
    Write a soothing, immersive narration for a meditation scene.

    Scene title: \(scene.title)
    Scene description: \(scene.description)
    Mood: \(scene.mood.rawValue)

    Write 3-4 sentences in second person ("you"), using a gentle, guiding tone.
    Focus on sensory details and breathing awareness.
    """
}

// MARK: - Fallback Generation

private func generateFallbackScene(prompt: String) -> String {
    // Return a pre-built scene JSON when no API key is available
    let fallbackScenes = [
        """
        {"title":"Moonlit Glade","description":"A clearing bathed in silver moonlight, where luminous flowers sway in an invisible breeze. Fireflies trace slow spirals between ancient oaks.","narration":"You step into a clearing where moonlight pools like liquid silver. The air carries the faint perfume of night-blooming jasmine. With each breath, you feel the gentle pulse of this ancient place welcoming you home."}
        """,
        """
        {"title":"Crystal Cavern","description":"A vast underground chamber where crystalline formations catch and refract light into prismatic rainbows. Still water mirrors the ceiling of glowing stalactites.","narration":"You descend into a cavern of crystalline wonder. Each formation hums with a frequency you can feel in your chest. The still pool at your feet reflects infinite colors, and you realize this place has been waiting for you."}
        """,
        """
        {"title":"Cloud Observatory","description":"A platform floating above a sea of golden clouds at sunset. The horizon stretches endlessly, painted in amber and rose.","narration":"You stand at the edge of the sky, clouds stretching below like a golden ocean. The last rays of sun warm your face. Here, above everything, your thoughts can simply drift and dissolve into the vast expanse."}
        """,
        """
        {"title":"Emerald Sanctuary","description":"A hidden garden where moss-covered stones form a natural amphitheater. A gentle waterfall feeds a pool surrounded by ferns and wildflowers.","narration":"You find yourself in a secret garden where water whispers over ancient stones. Ferns unfurl their delicate fronds as you pass. Let each drop of the waterfall carry away one small weight you have been holding."}
        """,
        """
        {"title":"Starfield Meadow","description":"An alpine meadow under a sky dense with stars. Bioluminescent grasses glow faintly, creating a mirror of the cosmos on the ground.","narration":"You lie in soft grass that glows with its own gentle light, a mirror of the star field above. The boundary between earth and sky dissolves. Breathe in starlight, breathe out the day. You are held between two infinities."}
        """,
    ]

    return fallbackScenes[Int.random(in: 0..<fallbackScenes.count)]
}

// MARK: - Response Parsing

private func parseSceneResponse(_ response: String, blend: MoodBlend, index: Int) -> SceneState {
    // Try to parse JSON from the response
    let cleaned = response
        .replacingOccurrences(of: "```json", with: "")
        .replacingOccurrences(of: "```", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)

    if let data = cleaned.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
        return SceneState(
            title: json["title"] ?? "Dream Scene \(index + 1)",
            description: json["description"] ?? blend.promptHint,
            mood: blend.dominant,
            narrationText: json["narration"] ?? "",
            duration: 60,
            orderIndex: index
        )
    }

    // Fallback if parsing fails
    return SceneState(
        title: "Dream Scene \(index + 1)",
        description: response.prefix(200).description,
        mood: blend.dominant,
        narrationText: "",
        duration: 60,
        orderIndex: index
    )
}

// MARK: - Errors

enum SceneGenerationError: Error, LocalizedError {
    case apiError(String)
    case parseError(String)
    case imageGenerationFailed
    case noApiKey

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return "API Error: \(msg)"
        case .parseError(let msg): return "Parse Error: \(msg)"
        case .imageGenerationFailed: return "Image generation failed"
        case .noApiKey: return "No API key configured"
        }
    }
}
