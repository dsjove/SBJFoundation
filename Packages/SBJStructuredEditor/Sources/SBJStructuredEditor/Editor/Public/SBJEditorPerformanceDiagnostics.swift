import SBJUIVocabulary
import SBJUnits
#if !os(tvOS) && !os(watchOS)
import Foundation

/// DEBUG-only console diagnostics for root structured-editor work.
/// Logs individual operations taking >= 5 ms, plus a summary every 100 calls
/// so that many inexpensive evaluations are also observable.
@MainActor
enum SBJEditorPerformanceDiagnostics {
    /// Explicitly enable the expensive full projection preflight when diagnosing
    /// descriptor integrity. Normal editing skips it entirely.
    static var isProjectionAuditEnabled = false

#if DEBUG
    private struct Statistics {
        var count = 0
        var totalMilliseconds = 0.0
        var maxMilliseconds = 0.0
    }

    private static var statistics: [String: Statistics] = [:]
    private static let slowThresholdMilliseconds = 5.0
    private static let summaryInterval = 100
#endif

    static func measure<Result>(_ name: StaticString, _ operation: () -> Result) -> Result {
#if DEBUG
        let start = ProcessInfo.processInfo.systemUptime
        let result = operation()
        let elapsedMilliseconds = (ProcessInfo.processInfo.systemUptime - start) * 1_000
        let operationName = String(describing: name)

        var stats = statistics[operationName, default: Statistics()]
        stats.count += 1
        stats.totalMilliseconds += elapsedMilliseconds
        stats.maxMilliseconds = max(stats.maxMilliseconds, elapsedMilliseconds)
        statistics[operationName] = stats

        if elapsedMilliseconds >= slowThresholdMilliseconds {
            NSLog("[SBJEditorPerformance] %@ call #%ld: %.2f ms", operationName, stats.count, elapsedMilliseconds)
        }
        if stats.count % summaryInterval == 0 {
            NSLog("[SBJEditorPerformance] %@ after %ld calls: average %.2f ms, max %.2f ms, total %.2f ms", operationName, stats.count, stats.totalMilliseconds / Double(stats.count), stats.maxMilliseconds, stats.totalMilliseconds)
        }
        return result
#else
        return operation()
#endif
    }
}
#endif
