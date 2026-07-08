import SwiftUI

struct MeasurementsSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var log: DailyLog
    
    @State private var weightStr = ""
    @State private var bodyFatStr = ""
    @State private var waistStr = ""
    @State private var neckStr = ""
    @State private var chestStr = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Core Metrics")) {
                    HStack {
                        Text("Body Weight (kg)")
                        Spacer()
                        TextField("Optional", text: $weightStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Body Fat (%)")
                        Spacer()
                        TextField("Optional", text: $bodyFatStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section(header: Text("Circumferences (cm)"), footer: Text("Tracking circumferences can give you a more accurate picture of fat loss than weight alone.")) {
                    HStack {
                        Text("Waist")
                        Spacer()
                        TextField("Optional", text: $waistStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Neck")
                        Spacer()
                        TextField("Optional", text: $neckStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Chest")
                        Spacer()
                        TextField("Optional", text: $chestStr)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            .navigationTitle("Log Measurements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMeasurements()
                        dismiss()
                    }
                }
            }
            .onAppear {
                weightStr = log.bodyWeight != nil ? String(format: "%.1f", log.bodyWeight!) : ""
                bodyFatStr = log.bodyFatPercentage != nil ? String(format: "%.1f", log.bodyFatPercentage!) : ""
                waistStr = log.waistCircumference != nil ? String(format: "%.1f", log.waistCircumference!) : ""
                neckStr = log.neckCircumference != nil ? String(format: "%.1f", log.neckCircumference!) : ""
                chestStr = log.chestCircumference != nil ? String(format: "%.1f", log.chestCircumference!) : ""
            }
        }
    }
    
    private func saveMeasurements() {
        if let w = Double(weightStr.replacingOccurrences(of: ",", with: ".")) { log.bodyWeight = w } else if weightStr.isEmpty { log.bodyWeight = nil }
        if let bf = Double(bodyFatStr.replacingOccurrences(of: ",", with: ".")) { log.bodyFatPercentage = bf } else if bodyFatStr.isEmpty { log.bodyFatPercentage = nil }
        if let w = Double(waistStr.replacingOccurrences(of: ",", with: ".")) { log.waistCircumference = w } else if waistStr.isEmpty { log.waistCircumference = nil }
        if let n = Double(neckStr.replacingOccurrences(of: ",", with: ".")) { log.neckCircumference = n } else if neckStr.isEmpty { log.neckCircumference = nil }
        if let c = Double(chestStr.replacingOccurrences(of: ",", with: ".")) { log.chestCircumference = c } else if chestStr.isEmpty { log.chestCircumference = nil }
        
        try? context.save()
    }
}
