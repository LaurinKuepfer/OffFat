import Foundation
import SwiftData
import SwiftUI

@Observable
class CalculatorViewModel {
    var isMale: Bool = true
    var age: Double?
    var heightCM: Double?
    var weightKG: Double?
    var activityLevel: CalculatorView.ActivityLevel = .sedentary
    var dietTemplate: DietTemplate = .balanced
    
    func load(from log: DailyLog) {
        if let w = log.bodyWeight {
            self.weightKG = w
        }
    }
    
    var isInputValid: Bool {
        return age != nil && heightCM != nil && weightKG != nil
    }
    
    enum CalculationResult {
        case clean
        case macroConflict(diff: Double)
    }

    func calculateAndCheck(goal: GoalType) -> CalculationResult {
        let w = weightKG ?? 70.0
        let h = heightCM ?? 170.0
        let a = age ?? 30.0
        
        var bmr = (10.0 * w) + (6.25 * h) - (5.0 * a)
        bmr += isMale ? 5.0 : -161.0
        
        var tdee = bmr * activityLevel.multiplier
        if goal == .lose { tdee -= 500 }
        if goal == .gain { tdee += 300 }
        
        let proteinPerKg: Double
        let fatPercentage: Double
        
        switch dietTemplate {
        case .balanced:
            proteinPerKg = (activityLevel == .active || activityLevel == .athlete || goal == .gain) ? 2.0 : 1.6
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
        
        let proteinTarget = round(w * proteinPerKg)
        let fatTarget = round((tdee * fatPercentage) / 9.0)
        let remainingCals = tdee - (proteinTarget * 4.0) - (fatTarget * 9.0)
        
        if remainingCals < 0 {
            return .macroConflict(diff: abs(remainingCals))
        }
        return .clean
    }

    func saveWithIncreasedCalories(dailyLog: DailyLog, context: ModelContext, goal: GoalType) {
        _save(dailyLog: dailyLog, context: context, goal: goal, increaseCalories: true)
    }
    
    func saveWithScaledMacros(dailyLog: DailyLog, context: ModelContext, goal: GoalType) {
        _save(dailyLog: dailyLog, context: context, goal: goal, increaseCalories: false)
    }

    func saveNormal(dailyLog: DailyLog, context: ModelContext, goal: GoalType) {
        _save(dailyLog: dailyLog, context: context, goal: goal, increaseCalories: false)
    }

    private func _save(dailyLog: DailyLog, context: ModelContext, goal: GoalType, increaseCalories: Bool) {
        let w = weightKG ?? 70.0
        let h = heightCM ?? 170.0
        let a = age ?? 30.0
        
        var bmr = (10.0 * w) + (6.25 * h) - (5.0 * a)
        bmr += isMale ? 5.0 : -161.0
        
        var tdee = bmr * activityLevel.multiplier
        if goal == .lose { tdee -= 500 }
        if goal == .gain { tdee += 300 }
        
        let proteinPerKg: Double
        let fatPercentage: Double
        
        switch dietTemplate {
        case .balanced:
            proteinPerKg = (activityLevel == .active || activityLevel == .athlete || goal == .gain) ? 2.0 : 1.6
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
        
        var proteinTarget = round(w * proteinPerKg)
        var fatTarget = round((tdee * fatPercentage) / 9.0)
        let remainingCals = tdee - (proteinTarget * 4.0) - (fatTarget * 9.0)
        
        var roundedTdee = round(tdee)
        var carbsTarget = 0.0
        
        if remainingCals < 0 {
            if increaseCalories {
                roundedTdee = round((proteinTarget * 4.0) + (fatTarget * 9.0))
                carbsTarget = 0
            } else {
                let totalReqCals = (proteinTarget * 4.0) + (fatTarget * 9.0)
                let scaleFactor = tdee / totalReqCals
                proteinTarget = round(proteinTarget * scaleFactor)
                fatTarget = round(fatTarget * scaleFactor)
                carbsTarget = 0
            }
        } else {
            carbsTarget = round(remainingCals / 4.0)
        }
        
        dailyLog.calorieTarget = roundedTdee
        dailyLog.proteinTarget = proteinTarget
        dailyLog.carbsTarget = carbsTarget
        dailyLog.fatTarget = fatTarget
        dailyLog.bodyWeight = w
        dailyLog.waterTargetML = Int((w / 20.0) * 1000)
        
        context.safeSave()
    }
}
