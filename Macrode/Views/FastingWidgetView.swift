import SwiftUI

struct FastingWidgetView: View {
    @AppStorage("fastingStartTime") private var fastingStartTime: Double = 0
    @AppStorage("fastingGoalHours") private var fastingGoalHours: Int = 16
    @AppStorage("isFastingActive") private var isFastingActive: Bool = false
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "timer")
                    .foregroundColor(.orange)
                Text("Intermittent Fasting")
                    .font(.headline)
                Spacer()
                
                Menu {
                    Picker("Goal", selection: $fastingGoalHours) {
                        Text("12 hours").tag(12)
                        Text("14 hours").tag(14)
                        Text("16 hours").tag(16)
                        Text("18 hours").tag(18)
                        Text("20 hours").tag(20)
                        Text("24 hours").tag(24)
                    }
                } label: {
                    Text("\(fastingGoalHours)h")
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(8)
                }
            }
            
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                let progress = isFastingActive ? min(timeElapsed / (Double(fastingGoalHours) * 3600), 1.0) : 0
                
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear, value: progress)
                
                VStack(spacing: 4) {
                    if isFastingActive {
                        Text(timeString(from: timeElapsed))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        let remaining = max(0, (Double(fastingGoalHours) * 3600) - timeElapsed)
                        Text(remaining > 0 ? "-\(timeString(from: remaining)) left" : "Goal Reached!")
                            .font(.caption)
                            .foregroundColor(remaining > 0 ? .secondary : .green)
                    } else {
                        Text("Ready")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 8)
            
            Button(action: toggleFast) {
                Text(isFastingActive ? "End Fast" : "Start Fast")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isFastingActive ? Color.red : Color.orange)
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .padding(.horizontal)
        .onAppear {
            if isFastingActive {
                startTimer()
            }
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func toggleFast() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if isFastingActive {
            isFastingActive = false
            stopTimer()
            timeElapsed = 0
        } else {
            fastingStartTime = Date().timeIntervalSince1970
            isFastingActive = true
            startTimer()
        }
    }
    
    private func startTimer() {
        updateTimeElapsed()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            updateTimeElapsed()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func updateTimeElapsed() {
        if isFastingActive {
            timeElapsed = Date().timeIntervalSince1970 - fastingStartTime
        }
    }
    
    private func timeString(from interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
}
