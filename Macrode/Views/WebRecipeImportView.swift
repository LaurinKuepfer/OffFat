import SwiftUI
import SwiftData

struct WebRecipeImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var urlString: String = ""
    @State private var isScraping: Bool = false
    @State private var errorMessage: String? = nil
    @State private var scrapedRecipe: RecipeScraperManager.ScrapedRecipe? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Recipe URL")) {
                    TextField("https://example.com/recipe", text: $urlString)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.callout)
                    }
                }
                
                Section {
                    Button(action: {
                        Task {
                            await scrapeURL()
                        }
                    }) {
                        if isScraping {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        } else {
                            Text("Import Recipe")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(urlString.isEmpty || isScraping)
                }
                
                if let recipe = scrapedRecipe {
                    Section(header: Text("Preview")) {
                        Text(recipe.name)
                            .font(.headline)
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Calories: \(Int(recipe.calories))")
                                Text("Protein: \(Int(recipe.protein))g")
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("Carbs: \(Int(recipe.carbs))g")
                                Text("Fat: \(Int(recipe.fat))g")
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        
                        Text("Ingredients: \(recipe.ingredients.count)")
                        Text("Instructions: \(recipe.instructions.count) steps")
                        
                        Button(action: saveRecipe) {
                            Text("Save to My Recipes")
                                .frame(maxWidth: .infinity)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        .listRowBackground(Color.blue)
                    }
                }
            }
            .navigationTitle("Web Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func scrapeURL() async {
        isScraping = true
        errorMessage = nil
        scrapedRecipe = nil
        
        do {
            let recipe = try await RecipeScraperManager.shared.scrapeRecipe(from: urlString)
            await MainActor.run {
                self.scrapedRecipe = recipe
                self.isScraping = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isScraping = false
            }
        }
    }
    
    private func saveRecipe() {
        guard let recipe = scrapedRecipe else { return }
        
        // Ensure instructions don't get too long for typical use case, or store as joined text
        let instructions = recipe.instructions.isEmpty ? ["No instructions found"] : recipe.instructions
        
        let newRecipe = RecipeItem(
            name: recipe.name,
            calories: recipe.calories,
            protein: recipe.protein,
            carbs: recipe.carbs,
            fat: recipe.fat,
            instructions: instructions,
            category: "Lunch",
            prepTimeMinutes: recipe.prepTimeMinutes,
            difficulty: "Medium",
            systemImage: "globe"
        )
        
        modelContext.insert(newRecipe)
        
        // Optionally insert ingredients as text, though RecipeIngredient usually maps to a FoodItem
        // For web import, we don't map to FoodItems perfectly. Let's just rely on the instructions and nutrition.
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}
