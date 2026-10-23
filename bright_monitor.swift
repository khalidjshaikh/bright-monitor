import Foundation

/// Runs a shell command and returns its stdout as a trimmed string.
func shell(_ command: String) -> String? {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]

    let pipe = Pipe()
    process.standardOutput = pipe

    do {
        try process.run()
        process.waitUntilExit()
    } catch {
        print("❌ Failed to run command: \(error)")
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

/// Parse brightness percentage from `bright` output, e.g. "66%" -> 66.0
func getBrightnessLevel() -> Float? {
    guard let output = shell("bright") else { return nil }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    // Remove trailing '%' if present
    let percentStr = trimmed.hasSuffix("%") ? String(trimmed.dropLast()) : trimmed
    return Float(percentStr)
}

/// Parses a positive interval in seconds, returning nil if the value is invalid.
func parseInterval(_ value: String) -> TimeInterval? {
    guard let seconds = TimeInterval(value), seconds.isFinite, seconds > 0 else { return nil }
    return seconds
}

/// Formats an interval for user-facing messages, e.g. 30 -> "30 seconds".
func formatInterval(_ seconds: TimeInterval) -> String {
    if seconds == seconds.rounded() {
        let whole = Int(seconds)
        return "\(whole) second\(whole == 1 ? "" : "s")"
    }
    return "\(seconds) seconds"
}

/// Prints command usage information.
func printUsage() {
    print("""
    🔆 bright_monitor — keeps display brightness pinned at 100%.

    USAGE:
        bright_monitor [options]

    OPTIONS:
        -h, --help              Show this help message and exit.
        -i, --interval <secs>   Seconds between brightness checks (default: 30).

    BEHAVIOR:
        Periodically (default: every 30 seconds), reads the current brightness
        with `bright` and, if it is below 100%, sets it back to 100%.

    REQUIREMENTS:
        The `bright` utility must be installed and on your PATH.

    Press Ctrl+C to stop.
    """)
}

/// Validates an interval argument, exiting with usage information on failure.
func requireInterval(_ value: String, for option: String) -> TimeInterval {
    if value.isEmpty {
        print("❌ Missing value for \(option)\n")
        printUsage()
        exit(1)
    }
    guard let seconds = parseInterval(value) else {
        print("❌ Invalid interval: \(value) — expected a positive number of seconds\n")
        printUsage()
        exit(1)
    }
    return seconds
}

// ── Argument Parsing ───────────────────────────────────────
let defaultInterval: TimeInterval = 30.0
var interval: TimeInterval = defaultInterval

var arguments = CommandLine.arguments.dropFirst().makeIterator()
while let argument = arguments.next() {
    switch argument {
    case "-h", "--help":
        printUsage()
        exit(0)
    case "-i", "--interval":
        guard let value = arguments.next() else {
            print("❌ Missing value for \(argument)\n")
            printUsage()
            exit(1)
        }
        interval = requireInterval(value, for: argument)
    default:
        guard argument.hasPrefix("--interval=") else {
            print("❌ Unknown argument: \(argument)\n")
            printUsage()
            exit(1)
        }
        let value = String(argument.dropFirst("--interval=".count))
        interval = requireInterval(value, for: "--interval")
    }
}

// ── Main Loop ──────────────────────────────────────────────
print("🔆 Brightness Monitor started — checking every \(formatInterval(interval)).")
print("   Press Ctrl+C to stop.\n")

// Use a DispatchSource signal handler for clean shutdown
let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
signalSource.setEventHandler {
    print("\n👋 Shutting down.")
    exit(0)
}
signalSource.resume()

// Block SIGINT so DispatchSource can handle it
signal(SIGINT, SIG_IGN)

// Timer loop
Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
    guard let level = getBrightnessLevel() else {
        print("⚠️  Could not read brightness level.")
        return
    }

    let time = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
    print("[\(time)] Brightness: \(level)%")

    if level < 100 {
        print("        ↓ Below 100%, setting to 100%")
        _ = shell("bright 100")
    }
}

// Keep the run loop alive
RunLoop.main.run()
