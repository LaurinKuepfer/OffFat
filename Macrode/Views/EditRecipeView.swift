import SwiftUI
import SwiftData
import VisionKit

// MARK: - Edit Recipe
struct EditRecipeView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \FoodItem.name) private var foodLibrary: [FoodItem]
    
    var recipe: RecipeItem
    
    @State private var name: String
    @State private var category: String
    @State private var prepTimeMinutes: Int
    @State private var cookedWeight: Double?
    @FocusState private var isInputActive: Bool
    
    @State private var ingredients: [RecipeIngredientTemp] = []
    @State private var showingAddIngredient = false
    @State private var selectedFood: FoodItem?
    @State private var ingredientWeight: Double = 100
    
    let categories = ["Breakfast", "Lunch", "Dinner", "Snack", "Dessert", "Shake", "Other"]
    
    init(recipe: RecipeItem) {
        self.recipe = recipe
        _name = State(initialValue: recipe.name)
        _category = State(initialValue: recipe.category)
        _prepTimeMinutes = State(initialValue: recipe.prepTimeMinutes)
        _cookedWeight = State(initialValue: recipe.totalCookedWeight)
    }
    
    private var totalCalories: Double { ingredients.reduce(0) { $0 + ($1.food.calories * ($1.weightGrams / 100)) } }
    private var totalProtein: Double { ingredients.reduce(0) { $0 + ($1.food.protein * ($1.weightGrams / 100)) } }
    private var totalCarbs: Double { ingredients.reduce(0) { $0 + ($1.food.carbs * ($1.weightGrams / 100)) } }
    private var totalFat: Double { ingredients.reduce(0) { $0 + ($1.food.fat * ($1.weightGrams / 100)) } }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Recipe Details")) {
                    TextField("Recipe Name", text: $name).focused($isInputActive)
                    Picker("Category", selection: $category) { ForEach(categories, id: \.self) { cat in Text(LocalizedStringKey(cat)).tag(cat) } }
                    HStack { Text("Prep Time (min)"); Spacer(); TextField("e.g. 15", value: $prepTimeMinutes, format: .number).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing) }
                }
                
                Section(header: Text("Ingredients"), footer: Text("Add foods from your library to build this recipe.")) {
                    ForEach(ingredients) { ingredient in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(ingredient.food.name).font(.headline)
                                Text("\(Int(ingredient.weightGrams))g").font(.subheadline).foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(Int(ingredient.food.calories * (ingredient.weightGrams / 100))) kcal").font(.subheadline).foregroundColor(.green)
                        }
                    }
                    .onDelete(perform: deleteIngredient)
                    
                    Button(action: { showingAddIngredient = true }) {
                        Label("Add Ingredient", systemImage: "plus.circle.fill").foregroundColor(.green).font(.headline)
                    }
                }
                
                Section(header: Text("Total Cooked Weight (Optional)"), footer: Text("If you are batch prepping, enter the final cooked weight in grams to enable portion logging by weight.")) {
                    TextField("e.g., 1200", value: $cookedWeight, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isInputActive)
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
            .navigationTitle("Edit \(recipe.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .keyboard) { KeyboardCloseButton(isInputActive: $isInputActive) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveRecipe() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || ingredients.isEmpty)
                }
            }
            .onAppear { loadIngredients() }
            .sheet(isPresented: $showingAddIngredient) {
                IngredientPickerSheet(foodLibrary: foodLibrary, onFoodSelected: { self.selectedFood = $0 })
            }
            .sheet(item: Binding(get: { selectedFood }, set: { if $0 == nil { selectedFood = nil } })) { food in
                NavigationStack {
                    Form {
                        Section(header: Text("Weight for \(food.name)")) {
                            HStack { Text("Grams"); Spacer(); TextField("100", value: $ingredientWeight, format: .number).keyboardType(.decimalPad).multilineTextAlignment(.trailing).foregroundColor(.blue) }
                        }
                    }
                    .navigationTitle("Add Ingredient")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { selectedFood = nil } }
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
    }
    
    private func deleteIngredient(at offsets: IndexSet) { ingredients.remove(atOffsets: offsets) }
    
    private func loadIngredients() {
        if let saved = recipe.savedIngredients {
            var temp: [RecipeIngredientTemp] = []
            for ing in saved {
                if let f = ing.food { temp.append(RecipeIngredientTemp(food: f, weightGrams: ing.weightGrams)) }
            }
            self.ingredients = temp
        } else {
            // Legacy recipe compatibility
            // Just add a dummy ingredient representing the total macros so the UI doesn't break
            let dummyFood = FoodItem(name: "Legacy Recipe Data", calories: recipe.calories, protein: recipe.protein, carbs: recipe.carbs, fat: recipe.fat)
            self.ingredients = [RecipeIngredientTemp(food: dummyFood, weightGrams: 100)]
        }
    }
    
    private func saveRecipe() {
        recipe.name = name
        recipe.category = category
        recipe.prepTimeMinutes = prepTimeMinutes
        recipe.totalCookedWeight = cookedWeight
        
        recipe.calories = totalCalories
        recipe.protein = totalProtein
        recipe.carbs = totalCarbs
        recipe.fat = totalFat
        
        // Remove old ingredients
        if let old = recipe.savedIngredients {
            for o in old { context.delete(o) }
        }
        
        // Add new
        var newIngs: [RecipeIngredient] = []
        for ing in ingredients {
            let n = RecipeIngredient(food: ing.food, weightGrams: ing.weightGrams, recipe: recipe)
            newIngs.append(n)
        }
        recipe.savedIngredients = newIngs
        
        context.safeSave()
        dismiss()
    }
}
