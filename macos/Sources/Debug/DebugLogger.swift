// DebugLogger — AGENTS.md 19장 표준 로거 (macOS)
// [HH:mm:ss.SSS] [LEVEL] [FEATURE] 메시지 | meta
import Foundation

enum LogLevel: String {
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
    case perf = "PERF"
    case cache = "CACHE"
    case feature = "FEATURE"
}

final class DebugLogger {
    static let shared = DebugLogger()
    private let lock = NSLock()
    private var buffer: [String] = []
    private let maxLines = 500
    private let fileHandle: FileHandle?

    private init() {
        let logDir = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: logDir, withIntermediateDirectories: true)
        let logURL = logDir.appendingPathComponent("Wordville.log")
        if !FileManager.default.fileExists(atPath: logURL.path) {
            FileManager.default.createFile(atPath: logURL.path, contents: nil)
        }
        fileHandle = try? FileHandle(forWritingTo: logURL)
        fileHandle?.seekToEndOfFile()
    }

    func log(_ level: LogLevel, _ feature: String?, _ message: String, meta: [String: Any]? = nil) {
        let ts = Self.timestamp()
        let featureTag = feature.map { "[\($0)] " } ?? ""
        var line = "[\(ts)] [\(level.rawValue)] \(featureTag)\(message)"
        if let meta, !meta.isEmpty {
            line += " | \(meta)"
        }
        lock.lock()
        buffer.append(line)
        if buffer.count > maxLines { buffer.removeFirst(buffer.count - maxLines) }
        if let handle = fileHandle {
            handle.write((line + "\n").data(using: .utf8)!)
        }
        lock.unlock()
        print(line)
    }

    static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f.string(from: Date())
    }

    func lines() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return buffer
    }

    func clear() {
        lock.lock()
        buffer.removeAll()
        lock.unlock()
    }

    // 신규 기능 로그 의무화 (AGENTS.md 19.1): [INFO] [FEATURE] <기능명> 진입/완료
    func feature(_ name: String, _ message: String, meta: [String: Any]? = nil) {
        log(.feature, name, message, meta: meta)
    }
}