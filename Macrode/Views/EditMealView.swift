import SwiftUI
import SwiftData
import VisionKit
import WidgetKit

// MARK: - 5. Edit Logged Meal
struct EditMealView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    var meal: ConsumedMeal
    
    @State private var weight: Double
    @State private var calories: Double
    @State private var protein: Double
    @State private var carbs: Double
    @State private var fat: Double
    @FocusState private var isInputActive: Bool
    @State private var overrideMacros: Bool = false
    
    let isWeightBased: Bool
    let originalMacrosPerGram: (cals: Double, pro: Double, carb: Double, fat: Double)?
    
    init(meal: ConsumedMeal) {
        self.meal = meal
        _weight = State(initialValue: meal.weightGrams)
        _calories = State(initialValue: meal.calories)
        _protein = State(initialValue: meal.protein)
        _carbs = State(initialValue: meal.carbs)
        _fat = State(initialValue: meal.fat)
        
        self.isWeightBased = meal.weightGrams > 0
        if meal.weightGrams > 0 {
            self.originalMacrosPerGram = (
                cals: meal.calories / meal.weightGrams,
                pro: meal.protein / meal.weightGrams,
                carb: meal.carbs / meal.weightGrams,
                fat: meal.fat / meal.weightGrams
            )
        } else {
            self.originalMacrosPerGram = nil
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if isWeightBased {
                    Section(header: Text("How much did you eat?"), footer: Text("Macros will auto-update based on the new weight.")) {
                        HStack {
                            Text("Weight (grams / ml)")
                            Spacer()
                            TextField("100", value: $weight, format: .number)
                                .keyboardType(.decimalPad)
                                .focused($isInputActive)
                                .multilineTextAlignment(.trailing)
                                .font(.title3.weight(.bold))
                                .onChange(of: weight) { _, newValue in
                                    if let original = originalMacrosPerGram {
                                        let validWeight = max(0, newValue)
                                        calories = validWeight * original.cals
                                        protein = validWeight * original.pro
                                        carbs = validWeight * original.carb
                                        fat = validWeight * original.fat
                                    }
                                }
                        }
                    }
                }
                
                Section(header: Text("Calculated Nutrition")) {
                    if isWeightBased {
                        Toggle("Override Macros manually", isOn: $overrideMacros)
                            .tint(.green)
                    }
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("Calories", value: $calories, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.green)
                            .disabled(isWeightBased && !overrideMacros)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("Protein", value: $protein, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.red)
                            .disabled(isWeightBased && !overrideMacros)
                    }
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("Carbs", value: $carbs, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.blue)
                            .disabled(isWeightBased && !overrideMacros)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("Fats", value: $fat, format: .number)
                            .keyboardType(.decimalPad)
                            .focused($isInputActive)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.orange)
                            .disabled(isWeightBased && !overrideMacros)
                    }
                }
            }
            .navigationTitle("Edit \(meal.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .keyboard) {
                    KeyboardCloseButton(isInputActive: $isInputActive)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        meal.weightGrams = weight
                        meal.calories = calories
                        meal.protein = protein
                        meal.carbs = carbs
                        meal.fat = fat
                        context.safeSave()
                        HapticManager.shared.notification(.success)
                        Task { WidgetCenter.shared.reloadAllTimelines() } 
                        dismiss()
                    }
                    .fontWeight(.bold)
                }
            }
        }
        .onAppear {
            isInputActive = true
        }
    }
}

// MARK: - Online Search Results View
extension String: @retroactive Identifiable {
    public var id: String { self }
}
