import Foundation
import SwiftData

struct ReviewData: Identifiable {
    let id = UUID()
    let days: Int
    let averageCalorieTarget: Double
    let averageCalorieIntake: Double
    let daysGoalMet: Int
    let bestMacroName: String
    let bestMacroPercentage: Double
    let weightChange: Double? // Positive means gained, negative means lost
    let motivationalMessage: String
    let analysisMessage: String
}

class ReviewEngine {
    
    struct ReviewStats {
        let avgTarget: Double
        let avgIntake: Double
        let successfulDays: Int
        let proRatio: Double
        let carbRatio: Double
        let fatRatio: Double
    }
    
    static func generateReview(days: Int, logs: [DailyLog], meals: [ConsumedMeal]) -> ReviewData {
        let (validLogs, dailyMeals, daysToCount) = filterAndGroup(days: days, logs: logs, meals: meals)
        
        let stats = calculateStats(validLogs: validLogs, dailyMeals: dailyMeals, daysToCount: daysToCount)
        let bestMacro = calculateBestMacro(stats: stats)
        let weightChange = calculateWeightChange(validLogs: validLogs)
        let message = generateMotivationalMessage(successfulDays: stats.successfulDays, daysToCount: daysToCount, isEmpty: validLogs.isEmpty)
        let analysis = generateAnalysisMessage(avgTarget: stats.avgTarget, avgIntake: stats.avgIntake)
        
        return ReviewData(
            days: days,
            averageCalorieTarget: stats.avgTarget,
            averageCalorieIntake: stats.avgIntake,
            daysGoalMet: stats.successfulDays,
            bestMacroName: bestMacro.name,
            bestMacroPercentage: bestMacro.ratio * 100,
            weightChange: weightChange,
            motivationalMessage: message,
            analysisMessage: analysis
        )
    }
    
    private static func filterAndGroup(days: Int, logs: [DailyLog], meals: [ConsumedMeal]) -> ([DailyLog], [Date: [ConsumedMeal]], Int) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -days, to: todayStart)!
        
        var validLogs = [DailyLog]()
        for log in logs {
            let logStart = calendar.startOfDay(for: log.date)
            if logStart >= startDate && logStart < todayStart {
                validLogs.append(log)
            }
        }
        
        var dailyMeals = [Date: [ConsumedMeal]]()
        for meal in meals {
            let mealStart = calendar.startOfDay(for: meal.consumedAt)
            if mealStart >= startDate && mealStart < todayStart {
                dailyMeals[mealStart, default: []].append(meal)
            }
        }
        
        let daysToCount = max(1, validLogs.count)
        return (validLogs, dailyMeals, daysToCount)
    }
    
    private static func calculateStats(validLogs: [DailyLog], dailyMeals: [Date: [ConsumedMeal]], daysToCount: Int) -> ReviewStats {
        var totalTargetCals: Double = 0
        var totalIntakeCals: Double = 0
        var totalProTarget: Double = 0, totalProIntake: Double = 0
        var totalCarbTarget: Double = 0, totalCarbIntake: Double = 0
        var totalFatTarget: Double = 0, totalFatIntake: Double = 0
        var successfulDays = 0
        
        let calendar = Calendar.current
        
        for log in validLogs {
            let logStart = calendar.startOfDay(for: log.date)
            let dayMeals = dailyMeals[logStart] ?? []
            
            let dailyTotals = dayMeals.reduce(into: (cals: 0.0, pro: 0.0, carb: 0.0, fat: 0.0)) { totals, meal in
                totals.cals += meal.calories
                totals.pro += meal.protein
                totals.carb += meal.carbs
                totals.fat += meal.fat
            }
            
            totalTargetCals += log.calorieTarget
            totalIntakeCals += dailyTotals.cals
            
            totalProTarget += log.proteinTarget
            totalProIntake += dailyTotals.pro
            totalCarbTarget += log.carbsTarget
            totalCarbIntake += dailyTotals.carb
            totalFatTarget += log.fatTarget
            totalFatIntake += dailyTotals.fat
            
            let diff = dailyTotals.cals - log.calorieTarget
            // Perfect range: 200 minus or 50 above goal
            if dailyTotals.cals > 0 && diff >= -200 && diff <= 50 {
                successfulDays += 1
            }
        }
        
        let avgTarget = totalTargetCals / Double(daysToCount)
        let avgIntake = totalIntakeCals / Double(daysToCount)
        let proRatio = totalProTarget > 0 ? (totalProIntake / totalProTarget) : 0
        let carbRatio = totalCarbTarget > 0 ? (totalCarbIntake / totalCarbTarget) : 0
        let fatRatio = totalFatTarget > 0 ? (totalFatIntake / totalFatTarget) : 0
        
        return ReviewStats(avgTarget: avgTarget, avgIntake: avgIntake, successfulDays: successfulDays, proRatio: proRatio, carbRatio: carbRatio, fatRatio: fatRatio)
    }
    
    private static func calculateBestMacro(stats: ReviewStats) -> (name: String, ratio: Double) {
        let macros = [
            (name: String.localizing( "Protein"), ratio: stats.proRatio),
            (name: String.localizing( "Carbs"), ratio: stats.carbRatio),
            (name: String.localizing( "Healthy Fats"), ratio: stats.fatRatio)
        ]
        
        let validMacros = macros.filter { $0.ratio > 0 }
        if let best = validMacros.min(by: { abs(1.0 - $0.ratio) < abs(1.0 - $1.ratio) }) {
            return best
        }
        
        return (String.localizing( "Protein"), 0.0)
    }
    
    private static func calculateWeightChange(validLogs: [DailyLog]) -> Double? {
        let sortedLogs = validLogs.sorted { $0.date < $1.date }
        if let firstLog = sortedLogs.first(where: { $0.bodyWeight != nil }), 
           let lastLog = sortedLogs.last(where: { $0.bodyWeight != nil }),
           let w1 = firstLog.bodyWeight, let w2 = lastLog.bodyWeight,
           firstLog.date != lastLog.date {
            return w2 - w1
        }
        return nil
    }
    
    private static func generateMotivationalMessage(successfulDays: Int, daysToCount: Int, isEmpty: Bool) -> String {
        if isEmpty {
            return String.localizing( "You don't have enough data yet. Keep logging your meals to see your review!")
        }
        let successRate = Double(successfulDays) / Double(daysToCount)
        if successRate >= 0.8 {
            return String.localizing( "Absolutely stellar work! You are building unbreakable habits. Keep this momentum going!")
        } else if successRate >= 0.5 {
            return String.localizing( "Great effort! You had some fantastic days. Let's aim to turn those few slip-ups into wins next time.")
        } else {
            return String.localizing( "Progress isn't always linear. What matters is that you're here and tracking. Let's focus on winning tomorrow.")
        }
    }
    
    private static func generateAnalysisMessage(avgTarget: Double, avgIntake: Double) -> String {
        let diff = avgIntake - avgTarget
        if diff < -200 {
            return String.localizing( "You were way under your goal.")
        } else if diff > 50 {
            return String.localizing( "You were above your goal.")
        } else {
            return String.localizing( "You were just perfect!")
        }
    }
}


extension String {
    static func localizing(_ key: String.LocalizationValue) -> String {
        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
        if appLanguage == "system" {
            return String(localized: key)
        } else {
            return String(localized: key, locale: Locale(identifier: appLanguage))
        }
    }
}
