import SwiftUI
import SwiftData
import VisionKit
import WidgetKit

func autoMealCategory(for date: Date = Date()) -> String {
    let hour = Calendar.current.component(.hour, from: date)
    if hour < 10 { return "Breakfast" }
    if hour < 14 { return "Lunch" }
    if hour < 17 { return "Snack" }
    return "Dinner"
}

// MARK: - 1. THE MAIN LIBRARY TAB
struct AddMealView: View {
    @Binding var selectedDate: Date
    @Binding var mainTabSelection: Int
    
    @Environment(\.modelContext) private var context
    @Query(sort: \FoodItem.name) private var foodLibrary: [FoodItem]
    @Query(sort: \RecipeItem.name) private var recipeLibrary: [RecipeItem]
    @Query(sort: \ConsumedMeal.consumedAt, order: .reverse) private var recentMeals: [ConsumedMeal]
    
    private var recentFoods: [FoodItem] {
        var foods: [FoodItem] = []
        var seenNames = Set<String>()
        for meal in recentMeals {
            if !seenNames.contains(meal.name) {
                if let food = foodLibrary.first(where: { $0.name == meal.name }) {
                    foods.append(food)
                    seenNames.insert(meal.name)
                }
            }
            if foods.count >= 8 { break }
        }
        return foods
    }
    
