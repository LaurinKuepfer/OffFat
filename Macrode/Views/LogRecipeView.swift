import SwiftUI
import SwiftData
import VisionKit
import WidgetKit

// MARK: - 2. Log Recipe
struct LogRecipeView: View {
    let recipe: RecipeItem
    var selectedDate: Date
    @Binding var mainTabSelection: Int
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var servings: Double? = nil
    @FocusState private var isInputActive: Bool
    @State private var showingEditSheet = false
    
    enum LogMode { case servings, weight }
    @State private var logMode: LogMode = .servings
    @State private var portionWeight: Double? = nil
    @State private var selectedMealCategory: String = "Snack"
    @State private var logTime: Date = Date()
    
    private var macroMultiplier: Double {
        if logMode == .weight, let w = portionWeight, let total = recipe.totalCookedWeight, total > 0 {
            return w / total
        }
        return max(0, servings ?? 1)
    }
    
    private var calcCalories: Double { recipe.calories * macroMultiplier }
    private var calcProtein: Double { recipe.protein * macroMultiplier }
    private var calcCarbs: Double { recipe.carbs * macroMultiplier }
    private var calcFat: Double { recipe.fat * macroMultiplier }
    
    private var loggedWeightGrams: Double {
        if logMode == .weight {
            return portionWeight ?? 0
        }
        return 0
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: recipe.systemImage)
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                    .frame(width: 100, height: 100)
                    .background(Color.green.opacity(0.1))
                    .clipShape(Circle())
                    .padding(.top, 24)
                
                HStack(spacing: 16) {
                    StatBadge(icon: "clock", text: "\(recipe.prepTimeMinutes) min")
                    StatBadge(icon: "flame.fill", text: "\(Int(recipe.calories)) kcal")
                    StatBadge(icon: "chart.bar.fill", text: recipe.difficulty)
                    Spacer()
                }
                .padding()
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(20)
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition (per serving)")
                            .font(.title3.weight(.bold))
                        
                        HStack(spacing: 12) {
                            MacroPreviewCol(name: "Protein", amount: "\(Int(recipe.protein))g", color: .red)
                            MacroPreviewCol(name: "Carbs", amount: "\(Int(recipe.carbs))g", color: .blue)
                            MacroPreviewCol(name: "Fats", amount: "\(Int(recipe.fat))g", color: .orange)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    
                    if !recipe.instructions.isEmpty {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Instructions")
                                .font(.title3.weight(.bold))
                            
                            ForEach(Array(recipe.instructions.enumerated()), id: \.offset) { index, instruction in
                                HStack(alignment: .top, spacing: 16) {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 28, height: 28)
                                        .overlay(Text("\(index + 1)").font(.caption.weight(.bold)).foregroundColor(.green))
                                    
                                    Text(instruction)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Log Meal")
                            .font(.title3.weight(.bold))
                        
                        if recipe.totalCookedWeight != nil {
                            Picker("Mode", selection: $logMode) {
                                Text("Servings").tag(LogMode.servings)
                                Text("Weight (g)").tag(LogMode.weight)
                            }.pickerStyle(.segmented)
                        }
                        
                        if logMode == .servings {
                            HStack {
                                Text("Servings")
                                    .font(.headline)
                                Spacer()
                                TextField("1", value: $servings, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($isInputActive)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.weight(.bold))
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        } else {
                            HStack {
                                Text("Portion (g)")
                                    .font(.headline)
                                Spacer()
                                TextField("e.g. 250", value: $portionWeight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($isInputActive)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.weight(.bold))
                                    .frame(width: 100)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Picker("Meal Category", selection: $selectedMealCategory) {
                            Text("Breakfast").tag("Breakfast")
                            Text("Lunch").tag("Lunch")
                            Text("Snack").tag("Snack")
                            Text("Dinner").tag("Dinner")
                        }
                        .pickerStyle(.segmented)
                        .padding(.vertical, 8)
                        
                        DatePicker("Time", selection: $logTime, displayedComponents: .hourAndMinute)
                            .padding(.vertical, 8)
                        
                        Button(action: logMeal) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Log \(Int(calcCalories)) kcal")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(16)
                            .shadow(color: .green.opacity(0.3), radius: 8, x: 0, y: 4)
                        }
                        .disabled(logMode == .servings ? ((servings ?? 0) <= 0) : ((portionWeight ?? 0) <= 0))
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(20)
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showingEditSheet = true }
            }
            ToolbarItem(placement: .keyboard) {
                KeyboardCloseButton(isInputActive: $isInputActive)
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRecipeView(recipe: recipe)
        }
        .onAppear {
            isInputActive = true
            selectedMealCategory = autoMealCategory(for: selectedDate)
            logTime = selectedDate
            if recipe.totalCookedWeight != nil && recipe.totalCookedWeight! > 0 {
                logMode = .weight
            } else {
                logMode = .servings
                servings = 1
            }
        }
    }
    
    private func logMeal() {
        let meal = ConsumedMeal(
            name: recipe.name,
            calories: calcCalories,
            protein: calcProtein,
            carbs: calcCarbs,
            fat: calcFat,
            weightGrams: loggedWeightGrams,
            consumedAt: logTime,
            mealCategory: selectedMealCategory
        )
        context.insert(meal)
        context.safeSave()
        
        HapticManager.shared.notification(.success)
                    HealthKitManager.shared.saveMeal(
            name: recipe.name,
            calories: calcCalories,
            protein: calcProtein,
            carbs: calcCarbs,
            fat: calcFat,
            date: selectedDate
        )
        Task { WidgetCenter.shared.reloadAllTimelines() }
        mainTabSelection = 0
        dismiss()
    }
}
