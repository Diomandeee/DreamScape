import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("DreamScape")
                    .font(.largeTitle.bold())

                Text("Welcome to DreamScape")
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("DreamScape")
        }
    }
}

#Preview {
    ContentView()
}
