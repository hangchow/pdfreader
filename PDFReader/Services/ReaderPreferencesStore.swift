import Foundation

@MainActor
final class ReaderPreferencesStore: ObservableObject {
    @Published var preferences: ReaderPreferences {
        didSet { save() }
    }

    private let defaults = UserDefaults.standard
    private let key = "pdfreader.reader.preferences"

    init() {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode(ReaderPreferences.self, from: data) {
            preferences = decoded
        } else {
            preferences = ReaderPreferences()
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(preferences) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}
