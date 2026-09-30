import Foundation

/// Crash isolation: config load, template render, lifecycle edges, and host callback boundaries.
enum DelightFailSafe {
    static func run(_ operation: () -> Void) {
        operation()
    }

    static func run(_ operation: () throws -> Void, onFailure: (Error) -> Void) {
        do {
            try operation()
        } catch {
            onFailure(error)
        }
    }

    static func run(_ operation: () throws -> Void) {
        run(operation) { error in
            DelightFailSafeLog.debug("Caught error: \(error.localizedDescription)")
        }
    }

    static func runAsync(
        _ operation: () async throws -> Void,
        onFailure: @escaping (Error) -> Void
    ) async {
        do {
            try await operation()
        } catch {
            onFailure(error)
        }
    }

    static func runAsync(_ operation: () async throws -> Void) async {
        await runAsync(operation) { error in
            DelightFailSafeLog.debug("Caught async error: \(error.localizedDescription)")
        }
    }
}

/// When initialization throws, the SDK behaves as if it were not installed for the rest of the process.
@MainActor
enum DelightSessionGuard {
    private(set) static var isDisabledForSession = false

    static var shouldNoOpPublicAPI: Bool {
        isDisabledForSession
    }

    static func disableAfterInitializationFailure(_ reason: String) {
        isDisabledForSession = true
        DelightFailSafeLog.debug("Session disabled after init failure: \(reason)")
    }

    static func resetForTesting() {
        isDisabledForSession = false
    }
}

/// Host callbacks must never take down the host app if the partner code throws.
enum DelightHostCallbacks {
    static func invokeImpression(_ callback: ((String?) -> Void)?, rewardId: String?) {
        guard let callback else { return }
        DelightFailSafe.run { callback(rewardId) }
    }

    static func invokePrimaryClick(_ callback: ((String?) -> Void)?, rewardId: String?) {
        guard let callback else { return }
        DelightFailSafe.run { callback(rewardId) }
    }

    static func invokeDismiss(_ callback: (() -> Void)?) {
        guard let callback else { return }
        DelightFailSafe.run { callback() }
    }
}

enum DelightFailSafeLog {
    static func debug(_ message: String) {
#if DEBUG
        print("Delight fail-safe:", message)
#endif
    }

    static func sdkError(_ message: String) {
#if DEBUG
        print("Delight SDK Error:", message)
#endif
    }
}

#if DEBUG
enum DelightRuntimeTestFlags {
    /// When true, popup template body is skipped (simulates render failure path).
    static var suppressTemplateBody = false
}
#else
enum DelightRuntimeTestFlags {
    static var suppressTemplateBody = false
}
#endif
