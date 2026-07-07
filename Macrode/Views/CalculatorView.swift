import SwiftUI
import SwiftData
import WidgetKit


struct CalculatorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    
    var dailyLog: DailyLog
    
    @State private var viewModel = CalculatorViewModel()
    @AppStorage("userGoal") private var goal: GoalType = .maintain
    
    @FocusState private var isInputActive: Bool
    @State private var showConflictAlert = false
    
    enum ActivityLevel: String, CaseIterable {
        case sedentary = "Office Job"
        case light = "Light (1-2x/Wk)"
        case active = "Active (3-5x/Wk)"
        case athlete = "Athlete (Daily)"
        
        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .active: return 1.55
            case .athlete: return 1.725
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Body Stats")) {
                    Picker("Gender", selection: $viewModel.isMale) {
                        Text("Male").tag(true)
                        Text("Female").tag(false)
                    }.pickerStyle(.segmented)
                    
                    HStack { Text("Age"); Spacer(); TextField("Years", value: $viewModel.age, format: .number).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing) }
                    HStack { Text("Height"); Spacer(); TextField("cm", value: $viewModel.heightCM, format: .number).keyboardType(.numberPad).focused($isInputActive).multilineTextAlignment(.trailing) }
                    HStack { Text("Weight"); Spacer(); TextField("kg", value: $viewModel.weightKG, format: .number).keyboardType(.decimalPad).focused($isInputActive).multilineTextAlignment(.trailing) }
                }
                
                Section(header: Text("Goals & Activity")) {
                    Picker("Goal", selection: $goal) {
                        ForEach(GoalType.allCases, id: \.self) { type in Text(LocalizedStringKey(type.rawValue)).tag(type) }
                    }.pickerStyle(.menu)
                    
                    Picker("Activity", selection: $viewModel.activityLevel) {
                        ForEach(ActivityLevel.allCases, id: \.self) { type in Text(LocalizedStringKey(type.rawValue)).tag(type) }
                    }.pickerStyle(.menu)
                    
                    Picker("Diet Template", selection: $viewModel.dietTemplate) {
                        ForEach(DietTemplate.allCases, id: \.self) { type in Text(LocalizedStringKey(type.rawValue)).tag(type) }
                    }.pickerStyle(.menu)
                }
                
                Section(footer: Text("This will recalculate and overwrite your macro targets for today.")) {
                    Button(action: calculateAndSave) {
                        Text("Recalculate Macros")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .listRowBackground(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .disabled(!viewModel.isInputValid)
                }
            }
            .navigationTitle("Macro Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .keyboard) { KeyboardCloseButton(isInputActive: $isInputActive) }
            }
            .onAppear {
                viewModel.load(from: dailyLog)
            }
            .alert("Macro Conflict Detected", isPresented: $showConflictAlert) {
                Button("Increase Calories (Recommended)") {
                    viewModel.saveWithIncreasedCalories(dailyLog: dailyLog, context: context, goal: goal)
                    WidgetCenter.shared.reloadAllTimelines()
                    dismiss()
                }
                Button("Keep Deficit") {
                    viewModel.saveWithScaledMacros(dailyLog: dailyLog, context: context, goal: goal)
                    WidgetCenter.shared.reloadAllTimelines()
                    dismiss()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Your calorie deficit is too steep to support your minimum protein and fat requirements. Would you like to slightly increase your calories, or keep the strict deficit and scale down your macros?")
            }
        }
    }
    
    private func calculateAndSave() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        let result = viewModel.calculateAndCheck(goal: goal)
        switch result {
        case .clean:
            viewModel.saveNormal(dailyLog: dailyLog, context: context, goal: goal)
            WidgetCenter.shared.reloadAllTimelines()
            dismiss()
        case .macroConflict(_):
            showConflictAlert = true
        }
    }
}
