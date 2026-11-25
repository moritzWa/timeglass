import Foundation

@main struct ModelTests {
    static func main() throws {
        let valid: [(String, Double)] = [("10m", 600), ("90s", 90), ("1h 30m", 5400),
            ("1h30m15s", 5415), (" 10M ", 600), ("10", 600), ("1.5m", 90), ("1s", 1)]
        for (input, expected) in valid { precondition(DurationParser.seconds(input) == expected, input) }
        for input in ["", "0", "0s", "-1m", "0.1s", "10mx", "abc10m", "1m 2m", "1:30", "inf", "nan", "999999999999999999h"] {
            precondition(DurationParser.seconds(input) == nil, "Must reject: \(input)")
        }
        precondition(countdown(600) == "10:00")
        precondition(countdown(3661) == "1:01:01")
        precondition(countdown(0) == "0:00")
        let now = Date(timeIntervalSince1970: 1000)
        let timer = ActiveTimer(id: "synthetic", deadline: now.addingTimeInterval(600), input: "10m")
        precondition(timer.remaining(at: now) == 600)
        precondition(timer.remaining(at: now.addingTimeInterval(599.2)) == 1)
        precondition(timer.remaining(at: now.addingTimeInterval(900)) == 0)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("timeglass-test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = TimerStore(url: folder.appendingPathComponent("timer.json"))
        let empty = try store.load()
        precondition(empty == nil)
        try store.save(timer)
        let loaded = try store.load()
        precondition(loaded == timer)
        try store.save(nil)
        let stopped = try store.load()
        precondition(stopped == nil)
        print("PASS: duration parsing, countdown, wall-clock deadlines, persistence and cancellation")
    }
}
