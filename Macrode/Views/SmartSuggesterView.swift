import SwiftUI
import SwiftData
import WidgetKit

struct SmartSuggesterView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var foodLibrary: [FoodItem]
    @Query private var pastMeals: [ConsumedMeal]
    
    var remProtein: Double
    var remCarbs: Double
    var remFat: Double
    var selectedDate: Date
    
    @State private var suggestion: [FoodPortion] = []
    @State private var isCalculating = true
    
    struct FoodPortion: Identifiable {
        let id = UUID()
        let food: FoodItem
        let grams: Double
        
        var calories: Double { food.calories * (grams / 100.0) }
        var protein: Double { food.protein * (grams / 100.0) }
        var carbs: Double { food.carbs * (grams / 100.0) }
        var fat: Double { food.fat * (grams / 100.0) }
    }
    
    struct FoodData: Sendable {
        let id: UUID
        let name: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double
        
        init(from item: FoodItem) {
            self.id = item.id
            self.name = item.name
            self.calories = item.calories
            self.protein = item.protein
            self.carbs = item.carbs
            self.fat = item.fat
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(UIColor.systemGroupedBackground),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.03),
                        Color(UIColor.systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                VStack(spacing: 24) {
                if isCalculating {
                    ProgressView()
                        .scaleEffect(2)
                    Text("Calculating perfect combo...")
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                } else if suggestion.isEmpty {
                    Image(systemName: "face.dashed")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Let's add more variety to your library to unlock better combos!")
                        .font(.headline)
                    Text("Try adding single-macro foods like lean chicken, rice, or olive oil. We'll find the perfect combination for your remaining targets!")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                } else {
                    Text("Here's the perfect combination to hit your goals today:")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        ForEach(suggestion) { portion in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(portion.food.name).font(.headline)
                                    Text("\(Int(portion.grams))g").font(.subheadline).foregroundColor(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(Int(portion.calories)) kcal").font(.headline).foregroundColor(.green)
                                    Text("\(Int(portion.protein))P | \(Int(portion.carbs))C | \(Int(portion.fat))F").font(.caption).foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(20)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button(action: logSuggestion) {
                        Text("Log This Combo")
                            .font(.headline)
                            .foregroundColor(.green)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(20)
                    }
                    .padding(.horizontal)
                    
                    Button(action: calculateSuggestion) {
                        Text("Refresh Suggestion")
                            .foregroundColor(.blue)
                    }
                    .padding(.bottom)
                }
            }
            }
            .navigationTitle("Smart Suggester ðŸª„")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .onAppear {
                calculateSuggestion()
            }
        }
    }
    
    private func logSuggestion() {
        for portion in suggestion {
            let meal = ConsumedMeal(
                name: portion.food.name,
                calories: portion.calories,
                protein: portion.protein,
                carbs: portion.carbs,
                fat: portion.fat,
                weightGrams: portion.grams,
                consumedAt: selectedDate,
                mealCategory: autoMealCategory(for: selectedDate),
                fiber: portion.food.fiber.map { $0 * portion.grams / 100.0 },
                sugar: portion.food.sugar.map { $0 * portion.grams / 100.0 },
                saturatedFat: portion.food.saturatedFat.map { $0 * portion.grams / 100.0 },
                sodium: portion.food.sodium.map { $0 * portion.grams / 100.0 }
            )
            context.insert(meal)
            HealthKitManager.shared.saveMeal(
                name: portion.food.name,
                calories: portion.calories,
                protein: portion.protein,
                carbs: portion.carbs,
                fat: portion.fat,
                date: selectedDate
            )
        }
        context.safeSave()
        WidgetCenter.shared.reloadAllTimelines()
        HapticManager.shared.notification(.success)
        dismiss()
    }
    
    private func calculateSuggestion() {
        isCalculating = true
        suggestion = []
        
        let foodsToAnalyze = foodLibrary.map { FoodData(from: $0) }
        var freqMap: [String: Int] = [:]
        for m in pastMeals { freqMap[m.name, default: 0] += 1 }
        
        let rP = remProtein
        let rC = remCarbs
        let rF = remFat
        
        Task {
            let valid = foodsToAnalyze.filter { $0.protein > 0 || $0.carbs > 0 || $0.fat > 0 }
            let bestComboData = await Self.runCalculation(validFoods: valid, freqMap: freqMap, rP: rP, rC: rC, rF: rF)
            
            if let combo = bestComboData {
                var finalCombo: [FoodPortion] = []
                for data in combo {
                    if let food = self.foodLibrary.first(where: { $0.id == data.id }) {
                        finalCombo.append(FoodPortion(food: food, grams: data.grams))
                    }
                }
                self.suggestion = finalCombo
            }
            self.isCalculating = false
        }
    }
    
    private static func runCalculation(validFoods: [FoodData], freqMap: [String: Int], rP: Double, rC: Double, rF: Double) async -> [(id: UUID, grams: Double)]? {
        return await Task.detached {
            var valid = validFoods
            valid.sort { (freqMap[$0.name] ?? 0) > (freqMap[$1.name] ?? 0) }
            if valid.isEmpty { return nil }
            
            var bestComboData: [(id: UUID, grams: Double)] = []
            var bestScore: Double = Double.infinity
            
            for food in valid.prefix(30) {
                for g in stride(from: 10, through: 500, by: 10) {
                    let grams = Double(g)
                    let p = food.protein * (grams/100.0)
                    let c = food.carbs * (grams/100.0)
                    let f = food.fat * (grams/100.0)
                    
                    let score = abs(rP - p) + abs(rC - c) + abs(rF - f)
                    if score < bestScore {
                        bestScore = score
                        bestComboData = [(food.id, grams)]
                    }
                }
            }
            
            if bestScore > 10 && valid.count > 1 {
                let topFoods = Array(valid.prefix(20))
                for i in 0..<topFoods.count {
                    for j in (i+1)..<topFoods.count {
                        let f1 = topFoods[i]
                        let f2 = topFoods[j]
                        for g1 in stride(from: 10, through: 600, by: 20) {
                            for g2 in stride(from: 10, through: 600, by: 20) {
                                let grams1 = Double(g1)
                                let grams2 = Double(g2)
                                let p = f1.protein * (grams1/100.0) + f2.protein * (grams2/100.0)
                                let c = f1.carbs * (grams1/100.0) + f2.carbs * (grams2/100.0)
                                let f = f1.fat * (grams1/100.0) + f2.fat * (grams2/100.0)
                                
                                let score = abs(rP - p) + abs(rC - c) + abs(rF - f)
                                if score < bestScore {
                                    bestScore = score
                                    bestComboData = [(f1.id, grams1), (f2.id, grams2)]
                                }
                            }
                        }
                    }
                }
            }
            
            let dynamicThreshold = max(80.0, (rP + rC + rF) * 0.40)
            if bestScore < dynamicThreshold { return bestComboData }
            return bestComboData.isEmpty ? nil : bestComboData
        }.value
    }
}
