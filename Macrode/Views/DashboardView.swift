import SwiftUI
import SwiftData
import WidgetKit

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var dailyLogs: [DailyLog]
    @Query private var allSupplements: [Supplement]

    @AppStorage("hasLoadedStarterData") private var hasLoadedStarterData: Bool = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = false
    @AppStorage("firstLaunchDate") private var firstLaunchDate: Double = Date().timeIntervalSince1970
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial: Bool = false
    @AppStorage("enableFasting") private var enableFasting = false

    @Binding var selectedDate: Date
    @Binding var selectedTab: Int
    
    @State private var showingGoalsSheet = false
    @State private var showingHistorySheet = false
    @State private var goalsMetCache: [Date: Bool] = [:]
    
    private var currentLog: DailyLog {
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        if let log = dailyLogs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            return log
        } else {
            let previousLogs = dailyLogs.filter { $0.date < startOfDay }.sorted { $0.date > $1.date }
            if let lastLog = previousLogs.first {
                return DailyLog(date: startOfDay, calorieTarget: lastLog.calorieTarget, proteinTarget: lastLog.proteinTarget, carbsTarget: lastLog.carbsTarget, fatTarget: lastLog.fatTarget, waterTargetML: lastLog.waterTargetML, bodyWeight: lastLog.bodyWeight)
            } else {
                return DailyLog(date: startOfDay)
            }
        }
    }
    
    @State private var viewModel = DashboardViewModel()
    
    private var isToday: Bool { Calendar.current.isDateInToday(selectedDate) }
    
    private func updateLogsDictionary() {
        viewModel.updateLogsDictionary(dailyLogs: dailyLogs)
    }

   
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground),
                        Color.blue.opacity(0.03),
                        Color.purple.opacity(0.03),
                        Color(uiColor: .systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .adaptiveBackgroundTexture()
                
                ScrollView {
                    VStack(spacing: 20) {
                        WeeklyCalendarView(selectedDate: $selectedDate, showingHistorySheet: $showingHistorySheet, goalsMetCache: goalsMetCache, firstLaunchDate: firstLaunchDate).padding(.top, 6)
                        
                        if enableFasting {
                            FastingWidgetView()
                        }
                        
                        DailyDashboardView(selectedDate: selectedDate, currentLog: currentLog, allSupplements: allSupplements)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if !hasLoadedStarterData { 
                    loadStarterDatabase()
                    hasLoadedStarterData = true 
                }
                updateLogsDictionary()
                updateGoalsMetCache()
            }
            .onChange(of: selectedDate) { _, newDate in
                ensureDailyLogExists(for: newDate)
            }
            .onChange(of: dailyLogs.count) { _, _ in
                updateLogsDictionary()
                updateGoalsMetCache()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {

                        Button(action: { 
                            playHaptic()
                            showingGoalsSheet = true 
                        }) {
                            Image(systemName: "target").foregroundColor(.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: Binding(get: { !hasCompletedTutorial && hasSeenOnboarding }, set: { _ in })) {
                VStack(spacing: 30) {
                    Text("Quick Guide").font(.largeTitle).fontWeight(.bold).padding(.top, 40)
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(spacing: 16) {
                            Image(systemName: "book.pages.fill").font(.largeTitle).foregroundColor(.green).frame(width: 45)
                            VStack(alignment: .leading) { 
                                Text("Log Meals").font(.headline)
                                Text("Use the Library tab below to log foods and recipes.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack(spacing: 16) {
                            Image(systemName: "target").font(.largeTitle).foregroundColor(.primary).frame(width: 45)
                            VStack(alignment: .leading) { 
                                Text("Adjust Your Goals").font(.headline)
                                Text("Tap the target icon anytime to adjust macros and supplements.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack(spacing: 16) {
                            Image(systemName: "banknote.fill").font(.largeTitle).foregroundColor(.orange).frame(width: 45)
                            VStack(alignment: .leading) { 
                                Text("Energy Balance").font(.headline)
                                Text("Your daily targets adapt automatically to smooth out calorie spikes.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        HStack(spacing: 16) {
                            Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundColor(.purple).frame(width: 45)
                            VStack(alignment: .leading) { 
                                Text("Check Insights").font(.headline)
                                Text("Use the Insights tab to see your weight, streak, and metabolism.").font(.subheadline).foregroundColor(.secondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }.padding(.horizontal, 20)
                    Spacer()
                    Button(action: { 
                        playHaptic()
                        hasCompletedTutorial = true 
                    }) {
                        Text("Got it!").font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(Color.blue).cornerRadius(16)
                    }.padding(.horizontal, 30).padding(.bottom, 30)
                }
                .presentationDetents([.fraction(0.7)]).interactiveDismissDisabled()
            }
            .sheet(isPresented: $showingGoalsSheet) { 
                EditGoalsView(dailyLog: currentLog).presentationDetents([.fraction(0.8)]) 
            }
            .sheet(isPresented: $showingHistorySheet) {
                NavigationStack {
                    let groupedLogs = Dictionary(grouping: dailyLogs.sorted(by: { $0.date > $1.date })) { log -> String in
                        let formatter = DateFormatter()
                        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                        formatter.locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                        formatter.dateFormat = "MMMM yyyy"
                        return formatter.string(from: log.date)
                    }
                    
                    let sortedMonths = groupedLogs.keys.sorted { month1, month2 in
                        let formatter = DateFormatter()
                        let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                        formatter.locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                        formatter.dateFormat = "MMMM yyyy"
                        guard let d1 = formatter.date(from: month1), let d2 = formatter.date(from: month2) else { return false }
                        return d1 > d2
                    }
                    
                    List {
                        ForEach(sortedMonths, id: \.self) { month in
                            Section(header: Text(month).font(.headline).foregroundColor(.primary)) {
                                ForEach(groupedLogs[month] ?? []) { log in
                                    Button(action: {
                                        playHaptic()
                                        withAnimation(.spring) {
                                            selectedDate = log.date
                                        }
                                        showingHistorySheet = false
                                    }) {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                                                let locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                                                Text(log.date.formatted(.dateTime.weekday(.wide).day().locale(locale)))
                                                    .font(.headline)
                                                    .foregroundColor(.primary)
                                                Text("\(Int(log.calorieTarget)) kcal Goal")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if goalsMetCache[Calendar.current.startOfDay(for: log.date)] == true {
                                                Image(systemName: "flame.fill")
                                                    .foregroundColor(.orange)
                                            }
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .navigationTitle("Your History")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Close") { showingHistorySheet = false }
                        }
                    }
                }
                .presentationDetents([.fraction(0.85), .large])
            }
            .fullScreenCover(isPresented: Binding(get: { !hasSeenOnboarding }, set: { _ in })) { 
                OnboardingView() 
            }
        }
    }
    

    private func updateGoalsMetCache() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -14, to: today)!
        let end = calendar.date(byAdding: .day, value: 1, to: today)!
        
        let descriptor = FetchDescriptor<ConsumedMeal>(
            predicate: #Predicate { $0.consumedAt >= start && $0.consumedAt < end }
        )
        
        let recentMeals = (try? context.fetch(descriptor)) ?? []
        
        var logsDictionary: [Date: DailyLog] = [:]
        for log in dailyLogs {
            logsDictionary[calendar.startOfDay(for: log.date)] = log
        }
        
        var newCache: [Date: Bool] = [:]
        for dayOffset in -14...0 {
            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today) {
                let dayStart = calendar.startOfDay(for: date)
                let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
                
                let daysMeals = recentMeals.filter { $0.consumedAt >= dayStart && $0.consumedAt < dayEnd }
                if let log = logsDictionary[dayStart], !daysMeals.isEmpty {
                    let totalCals = daysMeals.reduce(0) { $0 + $1.calories }
                    newCache[dayStart] = totalCals <= log.calorieTarget
                } else {
                    newCache[dayStart] = false
                }
            }
        }
        self.goalsMetCache = newCache
    }

    private func ensureDailyLogExists(for date: Date) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        if !dailyLogs.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: startOfDay) }) {
            let previousLogs = dailyLogs.filter { $0.date < startOfDay }.sorted { $0.date > $1.date }
            if let lastLog = previousLogs.first {
                let newLog = DailyLog(date: startOfDay, calorieTarget: lastLog.calorieTarget, proteinTarget: lastLog.proteinTarget, carbsTarget: lastLog.carbsTarget, fatTarget: lastLog.fatTarget, waterTargetML: lastLog.waterTargetML, bodyWeight: lastLog.bodyWeight)
                context.insert(newLog)
            } else {
                let newLog = DailyLog(date: startOfDay)
                context.insert(newLog)
            }
            try? context.save()
        }
    }

    private func loadStarterDatabase() {
        let existing = try? context.fetch(FetchDescriptor<FoodItem>())
        if let existing = existing, !existing.isEmpty { return }
        
        for item in StarterDatabase.foods { context.insert(FoodItem(name: item.name, calories: item.calories, protein: item.protein, carbs: item.carbs, fat: item.fat, category: item.category)) }
        for recipe in StarterDatabase.recipes { context.insert(RecipeItem(name: recipe.name, calories: recipe.calories, protein: recipe.protein, carbs: recipe.carbs, fat: recipe.fat, instructions: recipe.instructions, category: recipe.category, prepTimeMinutes: recipe.prepTimeMinutes, difficulty: recipe.difficulty, systemImage: recipe.systemImage)) }
    }

    private func playHaptic() { HapticManager.shared.impact(.light) }
}


