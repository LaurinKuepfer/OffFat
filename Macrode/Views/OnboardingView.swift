import SwiftUI
import SwiftData
import WidgetKit

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    
    @State private var currentStep = 0
    @FocusState private var isInputActive: Bool
    
    @State private var isMale: Bool = true
    @State private var age: Double = 30
    @State private var heightCM: Double = 170
    @State private var weightKG: Double = 70.0
    @State private var hasLoggedDummy = false
    
    @State private var goal: GoalType = .maintain
    @State private var activityLevel: ActivityLevel = .sedentary
    @State private var dietTemplate: DietTemplate = .balanced
    
    enum GoalType: String, CaseIterable {
        case lose = "Lose Weight"
        case maintain = "Maintain"
        case gain = "Build Muscle"
        
        var icon: String {
            switch self {
            case .lose: return "arrow.down.forward.and.arrow.up.backward"
            case .maintain: return "equal.circle"
            case .gain: return "bolt.fill"
            }
        }
    }
    
    enum ActivityLevel: String, CaseIterable {
        case sedentary = "Couch / Office Job"
        case light = "Light (1-2x Sport/Wk)"
        case active = "Active (3-5x Sport/Wk)"
        case athlete = "Athlete (Daily Hard Training)"
        
        var multiplier: Double {
            switch self {
            case .sedentary: return 1.2
            case .light: return 1.375
            case .active: return 1.55
            case .athlete: return 1.725
            }
        }
    }
    
    private var computedMacros: (calories: Double, protein: Double, carbs: Double, fat: Double) {
        let w = weightKG
        let h = heightCM
        let a = age
        
        var bmr = (10.0 * w) + (6.25 * h) - (5.0 * a)
        bmr += isMale ? 5.0 : -161.0
        
        var tdee = bmr * activityLevel.multiplier
        if goal == .lose { tdee -= 500 }
        if goal == .gain { tdee += 300 }
        
        let proteinPerKg: Double
        let fatPercentage: Double
        
        switch dietTemplate {
        case .balanced:
            proteinPerKg = (activityLevel == .active || activityLevel == .athlete || goal == .gain) ? 2.0 : 1.6
            fatPercentage = 0.25
        case .lowCarb:
            proteinPerKg = 2.2
            fatPercentage = 0.35
        case .keto:
            proteinPerKg = 1.8
            fatPercentage = 0.70
        case .highProtein:
            proteinPerKg = 2.4
            fatPercentage = 0.25
        }
        
        let protein = round(w * proteinPerKg)
        let fat = round((tdee * fatPercentage) / 9.0)
        let remainingCals = tdee - (protein * 4.0) - (fat * 9.0)
        let carbs = round(max(0, remainingCals / 4.0))
        
        return (round(tdee), protein, carbs, fat)
    }
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [.green.opacity(0.2), .blue.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                progressHeader
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                TabView(selection: $currentStep) {
                    welcomeScreen.tag(0)
                    bodyStatsScreen.tag(1)
                    goalsScreen.tag(2)
                    resultScreen.tag(3)
                    interactiveScreen.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                .toolbar {
                    ToolbarItem(placement: .keyboard) {
                        KeyboardCloseButton(isInputActive: $isInputActive)
                    }
                }
            }
            
            if currentStep > 0 {
                VStack {
                    HStack {
                        Button(action: {
                            playHaptic()
                            currentStep -= 1
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)
                                .padding(12)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
        }
    }
    
   
    private var progressHeader: some View {
        HStack(spacing: 8) {
            ForEach(0..<5) { index in
                Capsule()
                    .frame(height: 6)
                    .foregroundColor(index <= currentStep ? .green : Color.secondary.opacity(0.2))
                    .animation(.spring(), value: currentStep)
            }
        }
    }
    
   
    
    private var welcomeScreen: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 100, height: 100)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)
                }
                
                Text("Welcome to\nMacrode")
                    .font(.system(size: 38, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
            }
            
            VStack(alignment: .leading, spacing: 20) {
                FeatureRow(icon: "lock.shield.fill", color: .green, title: "100% Offline & Private", description: "Your data never leaves this device.")
                FeatureRow(icon: "sparkles", color: .yellow, title: "Quick Logging", description: "Easily add meals and track your daily macros.")
                FeatureRow(icon: "waveform.path.ecg", color: .purple, title: "Calorie Adaptation", description: "Helps you understand your metabolism over time.")
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            
            Spacer()
            
            nextButton(title: "Let's Build Your Profile")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
    private var bodyStatsScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("About You")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("We use these values to calculate base energy usage.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 18) {
                Picker("Sex", selection: $isMale) {
                    Text("Male").tag(true)
                    Text("Female").tag(false)
                }
                .pickerStyle(.segmented)
                
                ValueSlider(title: "Age", icon: "calendar", value: $age, range: 10...120, step: 1, unit: " y", format: "%.0f")
                ValueSlider(title: "Height", icon: "ruler", value: $heightCM, range: 100...250, step: 1, unit: " cm", format: "%.0f")
                ValueSlider(title: "Weight", icon: "scalemass", value: $weightKG, range: 30...200, step: 0.5, unit: " kg", format: "%.1f")
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            
            Spacer()
            
            nextButton(title: "Continue")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .onTapGesture { isInputActive = false }
    }
    
    private var goalsScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 8) {
                Text("Your Goals")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Tell us what you want to achieve.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 18) {
                Text("Primary Goal").font(.headline)
                
                HStack(spacing: 10) {
                    ForEach(GoalType.allCases, id: \.self) { type in
                        Button(action: {
                            playHaptic()
                            goal = type
                        }) {
                            VStack(spacing: 8) {
                                Image(systemName: type.icon)
                                    .font(.title3)
                                Text(LocalizedStringKey(type.rawValue))
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .multilineTextAlignment(.center)
                            }
                            .foregroundColor(goal == type ? .green : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(goal == type ? Color.green.opacity(0.12) : Color.secondary.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(goal == type ? Color.green : Color.clear, lineWidth: 1.5)
                            )
                        }
                    }
                }
                
                Text("Activity Level").font(.headline).padding(.top, 8)
                
                VStack(spacing: 10) {
                    ForEach(ActivityLevel.allCases, id: \.self) { level in
                        Button(action: {
                            playHaptic()
                            activityLevel = level
                        }) {
                            HStack {
                                Text(LocalizedStringKey(level.rawValue))
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                Spacer()
                                if activityLevel == level {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding()
                            .background(activityLevel == level ? Color.green.opacity(0.1) : Color.secondary.opacity(0.06))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(activityLevel == level ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                
                Text("Diet Template").font(.headline).padding(.top, 8)
                
                Picker("Diet Template", selection: $dietTemplate) {
                    ForEach(DietTemplate.allCases, id: \.self) { type in Text(LocalizedStringKey(type.rawValue)).tag(type) }
                }
                .pickerStyle(.menu)
                .padding()
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(12)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            
            Spacer()
            
            nextButton(title: "Calculate My Macros")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
    private var resultScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Your Recommended Plan")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("These targets serve as an initial estimate, and adapt to your log updates.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("\(Int(computedMacros.calories))")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(.green)
                    Text("Daily Calories (kcal)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                Divider()
                
                HStack(spacing: 20) {
                    MacroPreviewCol(name: "Protein", amount: "\(Int(computedMacros.protein))g", color: .purple)
                    MacroPreviewCol(name: "Carbs", amount: "\(Int(computedMacros.carbs))g", color: .orange)
                    MacroPreviewCol(name: "Fats", amount: "\(Int(computedMacros.fat))g", color: .blue)
                }
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            
            Spacer()
            
            nextButton(title: "Try It Out")
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
    }
    
    private var interactiveScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Let's Log Your First Snack")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            CalorieHUD(consumed: hasLoggedDummy ? 105 : 0, target: computedMacros.calories, isSocialDay: false)
                .frame(width: 250, height: 250)
                .padding()
            
            HStack(spacing: 20) {
                MacroPreviewCol(name: "Protein", amount: hasLoggedDummy ? "1g" : "0g", color: .purple)
                MacroPreviewCol(name: "Carbs", amount: hasLoggedDummy ? "27g" : "0g", color: .orange)
                MacroPreviewCol(name: "Fats", amount: hasLoggedDummy ? "0g" : "0g", color: .blue)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 24)
            
            if !hasLoggedDummy {
                Button(action: {
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
                        hasLoggedDummy = true
                        playHaptic()
                    }
                }) {
                    Text("Log a Banana ðŸŒ (105 kcal)")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow)
                        .cornerRadius(16)
                        .shadow(color: .yellow.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.horizontal, 24)
            } else {
                Text("Awesome! You're ready.")
                    .font(.headline)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }
            
            Spacer()
            Button(action: saveAndFinish) {
                Text("Enter Macrode")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(hasLoggedDummy ? LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.gray, .gray.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(16)
                    .shadow(color: hasLoggedDummy ? .green.opacity(0.4) : .clear, radius: 8, x: 0, y: 4)
            }
            .disabled(!hasLoggedDummy)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
   
    
    private func nextButton(title: String) -> some View {
        Button(action: {
            playHaptic()
            isInputActive = false
            withAnimation(.spring()) { currentStep += 1 }
        }) {
            Text(LocalizedStringKey(title))
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(16)
                .shadow(color: .green.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
    
    private func saveAndFinish() {
        playHaptic()
        
        let macros = computedMacros
        let w = weightKG
        let water = Int((w / 20.0) * 1000)
        
        let startOfToday = Calendar.current.startOfDay(for: Date())
        
        let descriptor = FetchDescriptor<DailyLog>()
        let allLogs = (try? context.fetch(descriptor)) ?? []
        
        if let existingTodayLog = allLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfToday) }) {
            existingTodayLog.calorieTarget = macros.calories
            existingTodayLog.proteinTarget = macros.protein
            existingTodayLog.carbsTarget = macros.carbs
            existingTodayLog.fatTarget = macros.fat
            existingTodayLog.bodyWeight = w
            existingTodayLog.waterTargetML = water
        } else {
            let newLog = DailyLog(
                date: startOfToday,
                calorieTarget: macros.calories,
                proteinTarget: macros.protein,
                carbsTarget: macros.carbs,
                fatTarget: macros.fat,
                waterTargetML: water,
                bodyWeight: w
            )
            context.insert(newLog)
        }
        
        context.safeSave()
        WidgetCenter.shared.reloadAllTimelines()
        
        withAnimation(.spring()) { hasSeenOnboarding = true }
    }
    
    private func playHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

// MARK: - REUSABLE SUBVIEWS

struct ValueSlider: View {
    let title: String
    let icon: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String
    let format: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
                Text(LocalizedStringKey(title))
                    .foregroundColor(.primary)
                Spacer()
                Text(String(format: format, value) + unit)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            Slider(value: $value, in: range, step: step)
                .accentColor(.green)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct MacroPreviewCol: View {
    let name: String
    let amount: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(amount)
                .font(.headline)
                .foregroundColor(.primary)
            Text(LocalizedStringKey(name))
                .font(.caption2)
                .foregroundColor(color)
                .fontWeight(.bold)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }
};struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.headline)
                Text(LocalizedStringKey(description))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
