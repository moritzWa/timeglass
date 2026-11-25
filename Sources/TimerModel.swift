import Foundation

enum DurationParser {
    static func seconds(_ input: String) -> TimeInterval? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !text.isEmpty else { return nil }
        if let minutes = Double(text), minutes.isFinite {
            return valid(minutes * 60)
        }
        let regex = try! NSRegularExpression(pattern: #"(\d+(?:\.\d+)?)\s*([hms])"#)
        let source = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: source.length))
        guard !matches.isEmpty else { return nil }
        var end = 0
        var total = 0.0
        var units = Set<String>()
        for match in matches {
            let gap = source.substring(with: NSRange(location: end, length: match.range.location - end))
            guard gap.trimmingCharacters(in: .whitespaces).isEmpty,
                  let amount = Double(source.substring(with: match.range(at: 1))) else { return nil }
            let unit = source.substring(with: match.range(at: 2))
            guard units.insert(unit).inserted else { return nil }
            total += amount * (unit == "h" ? 3600 : unit == "m" ? 60 : 1)
            end = match.range.location + match.range.length
        }
        guard source.substring(from: end).trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return valid(total)
    }

    private static func valid(_ seconds: Double) -> Double? {
        seconds.isFinite && seconds >= 1 && seconds <= 365 * 86400 ? seconds : nil
    }
}

struct ActiveTimer: Codable, Equatable {
    let id: String
    let deadline: Date
    let input: String

    func remaining(at date: Date = Date()) -> Int {
        max(0, Int(ceil(deadline.timeIntervalSince(date))))
    }
}

func countdown(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let rest = seconds % 60
    return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, rest)
                     : String(format: "%d:%02d", minutes, rest)
}

struct TimerStore {
    let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Timeglass/timer.json")
    }

    func load() throws -> ActiveTimer? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try JSONDecoder().decode(ActiveTimer.self, from: Data(contentsOf: url))
    }

    func save(_ timer: ActiveTimer?) throws {
        guard let timer else {
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            return
        }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        try JSONEncoder().encode(timer).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
