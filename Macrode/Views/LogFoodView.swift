import SwiftUI
import SwiftData
import VisionKit
import WidgetKit

// MARK: - 3. Log Single Food
struct LogFoodView: View {
    let food: FoodItem
    var selectedDate: Date
    @Binding var mainTabSelection: Int
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var weight: Double? = nil
    @State private var unitCount: Double? = nil
    @FocusState private var isInputActive: Bool
    
    enum LogMode { case weight, unit }
    @State private var logMode: LogMode = .weight
    @State private var selectedMealCategory: String = "Snack"
    @State private var logTime: Date = Date()
    
    private var validWeight: Double { 
        if logMode == .unit, let count = unitCount, let unitWeight = food.householdUnitWeightGrams {
            return count * unitWeight
        }
        return max(0, weight ?? 0) 
    }
    private var multiplier: Double { validWeight / 100.0 }
    
    private var calcCalories: Double { food.calories * multiplier }
    private var calcProtein: Double { food.protein * multiplier }
    private var calcCarbs: Double { food.carbs * multiplier }
    private var calcFat: Double { food.fat * multiplier }
    
    private var calcFiber: Double? { food.fiber.map { $0 * multiplier } }
    private var calcSugar: Double? { food.sugar.map { $0 * multiplier } }
    private var calcSaturatedFat: Double? { food.saturatedFat.map { $0 * multiplier } }
    private var calcSodium: Double? { food.sodium.map { $0 * multiplier } }
    
    private var isDrink: Bool {
        let cat = food.category.lowercased()
        return cat.contains("drink") || cat.contains("beverage") || cat.contains("liquid")
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let urlString = food.imageUrl, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill().frame(width: 120, height: 120).clipShape(Circle())
                        case .empty, .failure:
                            Image(systemName: isDrink ? "cup.and.saucer.fill" : "leaf.fill")
                                .font(.system(size: 60)).foregroundColor(.blue).frame(width: 120, height: 120).background(Color.blue.opacity(0.1)).clipShape(Circle())
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    Image(systemName: isDrink ? "cup.and.saucer.fill" : "leaf.fill")
                        .font(.system(size: 60)).foregroundColor(.blue).frame(width: 120, height: 120).background(Color.blue.opacity(0.1)).clipShape(Circle())
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        StatBadge(icon: isDrink ? "drop.fill" : "scalemass.fill", text: food.category)
                        StatBadge(icon: "flame.fill", text: "\(Int(food.calories)) kcal/100\(isDrink ? "ml" : "g")")
                        if let brand = food.brand, !brand.isEmpty {
                            StatBadge(icon: "tag.fill", text: brand)
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .cornerRadius(20)
                
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Nutrition (Calculated)")
                            .font(.title3.weight(.bold))
                        
                        HStack(spacing: 12) {
                            MacroPreviewCol(name: "Protein", amount: "\(Int(calcProtein))g", color: .red)
                            MacroPreviewCol(name: "Carbs", amount: "\(Int(calcCarbs))g", color: .blue)
                            MacroPreviewCol(name: "Fats", amount: "\(Int(calcFat))g", color: .orange)
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    
                    if food.fiber != nil || food.sugar != nil || food.saturatedFat != nil || food.sodium != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Extended Nutrition (Calculated)")
                                .font(.title3.weight(.bold))
                            
                            VStack(spacing: 8) {
                                if let fiber = calcFiber { LabeledContent("Fiber", value: String(format: "%.1f g", fiber)).foregroundColor(.brown) }
                                if let sugar = calcSugar { LabeledContent("Sugar", value: String(format: "%.1f g", sugar)).foregroundColor(.pink) }
                                if let satFat = calcSaturatedFat { LabeledContent("Saturated Fat", value: String(format: "%.1f g", satFat)).foregroundColor(.orange) }
                                if let sodium = calcSodium { LabeledContent("Sodium", value: String(format: "%.1f g", sodium)).foregroundColor(.gray) }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                    
                    if food.nutriscore != nil || food.ecoscore != nil || food.novaGroup != nil || food.ingredients?.isEmpty == false || food.allergens?.isEmpty == false {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Open Food Facts Data")
                                .font(.title3.weight(.bold))
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    if let n = food.nutriscore { StatBadge(icon: "heart.fill", text: "Nutri: \(n.uppercased())") }
                                    if let e = food.ecoscore { StatBadge(icon: "leaf.fill", text: "Eco: \(e.uppercased())") }
                                    if let nova = food.novaGroup { StatBadge(icon: "flask.fill", text: "NOVA: \(nova)") }
                                }
                            }
                            
                            if let ingredients = food.ingredients, !ingredients.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Ingredients").font(.subheadline.weight(.bold))
                                    Text(ingredients).font(.caption).foregroundColor(.secondary)
                                }
                            }
                            
                            if let allergens = food.allergens, !allergens.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Allergens").font(.subheadline.weight(.bold)).foregroundColor(.red)
                                    Text(allergens).font(.caption).foregroundColor(.red)
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
                        
                        if let unitName = food.householdUnitName, let _ = food.householdUnitWeightGrams {
                            Picker("Mode", selection: $logMode) {
                                Text("Weight").tag(LogMode.weight)
                                Text(unitName).tag(LogMode.unit)
                            }.pickerStyle(.segmented)
                        }
                        
                        if logMode == .weight {
                            HStack {
                                Text(isDrink ? "Volume (ml)" : "Weight (grams)")
                                    .font(.headline)
                                Spacer()
                                TextField("100", value: $weight, format: .number)
                                    .keyboardType(.decimalPad)
                                    .focused($isInputActive)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.weight(.bold))
                                    .frame(width: 100)
                                    .padding(8)
                                    .background(Color.secondary.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        } else {
                            HStack {
                                Text(food.householdUnitName ?? "Units")
                                    .font(.headline)
                                Spacer()
                                TextField("1", value: $unitCount, format: .number)
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
                        .disabled(logMode == .weight ? (weight ?? 0) <= 0 : (unitCount ?? 0) <= 0)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .cornerRadius(20)
                }
                .padding()
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(food.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if food.isVerified {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("Verified", systemImage: "checkmark.seal.fill").foregroundColor(.green)
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                KeyboardCloseButton(isInputActive: $isInputActive)
            }
        }
        .onAppear {
            isInputActive = true
            selectedMealCategory = autoMealCategory(for: selectedDate)
            logTime = selectedDate
            if food.householdUnitName != nil && food.householdUnitWeightGrams != nil {
                logMode = .unit
                unitCount = 1
            }
        }
    }
    
    private func logMeal() {
        let meal = ConsumedMeal(
            name: food.name,
            calories: calcCalories,
            protein: calcProtein,
            carbs: calcCarbs,
            fat: calcFat,
            weightGrams: validWeight,
            consumedAt: logTime,
            mealCategory: selectedMealCategory,
            fiber: calcFiber,
            sugar: calcSugar,
            saturatedFat: calcSaturatedFat,
            sodium: calcSodium
        )
        context.insert(meal)
        context.safeSave()
        
        HapticManager.shared.notification(.success)
        HealthKitManager.shared.saveMeal(
            name: food.name,
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

