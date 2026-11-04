import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Speaks a short message through VoiceOver (does nothing when it is off).
/// Used for things that otherwise only show: a scan result, a status line.
enum Announcer {
    static func post(_ text: String, urgent: Bool = false) {
        #if os(macOS)
        let priority = urgent ? NSAccessibilityPriorityLevel.high : .medium
        NSAccessibility.post(
            element: NSApp as Any, notification: .announcementRequested,
            userInfo: [.announcement: text, .priority: priority.rawValue])
        #else
        UIAccessibility.post(notification: .announcement, argument: text)
        #endif
    }
}
