import SwiftUI

struct FastingScheduleSettingsView: View {
    @AppStorage("enableFasting") private var enableFasting = false
    @AppStorage("fastingSchedule") private var fastingScheduleRaw = FastingSchedule.off.rawValue
    
    var body: some View {
        Form {
            Section(header: Text("Intermittent Fasting"), footer: Text("When enabled, the app will track your fasting hours using the selected schedule and display progress in Live Activities.")) {
                Toggle("Enable Fasting Timer", isOn: $enableFasting)
                
                if enableFasting {
                    Picker("Fasting Schedule", selection: $fastingScheduleRaw) {
                        ForEach(FastingSchedule.allCases, id: \.self) { schedule in
                            Text(schedule.rawValue).tag(schedule.rawValue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Fasting Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
