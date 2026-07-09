<div align="center">
  <img src="https://img.shields.io/badge/Platform-iOS%2017.0+-blue?style=for-the-badge&logo=apple" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-Swift%205.9-orange?style=for-the-badge&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/License-Dual%20License-green?style=for-the-badge" alt="License" />
</div>

<br/>

<div align="center">
  <h1>Macrode</h1>
  <p><strong>An offline macronutrient and calorie tracker for iOS.</strong></p>
</div>

<br/>

Macrode is an iOS application for tracking macronutrients and calories. It stores all data locally on the device using SwiftData, requiring no user accounts or external database servers.

---

### Application Previews

> *(Add app screenshots or a GIF here)*

---

## Core Features

### Dietary & Health Tracking
- **Logging:** Track calories, protein, carbohydrates, and fats.
- **Local Database:** Includes a database of common whole foods and generic restaurant items.
- **Recipes:** Combine ingredients into reusable meal entries to automatically calculate total macros.
- **Barcode Scanning:** Uses VisionKit to scan barcodes and retrieve nutritional data.
- **Daily Metrics:** Track daily water intake, body weight, and dietary supplements.

### Algorithms
- **TDEE Calculation:** Analyzes 14-day historical weight trends against caloric intake to estimate Total Daily Energy Expenditure.
- **Mifflin-St. Jeor Onboarding:** Calculates baseline macro targets based on height, weight, age, biological sex, and physical activity level.

### System Integration
- **Apple HealthKit:** Synchronize consumed dietary metrics to the Apple Health app.
- **WidgetKit & Live Activities:** Homescreen and lockscreen widgets for daily macronutrient progress.
- **Local Notifications:** Scheduled push notifications for hydration and supplement reminders.

### Data Management
- **CSV Export/Import:** Export meal history to a `.csv` file and restore it to ensure data portability.

---

## Technical Stack

- **Language:** Swift 5.9
- **Minimum OS:** iOS 17.0+
- **Architecture:** MVVM
- **User Interface:** SwiftUI, Swift Charts
- **Persistence:** SwiftData (SQLite)
- **Extensions:** WidgetKit
- **Hardware APIs:** VisionKit, UIImpactFeedbackGenerator
- **Networking:** URLSession (for Open Food Facts API queries)

---

## Build Instructions

### Prerequisites
- macOS Sonoma (14.0) or later
- Xcode 15.0 or later
- Physical iPhone (recommended for testing barcode scanning)

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/LaurinKuepfer/Macrode.git
   ```
2. Open `Macrode.xcodeproj` in Xcode.
3. In **Signing & Capabilities**, assign your Apple Developer account to both the `Macrode` and `MacrodeWidgetExtension` targets.
4. Update the **App Group** identifier to match across both targets (e.g., `group.com.yourname.macrode`).
5. Build and run (`Cmd + R`).

---

## Support & Attribution

If you would like to support the development:  
[Support Macrode on Ko-fi](https://ko-fi.com/laurinkuepfer)

**Attribution:** Barcode lookup uses the [Open Food Facts](https://world.openfoodfacts.org/) database.

## License

Please review the included `LICENSE` and `EULA.md` files for terms of use and distribution.
