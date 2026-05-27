import AppKit
import ApplicationServices

/// Accessibility access is needed to focus a specific window of an app
/// (e.g. raise the topmost window of Slack rather than just activating
/// the app). Without it the fallback is `NSRunningApplication.activate`.
enum AccessibilityPermissions {
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Prompts the user with the system dialog. Returns the current
    /// trust state — usually false on first call; the user must approve
    /// in System Settings → Privacy & Security → Accessibility.
    @discardableResult
    static func promptIfNeeded() -> Bool {
        // Hardcoded to avoid touching the C global `kAXTrustedCheckOptionPrompt`
        // (Swift treats imported `var` globals as non-Sendable shared state).
        let opts: CFDictionary = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }
}
