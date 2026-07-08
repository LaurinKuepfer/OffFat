import SwiftUI
import SwiftData
import Charts

struct WeeklyCalorieChartCard: View {
    var selectedDate: Date
    var allMeals: [ConsumedMeal]
    var logsDictionary: [Date: DailyLog]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack { 
                    Image(systemName: "chart.bar.fill").foregroundColor(.orange)
                    Text("Weekly Calories").font(.headline) 
                    Spacer()
                }
                Text("Compare your daily intake against your targets.").font(.caption).foregroundColor(.secondary)
            }
            
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: selectedDate)
            let past7Days = (0..<7).reversed().compactMap { calendar.date(byAdding: .day, value: -$0, to: today) }
            
            Chart {
                ForEach(past7Days, id: \.self) { date in
                    let dayStart = calendar.startOfDay(for: date)
                    let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86400)
                    let meals = allMeals.filter { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd }
                    let cals = meals.reduce(0) { $0 + $1.calories }
                    let target = logsDictionary[dayStart]?.calorieTarget ?? 2000
                    
                    BarMark(
                        x: .value("Day", date, unit: .day),
                        y: .value("Calories", cals)
                    )
                    .foregroundStyle(cals > target ? Color.blue.gradient : Color.green.gradient)
                    .cornerRadius(4)
                    
                    RuleMark(
                        y: .value("Target", target)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .foregroundStyle(.secondary.opacity(0.5))
                }
            }
            .frame(height: 180)
            .chartXAxis { 
                AxisMarks(values: .stride(by: .day)) { _ in 
                    AxisValueLabel(format: .dateTime.weekday(.narrow)) 
                } 
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .padding(.horizontal, 24)
    }
}


struct WeightTrackerCard: View {
    @Environment(\.modelContext) private var context
    var dailyLogs: [DailyLog]
    var currentLog: DailyLog?
    var selectedDate: Date
    
    @State private var showingMeasurementsSheet = false
    
    private var smoothedData: [(Date, Double)] {
        let logsWithWeight = dailyLogs.filter { $0.bodyWeight != nil }.sorted(by: { $0.date < $1.date })
        guard logsWithWeight.count >= 2 else { return [] }
        
        let alpha = 0.3
        var data: [(Date, Double)] = []
        var currentEWMA: Double? = nil
        
        for log in logsWithWeight {
            if let weight = log.bodyWeight {
                if let last = currentEWMA {
                    currentEWMA = (alpha * weight) + ((1 - alpha) * last)
                } else {
                    currentEWMA = weight
                }
                if let smoothed = currentEWMA {
                    data.append((log.date, smoothed))
                }
            }
        }
        return data
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "ruler.fill").foregroundColor(.purple)
                    Text("Measurements").font(.headline)
                    Spacer()
                    Button(action: {
                        HapticManager.shared.impact(.light)
                        showingMeasurementsSheet = true
                    }) {
                        Text(currentLog?.bodyWeight.map { "\($0, specifier: "%.1f") kg" } ?? "Log Metrics")
                            .font(.subheadline).fontWeight(.bold).foregroundColor(currentLog?.bodyWeight != nil ? .primary : .white)
                            .padding(.horizontal, 12).padding(.vertical, 6).background(currentLog?.bodyWeight != nil ? Color.secondary.opacity(0.2) : Color.purple).cornerRadius(8)
                    }
                }
                Text("Track your weight trends over time.").font(.caption).foregroundColor(.secondary)
            }
            
            let logsWithWeight = dailyLogs.filter { $0.bodyWeight != nil }.sorted(by: { $0.date < $1.date })
            if logsWithWeight.count >= 2 {                
                Chart {
                    ForEach(logsWithWeight) { log in
                        if let weight = log.bodyWeight {
                            PointMark(x: .value("Date", log.date), y: .value("Raw Weight", weight))
                                .foregroundStyle(Color.purple.opacity(0.4))
                        }
                    }
                    
                    ForEach(smoothedData, id: \.0) { point in
                        AreaMark(x: .value("Date", point.0), y: .value("Trend", point.1))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.4), Color.clear]), startPoint: .top, endPoint: .bottom))
                        
                        LineMark(x: .value("Date", point.0), y: .value("Trend", point.1))
                            .interpolationMethod(.monotone)
                            .foregroundStyle(Color.purple.gradient)
                    }
                }
                .frame(height: 120)
                .chartYScale(domain: .automatic(includesZero: false))
                .chartXAxis { 
                    AxisMarks(values: .stride(by: .day)) { _ in 
                        AxisTick()
                        AxisValueLabel(format: .dateTime.weekday(), centered: true) 
                    } 
                }
            } else {
                VStack { 
                    Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundColor(.secondary.opacity(0.3))
                    Text("Log your weight for a few days to see your trend.").font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center) 
                }
                .frame(maxWidth: .infinity).frame(height: 100)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
        .sheet(isPresented: $showingMeasurementsSheet) {
            if let log = currentLog {
                MeasurementsSheet(log: log)
            }
        }
    }
}
