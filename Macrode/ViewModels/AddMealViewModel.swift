import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class AddMealViewModel {
    var searchText: String = ""
    var selectedTab: Int = 0
    var selectedCategory: String = "All"
    
    var isShowingScanner = false
    var scannedBarcode: String? = nil
    var isFetchingAPI = false
    
    typealias APIResult = (name: String, calories: Double, protein: Double, carbs: Double, fat: Double, barcode: String, category: String, fiber: Double?, sugar: Double?, saturatedFat: Double?, sodium: Double?, imageUrl: String?, nutriscore: String?, ecoscore: String?, novaGroup: Int?, ingredients: String?, allergens: String?, brand: String?)
    var prefilledAPIResult: APIResult? = nil
    
    var navigateToCreateFood = false
    var selectedExistingFood: FoodItem? = nil
    
    var navigateToQuickEstimate = false
    var onlineSearchQuery: String?
    var foodToEdit: FoodItem? = nil
    
    let categories = ["All", "Scanned", "Drinks", "Fruits", "Vegetables", "Meat", "Carbs", "Dairy & Fats", "Fast Food", "Other"]
    
    func filteredFoods(from foodLibrary: [FoodItem]) -> [FoodItem] {
        var result = foodLibrary
        if selectedCategory == "Scanned" {
            result = result.filter { $0.isVerified }
        } else if selectedCategory != "All" {
            result = result.filter { $0.category == selectedCategory }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
    
    func filteredRecipes(from recipeLibrary: [RecipeItem]) -> [RecipeItem] {
        if searchText.isEmpty { return recipeLibrary }
        return recipeLibrary.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    func deleteFood(_ food: FoodItem, context: ModelContext) {
        context.delete(food)
        context.safeSave()
    }
    
    func deleteRecipe(_ recipe: RecipeItem, context: ModelContext) {
        context.delete(recipe)
        context.safeSave()
    }
    
    private var fetchTask: Task<Void, Never>?
    
    func fetchFromOpenFoodFacts(barcode: String, foodLibrary: [FoodItem]) {
        if let existingFood = foodLibrary.first(where: { $0.barcode == barcode }) {
            selectedExistingFood = existingFood
            return
        }
        
        fetchTask?.cancel()
        isFetchingAPI = true
        fetchTask = Task {
            if let result = try? await OpenFoodFactsAPI.fetchProduct(barcode: barcode) {
                if Task.isCancelled { return }
                await MainActor.run { 
                    self.prefilledAPIResult = (name: result.name, calories: result.calories, protein: result.protein, carbs: result.carbs, fat: result.fat, barcode: barcode, category: result.category, fiber: result.fiber, sugar: result.sugar, saturatedFat: result.saturatedFat, sodium: result.sodium, imageUrl: result.imageUrl, nutriscore: result.nutriscore, ecoscore: result.ecoscore, novaGroup: result.novaGroup, ingredients: result.ingredients, allergens: result.allergens, brand: result.brand)
                    self.isFetchingAPI = false
                    self.navigateToCreateFood = true 
                }
            } else {
                if Task.isCancelled { return }
                await MainActor.run { self.isFetchingAPI = false; self.prefilledAPIResult = nil; self.navigateToCreateFood = true }
            }
        }
    }
}
