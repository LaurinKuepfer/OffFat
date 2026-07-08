import SwiftUI
import SwiftData

struct WeeklyReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var dailyLogs: [DailyLog]
    @Query private var meals: [ConsumedMeal]
    
    @State private var averageCalories: Double = 0
    @State private var averageProtein: Double = 0
    @State private var weightDelta: Double = 0
    @State private var isCalculating = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if isCalculating {
                    ProgressView("Generating Report...")
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            Text("Your Weekly Summary")
                                .font(.largeTitle.weight(.heavy))
                                .padding(.top)
                            
                            VStack(spacing: 20) {
                                HStack {
                                    Text("Past 7 Days")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "calendar.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.purple)
                                }
                                
                                Divider()
                                
                                HStack {
                                    ReportStatBox(title: "Avg Calories", value: "\(Int(averageCalories))", unit: "kcal", color: .green)
                                    ReportStatBox(title: "Avg Protein", value: "\(Int(averageProtein))", unit: "g", color: .red)
                                }
                                
                                HStack {
                                    let weightText = weightDelta > 0 ? "+\(String(format: "%.1f", weightDelta))" : "\(String(format: "%.1f", weightDelta))"
                                    let weightColor: Color = weightDelta > 0 ? .orange : (weightDelta < 0 ? .green : .secondary)
                                    ReportStatBox(title: "Weight Delta", value: weightText, unit: "kg", color: weightColor)
                                    
                                    ReportStatBox(title: "Logged Days", value: "7", unit: "days", color: .blue)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(24)
                            .shadow(color: Color.black.opacity(0.08), radius: 10, x: 0, y: 4)
                            .padding(.horizontal)
                            
                            Text("Screenshot this card to share your progress with your coach or friends!")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }
            }
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                calculateReport()
            }
        }
    }
    
    private func calculateReport() {
        let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        // Calculate nutrition
        let recentMeals = meals.filter { $0.consumedAt >= oneWeekAgo }
        let totalCalories = recentMeals.reduce(0) { $0 + $1.calories }
        let totalProtein = recentMeals.reduce(0) { $0 + $1.protein }
        
        // Group by day to find unique active days
        let daysSet = Set(recentMeals.map { Calendar.current.startOfDay(for: $0.consumedAt) })
        let daysCount = max(1, Double(daysSet.count))
        
        averageCalories = totalCalories / daysCount
        averageProtein = totalProtein / daysCount
        
        // Calculate weight delta
        let recentLogs = dailyLogs.filter { $0.date >= oneWeekAgo && $0.bodyWeight != nil }.sorted { $0.date < $1.date }
        if let firstWeight = recentLogs.first?.bodyWeight, let lastWeight = recentLogs.last?.bodyWeight {
            weightDelta = lastWeight - firstWeight
        } else {
            weightDelta = 0
        }
        
        isCalculating = false
    }
}

struct ReportStatBox: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundColor(color)
                Text(unit)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(16)
    }
}
