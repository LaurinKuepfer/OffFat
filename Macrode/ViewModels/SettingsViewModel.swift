import Foundation
import SwiftData
import SwiftUI

@Observable
class SettingsViewModel {
    var showingExporter = false
    var showingImporter = false
    var showingAlert = false
    var showingResetConfirm = false
    
    var alertTitle = ""
    var alertMessage = ""
    var csvDocument = CSVDocument()
    
    func showAlert(title: String, message: String = "") {
        self.alertTitle = title
        self.alertMessage = message
        self.showingAlert = true
    }
    
    func resetAllData(context: ModelContext) {
        do {
            let mealDesc = FetchDescriptor<ConsumedMeal>()
            let logDesc = FetchDescriptor<DailyLog>()
            let foodDesc = FetchDescriptor<FoodItem>()
            let recipeDesc = FetchDescriptor<RecipeItem>()
            let suppDesc = FetchDescriptor<Supplement>()
            
            for item in (try? context.fetch(mealDesc)) ?? [] { context.delete(item) }
            for item in (try? context.fetch(logDesc)) ?? [] { context.delete(item) }
            for item in (try? context.fetch(foodDesc)) ?? [] { context.delete(item) }
            for item in (try? context.fetch(recipeDesc)) ?? [] { context.delete(item) }
            for item in (try? context.fetch(suppDesc)) ?? [] { context.delete(item) }
            
            try context.save()
            
            UserDefaults.standard.set(false, forKey: "hasLoadedStarterData")
            
            HapticManager.shared.notification(.success)
            showAlert(title: String.localizing( "Data Reset"), message: String.localizing( "All data has been deleted. Restart the app to begin fresh."))
        } catch {
            showAlert(title: String.localizing( "Error"), message: error.localizedDescription)
        }
    }
    
    func reseedStarterDatabase(context: ModelContext) {
        do {
            let foodsDesc = FetchDescriptor<FoodItem>()
            let recipesDesc = FetchDescriptor<RecipeItem>()
            let existingFoods = try context.fetch(foodsDesc)
            let existingRecipes = try context.fetch(recipesDesc)
            
            let starterFoodNames = StarterDatabase.allStarterFoodNames
            let starterRecipeNames = StarterDatabase.allStarterRecipeNames
            
            for food in existingFoods where starterFoodNames.contains(food.name) {
                context.delete(food)
            }
            for recipe in existingRecipes where starterRecipeNames.contains(recipe.name) {
                context.delete(recipe)
            }
            
            for item in StarterDatabase.foods { 
                context.insert(FoodItem(name: item.name, calories: item.calories, protein: item.protein, carbs: item.carbs, fat: item.fat, category: item.category)) 
            }
            for recipe in StarterDatabase.recipes { 
                context.insert(RecipeItem(name: recipe.name, calories: recipe.calories, protein: recipe.protein, carbs: recipe.carbs, fat: recipe.fat, instructions: recipe.instructions, category: recipe.category, prepTimeMinutes: recipe.prepTimeMinutes, difficulty: recipe.difficulty, systemImage: recipe.systemImage)) 
            }
            context.safeSave()
        } catch {
            print("Failed to update language database: \(error)")
        }
    }
    
    func prepareExport(allMeals: [ConsumedMeal]) {
        var rows: [String] = ["Date,Meal Name,Calories,Protein,Carbs,Fat,Weight (g)"]
        let formatter = ISO8601DateFormatter()
        for meal in allMeals {
            let dateStr = formatter.string(from: meal.consumedAt)
            var safeName = meal.name
            if safeName.contains(",") || safeName.contains("\"") {
                safeName = "\"" + safeName.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            rows.append("\(dateStr),\(safeName),\(meal.calories),\(meal.protein),\(meal.carbs),\(meal.fat),\(meal.weightGrams)")
        }
        csvDocument = CSVDocument(initialText: rows.joined(separator: "\n"))
        showingExporter = true
    }
    
    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        var skipNext = false
        
        let chars = Array(row)
        for (i, char) in chars.enumerated() {
            if skipNext {
                skipNext = false
                continue
            }
            
            if char == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i+1] == "\"" {
                    current.append("\"")
                    skipNext = true
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }
    
    func importCSV(from url: URL, context: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else { showAlert(title: String.localizing( "Error"), message: String.localizing( "Permission denied to read file.")); return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            guard let csvString = String(data: data, encoding: .utf8) else { return }
            let rows = csvString.components(separatedBy: "\n")
            guard rows.count > 1 else { return }
            
            let formatter = ISO8601DateFormatter()
            var importCount = 0
            
            for row in rows.dropFirst() {
                if row.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
                let columns = parseCSVRow(row)
                if columns.count >= 7 {
                    if let date = formatter.date(from: columns[0]), let cals = Double(columns[2]), let prot = Double(columns[3]), let carbs = Double(columns[4]), let fat = Double(columns[5]), let weight = Double(columns[6]) {
                        let newMeal = ConsumedMeal(name: columns[1], calories: cals, protein: prot, carbs: carbs, fat: fat, weightGrams: weight, consumedAt: date)
                        context.insert(newMeal)
                        importCount += 1
                    }
                }
            }
            context.safeSave()
            showAlert(title: String.localizing( "Import Successful!"), message: String.localizing( "Restored \(importCount) meals to your diary."))
        } catch {
            showAlert(title: String.localizing( "Import Error"), message: error.localizedDescription)
        }
    }
}
