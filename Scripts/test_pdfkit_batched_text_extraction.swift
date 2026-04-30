import Foundation

let arguments = CommandLine.arguments
guard arguments.count >= 2 else {
    fputs("usage: test_pdfkit_batched_text_extraction <pdf> [batch_size] [max_pages]\n", stderr)
    Foundation.exit(2)
}

let scriptURL = URL(fileURLWithPath: arguments[0]).standardizedFileURL
let repositoryURL = scriptURL.deletingLastPathComponent().deletingLastPathComponent()
let outputDirectoryURL = repositoryURL.appendingPathComponent("output", isDirectory: true)
let extractorURL = repositoryURL.appendingPathComponent("PDFReader/Services/PDFTextExtractor.swift")
let runnerSourceURL = outputDirectoryURL.appendingPathComponent(".pdfreader-extraction-runner.swift")
let runnerExecutableURL = outputDirectoryURL.appendingPathComponent(".pdfreader-extraction-runner")

let pdfURL = URL(fileURLWithPath: arguments[1]).standardizedFileURL
let outputURL = outputDirectoryURL
    .appendingPathComponent(pdfURL.deletingPathExtension().lastPathComponent)
    .appendingPathExtension("txt")
let batchSize = arguments.count >= 3 ? max(Int(arguments[2]) ?? PDFTextExtractionDefaults.batchSize, 1) : PDFTextExtractionDefaults.batchSize
let maxPages = arguments.count >= 4 ? arguments[3] : ""

try FileManager.default.createDirectory(at: outputDirectoryURL, withIntermediateDirectories: true)
try writeRunnerSource(to: runnerSourceURL)
defer {
    try? FileManager.default.removeItem(at: runnerSourceURL)
    try? FileManager.default.removeItem(at: runnerExecutableURL)
}

try run(
    executable: "/usr/bin/env",
    arguments: [
        "swiftc",
        "-parse-as-library",
        runnerSourceURL.path,
        extractorURL.path,
        "-o",
        runnerExecutableURL.path
    ]
)

try run(
    executable: runnerExecutableURL.path,
    arguments: [
        pdfURL.path,
        outputURL.path,
        String(batchSize),
        maxPages
    ]
)

private enum PDFTextExtractionDefaults {
    static let batchSize = 50
}

private func writeRunnerSource(to url: URL) throws {
    let source = #"""
import Foundation

@main
struct PDFTextExtractionRunner {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 4 else {
            fputs("usage: .pdfreader-extraction-runner <pdf> <txt> <batch_size> [max_pages]\n", stderr)
            Foundation.exit(2)
        }

        let pdfURL = URL(fileURLWithPath: arguments[1])
        let outputURL = URL(fileURLWithPath: arguments[2])
        let batchSize = max(Int(arguments[3]) ?? PDFTextExtractor.defaultBatchSize, 1)
        let maxPages = arguments.count >= 5 && arguments[4].isEmpty == false ? Int(arguments[4]) : nil

        let startedAt = Date()
        try await PDFTextExtractor.generateTextFile(from: pdfURL, to: outputURL, batchSize: batchSize, maxPages: maxPages) { progress in
            print("progress=\(String(format: "%.1f", progress * 100))%")
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        print("done elapsed=\(String(format: "%.2f", elapsed))s output=\(outputURL.path)")
    }
}
"""#

    try source.write(to: url, atomically: true, encoding: .utf8)
}

private func run(executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
        Foundation.exit(process.terminationStatus)
    }
}