    @State private var viewModel = AddMealViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground),
                        Color.green.opacity(0.04),
                        Color.yellow.opacity(0.04),
                        Color(uiColor: .systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .adaptiveBackgroundTexture()

                VStack(spacing: 0) {
                if !Calendar.current.isDateInToday(selectedDate) {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.orange)
                        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                        let locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                        Text("Logging for \(selectedDate.formatted(.dateTime.weekday(.wide).month().day().locale(locale)))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.secondarySystemBackground))
                }
                
                Picker("Library", selection: $viewModel.selectedTab) {
                    Text("Foods").tag(0)
                    Text("Recipes").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                if viewModel.selectedTab == 0 {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.categories, id: \.self) { cat in
                                Button(action: {
                                    withAnimation { viewModel.selectedCategory = cat }
                                }) {
                                    Text(LocalizedStringKey(cat))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(viewModel.selectedCategory == cat ? Color.green : Color.secondary.opacity(0.15))
                                        .foregroundColor(viewModel.selectedCategory == cat ? .white : .primary)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                
                List {
                    if viewModel.selectedTab == 0 {
                        foodListContent
                    } else {
                        recipeListContent
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .searchable(text: $viewModel.searchText, prompt: "Search...")
                .overlay {
                    if viewModel.isFetchingAPI {
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.2)
                            Text("Looking up product...")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                }
                }
            }
            .navigationTitle(viewModel.selectedTab == 0 ? "Food Library" : "Recipe Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { viewModel.navigateToQuickEstimate = true }) {
                        Image(systemName: "bolt.fill")
                            .foregroundColor(.yellow)
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    if viewModel.selectedTab == 0 {
                        HStack(spacing: 16) {
                            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                                Button(action: { viewModel.isShowingScanner = true }) { Image(systemName: "barcode.viewfinder").accessibilityLabel("Scan Barcode") }
                            }
                            Button(action: { viewModel.prefilledAPIResult = nil; viewModel.navigateToCreateFood = true }) { Image(systemName: "plus") }
                        }
                    } else {
                        NavigationLink(destination: CreateRecipeView()) { Image(systemName: "plus") }
                    }
                }
            }
            .navigationDestination(isPresented: $viewModel.navigateToCreateFood) { 
                CreateFoodView(prefilledData: viewModel.prefilledAPIResult, editingFood: viewModel.foodToEdit, selectedDate: selectedDate, mainTabSelection: $mainTabSelection)
                    .onDisappear { viewModel.foodToEdit = nil; viewModel.prefilledAPIResult = nil }
            }
            .navigationDestination(isPresented: $viewModel.navigateToQuickEstimate) { QuickEstimateView(selectedDate: selectedDate, isRootPresented: $viewModel.navigateToQuickEstimate, mainTabSelection: $mainTabSelection) }
            .navigationDestination(item: $viewModel.selectedExistingFood) { food in LogFoodView(food: food, selectedDate: selectedDate, mainTabSelection: $mainTabSelection) }
            .navigationDestination(item: Binding<String?>(
                get: { viewModel.onlineSearchQuery },
                set: { viewModel.onlineSearchQuery = $0 }
            )) { query in
                OnlineSearchResultsView(query: query)
            }
            .sheet(isPresented: $viewModel.isShowingScanner) { ScannerView(scannedBarcode: $viewModel.scannedBarcode).ignoresSafeArea() }
            .onChange(of: viewModel.scannedBarcode) { _, newValue in if let barcode = newValue { viewModel.fetchFromOpenFoodFacts(barcode: barcode, foodLibrary: foodLibrary) } }
        }
    }
    
    private var foodListContent: some View {
        Group {
            if !viewModel.searchText.isEmpty {
                Section {
                    Button(action: {
                        viewModel.onlineSearchQuery = viewModel.searchText
                    }) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Search '\(viewModel.searchText)' Globally")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                        }
                        .foregroundColor(.blue)
                        .padding(.vertical, 4)
                    }
                }
            }
            
            if viewModel.searchText.isEmpty && !recentFoods.isEmpty {
                Section(header: Text("Recent Foods").font(.headline).foregroundColor(.primary).padding(.horizontal)) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recentFoods) { food in
                                NavigationLink(destination: LogFoodView(food: food, selectedDate: selectedDate, mainTabSelection: $mainTabSelection)) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(food.name).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                                        Text("\(Int(food.calories)) kcal").font(.caption).foregroundColor(.green)
                                    }
                                    .padding(12)
                                    .frame(width: 140, alignment: .leading)
                                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                                    .cornerRadius(12)
                                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            
            if viewModel.filteredFoods(from: foodLibrary).isEmpty {
                ContentUnavailableView("No Foods Locally", systemImage: "carrot", description: Text("Tap '+' to create food, or search globally above."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(viewModel.filteredFoods(from: foodLibrary)) { food in
                    NavigationLink(destination: LogFoodView(food: food, selectedDate: selectedDate, mainTabSelection: $mainTabSelection)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 4) {
                                Text(food.name).font(.headline)
                                if food.isVerified {
                                    Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.caption)
                                }
                            }
                            HStack(spacing: 8) {
                                Text("\(Int(food.calories)) kcal").foregroundColor(.green)
                                Text("•  \(Int(food.protein))g P | \(Int(food.carbs))g C | \(Int(food.fat))g F").foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                    .swipeActions { 
                        Button(role: .destructive) { viewModel.deleteFood(food, context: context) } label: { Label("Delete", systemImage: "trash") } 
                        Button {
                            viewModel.foodToEdit = food
                            viewModel.prefilledAPIResult = (name: food.name, calories: food.calories, protein: food.protein, carbs: food.carbs, fat: food.fat, barcode: food.barcode ?? "", category: food.category, fiber: food.fiber, sugar: food.sugar, saturatedFat: food.saturatedFat, sodium: food.sodium, imageUrl: food.imageUrl, nutriscore: food.nutriscore, ecoscore: food.ecoscore, novaGroup: food.novaGroup, ingredients: food.ingredients, allergens: food.allergens, brand: food.brand)
                            viewModel.navigateToCreateFood = true
                        } label: { Label("Edit", systemImage: "pencil") }.tint(.blue)
                    }
                    .listRowBackground(Color.clear)
                }
            }
        }
    }
    
    private var recipeListContent: some View {
        Group {
            if viewModel.filteredRecipes(from: recipeLibrary).isEmpty {
                ContentUnavailableView("No Recipes", systemImage: "frying.pan", description: Text("Tap '+' to combine foods into a recipe."))
                    .listRowBackground(Color.clear)
            } else {
                let groupedRecipes = Dictionary(grouping: viewModel.filteredRecipes(from: recipeLibrary), by: { $0.category })
                let sortedCategories = groupedRecipes.keys.sorted()
                
                ForEach(sortedCategories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(LocalizedStringKey(category))
                            .font(.title2.weight(.bold))
                            .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(groupedRecipes[category] ?? []) { recipe in
                                    NavigationLink(destination: LogRecipeView(recipe: recipe, selectedDate: selectedDate, mainTabSelection: $mainTabSelection)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(Color.green.opacity(0.1))
                                                    .frame(width: 140, height: 100)
                                                Image(systemName: recipe.systemImage)
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.green)
                                            }
                                            
                                            Text(recipe.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                                .frame(width: 140, alignment: .leading)
                                            
                                            HStack(spacing: 4) {
                                                Image(systemName: "clock")
                                                Text("\(recipe.prepTimeMinutes) min")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            
                                            Text("\(Int(recipe.calories)) kcal")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundColor(.green)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            viewModel.deleteRecipe(recipe, context: context)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }
        }
    }
}
