import Darwin
import Foundation

/// Blocks SIGTERM/SIGINT on every thread, then waits on a dedicated thread.
/// When killall / Activity Monitor Quit arrives, restore gaps before exiting.
enum TerminationGuard {
    private static var started = false

    static func install() {
        guard !started else { return }
        started = true

        var set = sigset_t()
        sigemptyset(&set)
        sigaddset(&set, SIGTERM)
        sigaddset(&set, SIGINT)
        // Block on this thread (and inherited by later threads) so signals
        // are delivered to sigwait instead of killing the process immediately.
        pthread_sigmask(SIG_BLOCK, &set, nil)

        let thread = Thread {
            var waitSet = sigset_t()
            sigemptyset(&waitSet)
            sigaddset(&waitSet, SIGTERM)
            sigaddset(&waitSet, SIGINT)
            var signal: Int32 = 0
            // Blocks until kill / Ctrl-C.
            _ = withUnsafeMutablePointer(to: &signal) { sigPtr in
                withUnsafePointer(to: &waitSet) { setPtr in
                    sigwait(setPtr, sigPtr)
                }
            }
            GapBoost.shared.deactivate()
            // Hard exit so we don't race AppKit teardown.
            _exit(0)
        }
        thread.name = "aerospace-tabs.termination"
        thread.qualityOfService = .userInitiated
        thread.start()
    }
}
