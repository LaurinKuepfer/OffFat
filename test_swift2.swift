import Foundation
func test(_ key: String.LocalizationValue) {
    let s = String(localized: key, locale: Locale(identifier: "fr"))
}
