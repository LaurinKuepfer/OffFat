import SwiftUI
import SwiftData

struct MacroCyclingSettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var schedules: [WeeklyMacroSchedule]
    
    @State private var localSchedule: WeeklyMacroSchedule?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                if let schedule = localSchedule {
                    Section(header: Text("Enable Macro Cycling"), footer: Text("When enabled, these custom daily targets will override Adaptive Coaching.")) {
                        Toggle("Macro Cycling", isOn: Binding(
                            get: { schedule.isActive },
                            set: { newValue in
                                schedule.isActive = newValue
                                try? context.save()
                            }
                        ))
                    }
                    
                    if schedule.isActive {
                        daySection(name: "Monday", cal: Binding(get: { schedule.monCalories }, set: { schedule.monCalories = $0 }), pro: Binding(get: { schedule.monProtein }, set: { schedule.monProtein = $0 }), car: Binding(get: { schedule.monCarbs }, set: { schedule.monCarbs = $0 }), fat: Binding(get: { schedule.monFat }, set: { schedule.monFat = $0 }))
                        
                        daySection(name: "Tuesday", cal: Binding(get: { schedule.tueCalories }, set: { schedule.tueCalories = $0 }), pro: Binding(get: { schedule.tueProtein }, set: { schedule.tueProtein = $0 }), car: Binding(get: { schedule.tueCarbs }, set: { schedule.tueCarbs = $0 }), fat: Binding(get: { schedule.tueFat }, set: { schedule.tueFat = $0 }))
                        
                        daySection(name: "Wednesday", cal: Binding(get: { schedule.wedCalories }, set: { schedule.wedCalories = $0 }), pro: Binding(get: { schedule.wedProtein }, set: { schedule.wedProtein = $0 }), car: Binding(get: { schedule.wedCarbs }, set: { schedule.wedCarbs = $0 }), fat: Binding(get: { schedule.wedFat }, set: { schedule.wedFat = $0 }))
                        
                        daySection(name: "Thursday", cal: Binding(get: { schedule.thuCalories }, set: { schedule.thuCalories = $0 }), pro: Binding(get: { schedule.thuProtein }, set: { schedule.thuProtein = $0 }), car: Binding(get: { schedule.thuCarbs }, set: { schedule.thuCarbs = $0 }), fat: Binding(get: { schedule.thuFat }, set: { schedule.thuFat = $0 }))
                        
                        daySection(name: "Friday", cal: Binding(get: { schedule.friCalories }, set: { schedule.friCalories = $0 }), pro: Binding(get: { schedule.friProtein }, set: { schedule.friProtein = $0 }), car: Binding(get: { schedule.friCarbs }, set: { schedule.friCarbs = $0 }), fat: Binding(get: { schedule.friFat }, set: { schedule.friFat = $0 }))
                        
                        daySection(name: "Saturday", cal: Binding(get: { schedule.satCalories }, set: { schedule.satCalories = $0 }), pro: Binding(get: { schedule.satProtein }, set: { schedule.satProtein = $0 }), car: Binding(get: { schedule.satCarbs }, set: { schedule.satCarbs = $0 }), fat: Binding(get: { schedule.satFat }, set: { schedule.satFat = $0 }))
                        
                        daySection(name: "Sunday", cal: Binding(get: { schedule.sunCalories }, set: { schedule.sunCalories = $0 }), pro: Binding(get: { schedule.sunProtein }, set: { schedule.sunProtein = $0 }), car: Binding(get: { schedule.sunCarbs }, set: { schedule.sunCarbs = $0 }), fat: Binding(get: { schedule.sunFat }, set: { schedule.sunFat = $0 }))
                    }
                } else {
                    Text("Loading...")
                }
            }
            .navigationTitle("Macro Cycling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let existing = schedules.first {
                    self.localSchedule = existing
                } else {
                    let new = WeeklyMacroSchedule()
                    context.insert(new)
                    self.localSchedule = new
                }
            }
        }
    }
    
    @ViewBuilder
    private func daySection(name: String, cal: Binding<Double>, pro: Binding<Double>, car: Binding<Double>, fat: Binding<Double>) -> some View {
        Section(header: Text(name)) {
            HStack { Text("Calories"); Spacer(); TextField("", value: cal, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.green) }
            HStack { Text("Protein (g)"); Spacer(); TextField("", value: pro, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.red) }
            HStack { Text("Carbs (g)"); Spacer(); TextField("", value: car, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.blue) }
            HStack { Text("Fats (g)"); Spacer(); TextField("", value: fat, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).foregroundColor(.orange) }
        }
    }
}
