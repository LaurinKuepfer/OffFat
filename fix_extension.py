import re

file_path = "/Users/laurin/Macroad/Macrode/Engines/ReviewEngine.swift"
with open(file_path, "r") as f:
    content = f.read()

# Replace the broken extension
broken = """extension String {
    static func localizing(_ key: String.LocalizationValue) -> String {
        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
        if appLanguage == "system" {
            return String.localizing( key)
        } else {
            return String.localizing( key, locale: Locale(identifier: appLanguage))
        }
    }
}"""

fixed = """extension String {
    static func localizing(_ key: String.LocalizationValue) -> String {
        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
        if appLanguage == "system" {
            return String(localized: key)
        } else {
            return String(localized: key, locale: Locale(identifier: appLanguage))
        }
    }
}"""

content = content.replace(broken, fixed)

with open(file_path, "w") as f:
    f.write(content)

