import Foundation

extension String {
    /// This English text as the app shows it in the current language, per `Localizable.xcstrings`; English as written
    /// where there's no translation yet.
    var localized: String { NSLocalizedString(self, comment: "") }
}
