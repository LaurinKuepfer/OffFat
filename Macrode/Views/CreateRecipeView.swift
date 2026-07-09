import SwiftUI
import SwiftData
import VisionKit

struct RecipeIngredientTemp: Identifiable {
    let id = UUID()
    let food: FoodItem
    var weightGrams: Double
}

struct CreateRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foodLibrary: [FoodItem]
    
    @State private var recipeName: String = ""
    @State private var ingredients: [RecipeIngredientTemp] = []
    @State private var cookedWeight: Double? = nil
    
    @State private var showingAddIngredient = false
    @State private var selectedFood: FoodItem?
    @State private var ingredientWeight: Double = 100
    @FocusState private var isNameFocused: Bool
    
    private var totalCalories: Double { ingredients.reduce(0) { $0 + ($1.food.calories * ($1.weightGrams / 100)) } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + ($1.food.protein * ($1.weightGrams / 100)) } }
    private var totalCarbs: Double { ingredients.reduce(0) { $0 + ($1.food.carbs * ($1.weightGrams / 100)) } }
    private var totalFat: Double { ingredients.reduce(0) { $0 + ($1.food.fat * ($1.weightGrams / 100)) } }
    
    var body: some View {
        Form {
            Section(header: Text("Recipe Name")) {
                TextField("e.g., Morning Protein Oats", text: $recipeName)
                    .focused($isNameFocused)
            }
            
            Section(header: Text("Ingredients"), footer: Text("Add foods from your library to build this recipe.")) {
                ForEach(ingredients) { ingredient in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(ingredient.food.name).font(.headline)
                            Text("\(Int(ingredient.weightGrams))g").font(.subheadline).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(Int(ingredient.food.calories * (ingredient.weightGrams / 100))) kcal")
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }
                .onDelete(perform: deleteIngredient)
                
                Button(action: { showingAddIngredient = true }) {
                    Label("Add Ingredient", systemImage: "plus.circle.fill")
                        .foregroundColor(.green)
                        .font(.headline)
                }
            }
            
            Section(header: Text("Total Cooked Weight (Optional)"), footer: Text("If you are batch prepping, enter the final cooked weight in grams to enable portion logging by weight.")) {
                TextField("e.g., 1200", value: $cookedWeight, format: .number)
                    .keyboardType(.decimalPad)
                    .focused($isNameFocused)
            }
            
            if !ingredients.isEmpty {
                Section(header: Text("Total Nutrition (Per 1 Serving)")) {
                    LabeledContent("Calories", value: "\(Int(totalCalories)) kcal").foregroundColor(.green)
                    LabeledContent("Protein", value: "\(Int(totalProtein)) g").foregroundColor(.red)
                    LabeledContent("Carbs", value: "\(Int(totalCarbs)) g").foregroundColor(.blue)
                    LabeledContent("Fats", value: "\(Int(totalFat)) g").foregroundColor(.orange)
                }
            }
        }
        .navigationTitle("Create Recipe")
        .toolbar {
            ToolbarItem(placement: .keyboard) { KeyboardCloseButton(isInputActive: $isNameFocused) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save Recipe") {
                    saveRecipe()
                }
                .disabled(recipeName.isEmpty || ingredients.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddIngredient) {
            IngredientPickerSheet(
                foodLibrary: foodLibrary,
                onFoodSelected: { food in
                    self.selectedFood = food
                }
            )
        }
        .sheet(item: Binding(get: { selectedFood }, set: { if $0 == nil { selectedFood = nil } })) { food in
            NavigationStack {
                Form {
                    Section(header: Text("Weight for \(food.name)")) {
                        HStack {
                            Text("Grams")
                            Spacer()
                            TextField("100", value: $ingredientWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(.blue)
                        }
                    }
                }
                .navigationTitle("Add Ingredient")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { selectedFood = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            ingredients.append(RecipeIngredientTemp(food: food, weightGrams: ingredientWeight))
                            selectedFood = nil
                            ingredientWeight = 100
                        }
                    }
                }
            }
            .presentationDetents([.height(250)])
        }
    }
    
    private func deleteIngredient(at offsets: IndexSet) { ingredients.remove(atOffsets: offsets) }
    
    private func saveRecipe() {
        let newRecipe = RecipeItem(name: recipeName, calories: totalCalories, protein: totalProtein, carbs: totalCarbs, fat: totalFat, totalCookedWeight: cookedWeight)
        
        var savedIngs: [RecipeIngredient] = []
        for ing in ingredients {
            let newIng = RecipeIngredient(food: ing.food, weightGrams: ing.weightGrams, recipe: newRecipe)
            savedIngs.append(newIng)
        }
        newRecipe.savedIngredients = savedIngs
        
        context.insert(newRecipe)
        dismiss()
    }
}

// MARK: - THE INGREDIENT PICKER SHEET