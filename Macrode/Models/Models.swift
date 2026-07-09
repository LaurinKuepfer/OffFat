import Foundation
import SwiftData
import ActivityKit

@Model
final class FoodItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var barcode: String?
    var category: String
    var createdAt: Date
    
    var fiber: Double?
    var sugar: Double?
    var saturatedFat: Double?
    var sodium: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var calcium: Double?
    var iron: Double?
    var potassium: Double?
    var magnesium: Double?
    
    var imageUrl: String?
    var nutriscore: String?
    var ecoscore: String?
    var novaGroup: Int?
    var ingredients: String?
    var allergens: String?
    var brand: String?
    
    var householdUnitName: String?
    var householdUnitWeightGrams: Double?
    
    var isVerified: Bool { barcode != nil }
    
    init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double, barcode: String? = nil, category: String = "Other", createdAt: Date = Date(), fiber: Double? = nil, sugar: Double? = nil, saturatedFat: Double? = nil, sodium: Double? = nil, imageUrl: String? = nil, nutriscore: String? = nil, ecoscore: String? = nil, novaGroup: Int? = nil, ingredients: String? = nil, allergens: String? = nil, brand: String? = nil, householdUnitName: String? = nil, householdUnitWeightGrams: Double? = nil) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.barcode = barcode
        self.category = category
        self.createdAt = createdAt
        self.fiber = fiber
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.sodium = sodium
        self.imageUrl = imageUrl
        self.nutriscore = nutriscore
        self.ecoscore = ecoscore
        self.novaGroup = novaGroup
        self.ingredients = ingredients
        self.allergens = allergens
        self.brand = brand
        self.householdUnitName = householdUnitName
        self.householdUnitWeightGrams = householdUnitWeightGrams
    }
}

@Model
final class RecipeIngredient {
    @Attribute(.unique) var id: UUID
    var food: FoodItem?
    var weightGrams: Double
    var recipe: RecipeItem?
    
    init(id: UUID = UUID(), food: FoodItem? = nil, weightGrams: Double = 100, recipe: RecipeItem? = nil) {
        self.id = id
        self.food = food
        self.weightGrams = weightGrams
        self.recipe = recipe
    }
}

@Model
final class RecipeItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    
    var instructions: [String]
    var category: String
    var prepTimeMinutes: Int
    var difficulty: String
    var systemImage: String
    
    @Relationship(deleteRule: .cascade, inverse: \RecipeIngredient.recipe)
    var savedIngredients: [RecipeIngredient]?
    
    var totalCookedWeight: Double?
    
    init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double, instructions: [String] = [], category: String = "Breakfast", prepTimeMinutes: Int = 10, difficulty: String = "Easy", systemImage: String = "fork.knife", totalCookedWeight: Double? = nil) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.instructions = instructions
        self.category = category
        self.prepTimeMinutes = prepTimeMinutes
        self.difficulty = difficulty
        self.systemImage = systemImage
        self.totalCookedWeight = totalCookedWeight
    }
}

@Model
final class Supplement {
    @Attribute(.unique) var id: UUID
    var name: String
    var scheduledDays: String
    
    var datesTaken: [String]
    
    init(id: UUID = UUID(), name: String, scheduledDays: String = "1,2,3,4,5,6,7", datesTaken: [String] = []) {
        self.id = id
        self.name = name
        self.scheduledDays = scheduledDays
        self.datesTaken = datesTaken
    }
}

@Model
final class DailyLog {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var date: Date
    var calorieTarget: Double
    var proteinTarget: Double
    var carbsTarget: Double
    var fatTarget: Double
    var waterML: Int
    var waterTargetML: Int
    var bodyWeight: Double?
    var bodyFatPercentage: Double?
    var waistCircumference: Double?
    var neckCircumference: Double?
    var chestCircumference: Double?
    var isSocialDay: Bool
    
    
    init(id: UUID = UUID(), date: Date = Calendar.current.startOfDay(for: Date()), calorieTarget: Double = 2200, proteinTarget: Double = 150, carbsTarget: Double = 250, fatTarget: Double = 70, waterML: Int = 0, waterTargetML: Int = 2500, bodyWeight: Double? = nil, bodyFatPercentage: Double? = nil, waistCircumference: Double? = nil, neckCircumference: Double? = nil, chestCircumference: Double? = nil, isSocialDay: Bool = false) {
        self.id = id
        self.date = date
        self.calorieTarget = calorieTarget
        self.proteinTarget = proteinTarget
        self.carbsTarget = carbsTarget
        self.fatTarget = fatTarget
        self.waterML = waterML
        self.waterTargetML = waterTargetML
        self.bodyWeight = bodyWeight
        self.bodyFatPercentage = bodyFatPercentage
        self.waistCircumference = waistCircumference
        self.neckCircumference = neckCircumference
        self.chestCircumference = chestCircumference
        self.isSocialDay = isSocialDay
    }
}

