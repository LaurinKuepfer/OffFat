import Foundation
import SwiftData
import SwiftUI

@Observable
class DashboardViewModel {
    var cachedTDEE: TDEEResult?
    
    var showingSmartSuggester = false
    var showingQuickAddSheet = false
    var editingMeal: ConsumedMeal? = nil
    var mealToDelete: ConsumedMeal? = nil
    
    var goalsMetCache: [Date: Bool] = [:]
    var logsDictionary: [Date: DailyLog] = [:]
    
    func recalculateEngines(allDailyLogs: [DailyLog], allConsumedMeals: [ConsumedMeal], userGoal: GoalType, selectedDate: Date) {
        let logsData = allDailyLogs.map { DailyLogData(from: $0) }
        let mealsData = allConsumedMeals.map { ConsumedMealData(from: $0) }
        
        let tdeeResult = MetabolismEngine.calculateTrueTDEE(dailyLogs: logsData, allMeals: mealsData)
        self.cachedTDEE = tdeeResult
        
        // Dynamic Coaching
        let isAdaptiveCoachingEnabled = UserDefaults.standard.bool(forKey: "isAdaptiveCoachingEnabled")
        let templateStr = UserDefaults.standard.string(forKey: "dietTemplate") ?? DietTemplate.balanced.rawValue
        let template = DietTemplate(rawValue: templateStr) ?? .balanced
        
        if isAdaptiveCoachingEnabled, let trueTdee = tdeeResult.tdee {
            let startOfDay = Calendar.current.startOfDay(for: selectedDate)
            if let todayLog = allDailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
                
                var newCalorieTarget = trueTdee
                if userGoal == .lose { newCalorieTarget -= 500 }
                if userGoal == .gain { newCalorieTarget += 300 }
                
                let weight = todayLog.bodyWeight ?? 70.0
                let proteinPerKg: Double
                let fatPercentage: Double
                
                switch template {
                case .balanced:
                    proteinPerKg = (userGoal == .gain) ? 2.0 : 1.6 // simplified
                    fatPercentage = 0.25
                case .lowCarb:
                    proteinPerKg = 2.2
                    fatPercentage = 0.35
                case .keto:
                    proteinPerKg = 1.8
                    fatPercentage = 0.70
                case .highProtein:
                    proteinPerKg = 2.4
                    fatPercentage = 0.25
                }
                
                var proteinTarget = round(weight * proteinPerKg)
                var fatTarget = round((newCalorieTarget * fatPercentage) / 9.0)
                let remainingCals = newCalorieTarget - (proteinTarget * 4.0) - (fatTarget * 9.0)
                var carbsTarget = 0.0
                
                if remainingCals < 0 {
                    let totalReqCals = (proteinTarget * 4.0) + (fatTarget * 9.0)
                    let scaleFactor = newCalorieTarget / totalReqCals
                    proteinTarget = round(proteinTarget * scaleFactor)
                    fatTarget = round(fatTarget * scaleFactor)
                } else {
                    carbsTarget = round(remainingCals / 4.0)
                }
                
                // Only update if there is a significant change (e.g. > 50 kcal) to avoid constant micro-updates
                if abs(todayLog.calorieTarget - round(newCalorieTarget)) > 50 {
                    todayLog.calorieTarget = round(newCalorieTarget)
                    todayLog.proteinTarget = proteinTarget
                    todayLog.carbsTarget = carbsTarget
                    todayLog.fatTarget = fatTarget
                    
                    if let context = todayLog.modelContext {
                        try? context.save()
                    }
                }
            }
        }
    }
    
    var frequentMeals: [ConsumedMeal] = []
    
    func updateFrequentMeals(allConsumedMeals: [ConsumedMeal]) {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let startOfToday = calendar.startOfDay(for: now)
        
        let todayMealNames = Set(allConsumedMeals.filter { $0.consumedAt >= startOfToday }.map { $0.name })
        
        let recentMeals = allConsumedMeals.filter {
            guard $0.consumedAt < startOfToday else { return false }
            
            let daysAgo = calendar.dateComponents([.day], from: $0.consumedAt, to: now).day ?? 0
            guard daysAgo <= 30 else { return false }
            
            let mealHour = calendar.component(.hour, from: $0.consumedAt)
            let diff = abs(mealHour - currentHour)
            return diff <= 2 || diff >= 22
        }
        
        let grouped = Dictionary(grouping: recentMeals, by: { $0.name })
        let frequent = grouped.filter { !todayMealNames.contains($0.key) && $0.value.count >= 2 }
        
        let sorted = frequent.sorted { $0.value.count > $1.value.count }
        let result = sorted.prefix(3).compactMap { $0.value.first }
        
        self.frequentMeals = result
    }
    
    func updateLogsDictionary(dailyLogs: [DailyLog]) {
        var dict = [Date: DailyLog]()
        for log in dailyLogs { dict[Calendar.current.startOfDay(for: log.date)] = log }
        self.logsDictionary = dict
    }
}
