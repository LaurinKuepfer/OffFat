import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \ConsumedMeal.consumedAt, order: .reverse) private var allMeals: [ConsumedMeal]
    @Query private var dailyLogs: [DailyLog]
    
    @Binding var selectedDate: Date
    
    @State private var showingWeightAlert = false
    @State private var weightInput: String = ""
    @State private var reviewData: ReviewData? = nil

    private var currentLog: DailyLog? {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        return dailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) })
    }
    
    private var logsDictionary: [Date: DailyLog] {
        var dict = [Date: DailyLog]()
        for log in dailyLogs { dict[Calendar.current.startOfDay(for: log.date)] = log }
        return dict
    }
    
   
    
    private var currentStreak: Int {
        var streak = 0
        let calendar = Calendar.current
        var checkDate = calendar.startOfDay(for: Date())
        
        var dict = [Date: DailyLog]()
        for log in dailyLogs { dict[calendar.startOfDay(for: log.date)] = log }
        
        var dailyCalories = [Date: Double]()
        for meal in allMeals {
            let day = calendar.startOfDay(for: meal.consumedAt)
            dailyCalories[day, default: 0] += meal.calories
        }
        
        func goalMet(on date: Date) -> Bool {
            let start = calendar.startOfDay(for: date)
            guard let calories = dailyCalories[start] else { return false }
            return calories > 500
        }
        
        if goalMet(on: checkDate) { streak += 1 }
        
        checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate.addingTimeInterval(-86400)
        for _ in 0..<100 {
            if goalMet(on: checkDate) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate.addingTimeInterval(-86400)
            } else { break }
        }
        return streak
    }
    
    @State private var trueMetabolism: TDEEResult? = nil
    @State private var showingTDEEInfo = false
    @State private var isCalculatingInsights = true

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground),
                        Color.purple.opacity(0.04),
                        Color.pink.opacity(0.04),
                        Color(uiColor: .systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .adaptiveBackgroundTexture()

                ScrollView {
                    VStack(spacing: 24) {
                    
                    if currentStreak > 0 { streakBanner }
                    
                    reviewSection
                    
                    if isCalculatingInsights {
                        metabolismInsightCard(result: nil)
                    } else { 
                        metabolismInsightCard(result: trueMetabolism) 
                    }
                    
                    WeeklyCalorieChartCard(selectedDate: selectedDate, allMeals: allMeals, logsDictionary: logsDictionary)
                    
                    WeightTrackerCard(dailyLogs: dailyLogs, currentLog: currentLog, selectedDate: selectedDate)
                }
                .padding(.vertical, 20)
                .padding(.bottom, 80)
            }
            .navigationTitle("Insights")
            .onAppear {
                ReviewManager.shared.checkAndPromptReview(currentStreak: currentStreak)
            }
            .onChange(of: selectedDate) { _, _ in
                isCalculatingInsights = true
                let logsData = dailyLogs.map { DailyLogData(from: $0) }
                let mealsData = allMeals.map { ConsumedMealData(from: $0) }
                
                let result = MetabolismEngine.calculateTrueTDEE(dailyLogs: logsData, allMeals: mealsData)
                
                trueMetabolism = result
                isCalculatingInsights = false
            }
            .onAppear {
                isCalculatingInsights = true
                let logsData = dailyLogs.map { DailyLogData(from: $0) }
                let mealsData = allMeals.map { ConsumedMealData(from: $0) }
                
                let result = MetabolismEngine.calculateTrueTDEE(dailyLogs: logsData, allMeals: mealsData)
                
                trueMetabolism = result
                isCalculatingInsights = false
            }
            .sheet(item: $reviewData) { data in
                ReviewReportView(data: data)
            }
        }
    }
}
    
    private var reviewSection: some View {
        HStack(spacing: 16) {
            Button(action: {
                reviewData = ReviewEngine.generateReview(days: 7, logs: dailyLogs, meals: allMeals)
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                    Text("Weekly Review")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(20)
            }
            
            Button(action: {
                reviewData = ReviewEngine.generateReview(days: 30, logs: dailyLogs, meals: allMeals)
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.title)
                    Text("Monthly Review")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(LinearGradient(gradient: Gradient(colors: [.purple, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing))
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 24)
    }
    
   
    private var streakBanner: some View {
        HStack {
            Image(systemName: "flame.fill").foregroundColor(.orange)
            Text("\(currentStreak) Day Streak").font(.headline).fontWeight(.bold).foregroundColor(.orange)
            Spacer()
            Text("Perfect Days!").font(.subheadline).foregroundColor(.secondary)
        }
        .padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2).padding(.horizontal, 24)
    }
    
    private func metabolismInsightCard(result: TDEEResult?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack { 
                Image(systemName: "brain.head.profile").foregroundColor(.purple)
                Text("Smart Insights").font(.headline) 
                Spacer()
                Button(action: { showingTDEEInfo = true }) {
                    Image(systemName: "info.circle").foregroundColor(.secondary)
                }
            }
            
            if isCalculatingInsights {
                ProgressView("Crunching your data...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if let tdee = result?.tdee {
                Text("Your True Metabolism is approx **\(Int(tdee)) kcal**.")
                    .font(.subheadline).foregroundColor(.primary).fixedSize(horizontal: false, vertical: true)
                Text("This is your estimated daily calorie burn rate, based on your logs and weight.")
                    .font(.caption).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Calculating True Metabolism...")
                    .font(.subheadline).fontWeight(.medium)
                ProgressView(value: Double(result?.validDaysLogged ?? 0), total: 21.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .purple))
                Text("Needs 21 days of tracked data. Currently \(result?.validDaysLogged ?? 0)/21 days.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2).padding(.horizontal, 24)
        .sheet(isPresented: $showingTDEEInfo) {
            InfoPopupView(title: "True Metabolism (TDEE)", description: "TDEE stands for Total Daily Energy Expenditure. It represents the total number of calories you burn in a day.\n\nMacrode calculates this by analyzing your logged calories and body weight over a 21-day period to find your exact metabolic rate, eliminating the need for generic formulas.")
                .presentationDetents([.fraction(0.4), .medium])
        }
    }
    

    

}
