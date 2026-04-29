import SwiftUI

@main
struct PDFReaderApp: App {
    @StateObject private var library = BookLibrary()
    @StateObject private var progressStore = ProgressStore()
    @StateObject private var preferencesStore = ReaderPreferencesStore()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environmentObject(library)
                .environmentObject(progressStore)
                .environmentObject(preferencesStore)
        }
    }
}
