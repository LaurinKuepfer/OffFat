import SwiftData
import Foundation

extension ModelContext {
    /// Attempts to save the context and catches any errors.
    /// This prevents silent data loss that occurs when using `context.safeSave()`.
    func safeSave() {
        do {
            try self.save()
        } catch {
            print("âŒ Failed to save ModelContext: \(error.localizedDescription)")
            // In a production app, you might also want to log this to a crash reporter
            // like Crashlytics or Sentry, or show a user-facing alert.
        }
    }
}
