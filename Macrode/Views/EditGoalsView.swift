import SwiftUI
import SwiftData
import WidgetKit

struct EditGoalsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    var dailyLog: DailyLog
    
    @Query private var allSupplements: [Supplement]
    
    @State private var calories: Double = 0
    @State private var protein: Double = 0
    @State private var carbs: Double = 0
    @State private var fat: Double = 0
    @State private var waterTarget: Int = 0
    @State private var isSocialDay: Bool = false
    
    @State private var showingCalculator = false
    @FocusState private var isInputActive: Bool
    
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        showingCalculator = true
                    }) {
                        HStack {
                            Image(systemName: "brain.head.profile").foregroundColor(.purple)
                            Text("Auto-Calculate with Smart Formula").fontWeight(.medium).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                        }
                    }
                    .sheet(isPresented: $showingCalculator) { CalculatorView(dailyLog: dailyLog).presentationDetents([.large]) }
                }
                
                Section(header: Text("Flexible Day / Social Event"), footer: Text("Take a flexible day. High energy intake won't trigger warnings, but targets will gracefully adapt later.")) {
                    Toggle("Enable Social Day", isOn: $isSocialDay)
                        .tint(.orange)
                }
                
                Section(header: Text("Nutrition Targets")) {
                    HStack { Text("Calories"); Spacer(); TextField("2200", value: $calories, format: .number.precision(.fractionLength(0))).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing).foregroundColor(.green) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("150", value: $protein, format: .number.precision(.fractionLength(0))).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing).foregroundColor(.red) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("250", value: $carbs, format: .number.precision(.fractionLength(0))).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing).foregroundColor(.blue) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("70", value: $fat, format: .number).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing).foregroundColor(.orange) }
                }
                
                Section(header: Text("Hydration")) {
                    HStack { Text("Water Target (ml)"); Spacer(); TextField("2500", value: $waterTarget, format: .number).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing).foregroundColor(.cyan) }
                }
                
                Section(header: Text("Supplements"), footer: Text("Add your daily vitamins or supplements and assign them to specific days.")) {
                    ForEach(allSupplements) { supp in
                        SupplementEditRow(supplement: supp)
                    }
                    .onDelete(perform: deleteSupplement)
                    
                    Button(action: {
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                        let newSupp = Supplement(name: "New Supplement")
                        context.insert(newSupp)
                    }) {
                        Label("Add Supplement", systemImage: "plus.circle.fill")
                            .foregroundColor(.pink)
                    }
                }
            }
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                calories = dailyLog.calorieTarget
                protein = dailyLog.proteinTarget
                carbs = dailyLog.carbsTarget
                fat = dailyLog.fatTarget
                waterTarget = dailyLog.waterTargetML
                isSocialDay = dailyLog.isSocialDay
            }
            .onChange(of: showingCalculator) { _, isShowing in
                if !isShowing {
                    calories = dailyLog.calorieTarget
                    protein = dailyLog.proteinTarget
                    carbs = dailyLog.carbsTarget
                    fat = dailyLog.fatTarget
                    waterTarget = dailyLog.waterTargetML
                    isSocialDay = dailyLog.isSocialDay
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .keyboard) { KeyboardCloseButton(isInputActive: $isInputActive) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { saveGoals() } }
            }
        }
    }
    
    private func deleteSupplement(at offsets: IndexSet) {
        for index in offsets {
            context.delete(allSupplements[index])
        }
    }
    
    private func saveGoals() {
        dailyLog.calorieTarget = max(0, calories)
        dailyLog.proteinTarget = max(0, protein)
        dailyLog.carbsTarget = max(0, carbs)
        dailyLog.fatTarget = max(0, fat)
        dailyLog.waterTargetML = max(0, waterTarget)
        dailyLog.isSocialDay = isSocialDay
        
        context.safeSave()
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

struct SupplementEditRow: View {
    @Bindable var supplement: Supplement
    let daysOfWeek = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Name", text: $supplement.name)
                .font(.headline)
                .foregroundColor(.pink)
            
            HStack {
                ForEach(0..<7) { index in
                    let dayNumber = index + 1
                    
                    let currentDays = supplement.scheduledDays.split(separator: ",").compactMap { Int($0) }
                    let isSelected = currentDays.contains(dayNumber)
                    
                    Text(daysOfWeek[index])
                        .font(.caption)
                        .fontWeight(.bold)
                        .frame(width: 30, height: 30)
                        .background(isSelected ? Color.pink : Color.secondary.opacity(0.2))
                        .foregroundColor(isSelected ? .white : .primary)
                        .clipShape(Circle())
                        .onTapGesture {
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            
                            var newDays = currentDays
                            if isSelected {
                                newDays.removeAll(where: { $0 == dayNumber })
                            } else {
                                newDays.append(dayNumber)
                            }
                            supplement.scheduledDays = newDays.map { String($0) }.joined(separator: ",")
                        }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
