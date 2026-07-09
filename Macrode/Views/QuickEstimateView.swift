import SwiftUI
import SwiftData
import VisionKit
import WidgetKit

// MARK: - 1. Quick Estimate
struct QuickEstimateView: View {
    var selectedDate: Date
    @Binding var isRootPresented: Bool
    @Binding var mainTabSelection: Int
    @Environment(\.modelContext) private var context
    
    @State private var name: String = ""
    @State private var calories: Double?
    @State private var protein: Double?
    @State private var carbs: Double?
    @State private var fat: Double?
    @FocusState private var isInputActive: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section(
                header: Text("Restaurant or Quick Meal"),
                footer: Text("Don't know the exact macros? Just estimate the calories. Consistency is more important than perfect accuracy.")
            ) {
                TextField("e.g. Five Guys Cheeseburger", text: $name)
                    .focused($isInputActive)
                
                HStack {
                    Text("Estimated Calories")
                    Spacer()
                    TextField("Required", value: $calories, format: .number)
                        .keyboardType(.numberPad)
                        .focused($isInputActive)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.green)
                        .font(.title3.weight(.bold))
                }
            }
            
            Section(
                header: Text("Optional Macros"),
                footer: Text("If you know the exact macros, you can enter them here. Otherwise, they will be logged as 0g.")
            ) {
                HStack {
                    Text("Protein")
                    Spacer()
                    TextField("Optional", value: $protein, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isInputActive)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.red)
                }
                HStack {
                    Text("Carbs")
                    Spacer()
                    TextField("Optional", value: $carbs, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isInputActive)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.blue)
                }
                HStack {
                    Text("Fats")
                    Spacer()
                    TextField("Optional", value: $fat, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($isInputActive)
                        .multilineTextAlignment(.trailing)
                        .foregroundColor(.orange)
                }
            }
        }
        .navigationTitle("Quick Estimate")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    isRootPresented = false
                }
            }
            ToolbarItem(placement: .keyboard) {
                KeyboardCloseButton(isInputActive: $isInputActive)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Log Meal") {
                    let finalCalories = max(0, calories ?? 0)
                    let finalProtein = max(0, protein ?? 0)
                    let finalCarbs = max(0, carbs ?? 0)
                    let finalFat = max(0, fat ?? 0)
                    
                    let meal = ConsumedMeal(
                        name: name,
                        calories: finalCalories,
                        protein: finalProtein,
                        carbs: finalCarbs,
                        fat: finalFat,
                        weightGrams: 0,
                        consumedAt: selectedDate,
                        mealCategory: autoMealCategory(for: selectedDate)
                    )
                    context.insert(meal)
                    context.safeSave()
                    
                    HapticManager.shared.notification(.success)
                    HealthKitManager.shared.saveMeal(
                        name: name,
                        calories: finalCalories,
                        protein: finalProtein,
                        carbs: finalCarbs,
                        fat: finalFat,
                        date: selectedDate
                    )
                    Task { WidgetCenter.shared.reloadAllTimelines() }
                    mainTabSelection = 0
                    isRootPresented = false
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || calories == nil)
            }
        }
            .onAppear {
                isInputActive = true
            }
        }
    }
}

