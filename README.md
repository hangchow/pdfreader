# PDF Reader

SwiftUI + PDFKit iOS reader. The library screen scans PDF files from an iCloud Drive folder selected by the user, stores reading progress locally, and keeps file rename/delete outside the app.

## Usage

1. Open `PDFReader.xcodeproj` in Xcode.
2. Run the `PDFReader` scheme on iPhone or Simulator.
3. On first launch, choose the `pdfreader` folder in iCloud Drive.

The app stores a bookmark for that folder so later launches can refresh the library without asking again. Reading progress and reader preferences are stored in `UserDefaults`.

PDF pages are fixed-layout. In PDF mode the size control changes zoom; switch to text mode when you want the selected font and text size to affect extracted text.