@Model
final class ConsumedMeal {
    @Attribute(.unique) var id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    var weightGrams: Double
    var consumedAt: Date
    var mealCategory: String
    
    var fiber: Double?
    var sugar: Double?
    var saturatedFat: Double?
    var sodium: Double?
    var vitaminA: Double?
    var vitaminC: Double?
    var vitaminD: Double?
    var calcium: Double?
    var iron: Double?
    var potassium: Double?
    var magnesium: Double?
    
    init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double, weightGrams: Double = 100, consumedAt: Date = Date(), mealCategory: String = "Snack", fiber: Double? = nil, sugar: Double? = nil, saturatedFat: Double? = nil, sodium: Double? = nil) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.weightGrams = weightGrams
        self.consumedAt = consumedAt
        self.mealCategory = mealCategory
        self.fiber = fiber
        self.sugar = sugar
        self.saturatedFat = saturatedFat
        self.sodium = sodium
    }
}

public struct DailyLogData: Sendable {
    public let date: Date
    public let calorieTarget: Double
    public let bodyWeight: Double?
    
    init(from log: DailyLog) {
        self.date = log.date
        self.calorieTarget = log.calorieTarget
        self.bodyWeight = log.bodyWeight
    }
}

public struct ConsumedMealData: Sendable {
    public let calories: Double
    public let consumedAt: Date
    
    init(from meal: ConsumedMeal) {
        self.calories = meal.calories
        self.consumedAt = meal.consumedAt
    }
}

public enum GoalType: String, CaseIterable, Sendable {
    case lose = "Lose Weight"
    case maintain = "Maintain"
    case gain = "Build Muscle"
}

public enum DietTemplate: String, CaseIterable, Sendable {
    case balanced = "Balanced"
    case lowCarb = "Low Carb"
    case keto = "Keto"
    case highProtein = "High Protein"
}

public enum FastingSchedule: String, CaseIterable, Sendable, Codable {
    case off = "Off"
    case custom = "Custom"
    case intermittent16_8 = "16:8 (16h Fast)"
    case intermittent18_6 = "18:6 (18h Fast)"
    case omad = "OMAD (23h Fast)"
    
    var targetHours: Double {
        switch self {
        case .off: return 0
        case .custom: return 12
        case .intermittent16_8: return 16
        case .intermittent18_6: return 18
        case .omad: return 23
        }
    }
}

@Model
final class WeeklyMacroSchedule {
    @Attribute(.unique) var id: UUID
    var isActive: Bool
    
    var monCalories: Double
    var monProtein: Double
    var monCarbs: Double
    var monFat: Double
    
    var tueCalories: Double
    var tueProtein: Double
    var tueCarbs: Double
    var tueFat: Double
    
    var wedCalories: Double
    var wedProtein: Double
    var wedCarbs: Double
    var wedFat: Double
    
    var thuCalories: Double
    var thuProtein: Double
    var thuCarbs: Double
    var thuFat: Double
    
    var friCalories: Double
    var friProtein: Double
    var friCarbs: Double
    var friFat: Double
    
    var satCalories: Double
    var satProtein: Double
    var satCarbs: Double
    var satFat: Double
    
    var sunCalories: Double
    var sunProtein: Double
    var sunCarbs: Double
    var sunFat: Double
    
    init(isActive: Bool = false) {
        self.id = UUID()
        self.isActive = isActive
        self.monCalories = 2000; self.monProtein = 150; self.monCarbs = 200; self.monFat = 65
        self.tueCalories = 2000; self.tueProtein = 150; self.tueCarbs = 200; self.tueFat = 65
        self.wedCalories = 2000; self.wedProtein = 150; self.wedCarbs = 200; self.wedFat = 65
        self.thuCalories = 2000; self.thuProtein = 150; self.thuCarbs = 200; self.thuFat = 65
        self.friCalories = 2000; self.friProtein = 150; self.friCarbs = 200; self.friFat = 65
        self.satCalories = 2000; self.satProtein = 150; self.satCarbs = 200; self.satFat = 65
        self.sunCalories = 2000; self.sunProtein = 150; self.sunCarbs = 200; self.sunFat = 65
    }
}
