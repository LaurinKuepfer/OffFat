import SwiftUI
import SwiftData
import WidgetKit

struct WeeklyCalendarView: View {
    @Binding var selectedDate: Date
    @Binding var showingHistorySheet: Bool
    var goalsMetCache: [Date: Bool]
    var firstLaunchDate: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                let locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                Text(selectedDate.formatted(.dateTime.month(.wide).year().locale(locale))).font(.headline).foregroundColor(.primary)
                Spacer()
                Button(action: { HapticManager.shared.impact(.light); showingHistorySheet = true }) {
                    HStack(spacing: 4) { Text("History"); Image(systemName: "calendar") }.font(.subheadline).foregroundColor(.green)
                }
            }
            .padding(.horizontal, 24)
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 12) {
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        let maxDaysToShow = 14
                        let firstLaunch = calendar.startOfDay(for: Date(timeIntervalSince1970: firstLaunchDate))
                        
                        ForEach(-maxDaysToShow...0, id: \.self) { dayOffset in
                            if let date = calendar.date(byAdding: .day, value: dayOffset, to: today), date >= firstLaunch {
                                let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                let isCurrentDay = calendar.isDateInToday(date)
                                let hitGoal = goalsMetCache[calendar.startOfDay(for: date)] == true
                                
                                VStack(spacing: 6) {
                                    let appLanguage = UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")?.string(forKey: "appLanguage") ?? "system"
                                    let locale = appLanguage == "system" ? Locale.current : Locale(identifier: appLanguage)
                                    
                                    Text(date.formatted(.dateTime.weekday(.short).locale(locale))).font(.caption2).fontWeight(isSelected ? .bold : .regular).foregroundColor(isSelected ? .primary : .secondary)
                                    ZStack {
                                        if hitGoal { Circle().stroke(Color.green, lineWidth: 2).frame(width: 38, height: 38) }
                                        Circle().fill(isSelected ? Color.primary : Color.clear).frame(width: 32, height: 32)
                                        Text(date.formatted(.dateTime.day().locale(locale))).font(.subheadline).fontWeight(isSelected ? .bold : .medium).foregroundColor(isSelected ? Color(UIColor.systemBackground) : (isCurrentDay ? .green : .primary))
                                    }
                                }
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                                .accessibilityElement(children: .combine)
                                .accessibilityAddTraits(.isButton)
                                .accessibilityValue(isSelected ? "Selected" : "")
                                .onTapGesture { HapticManager.shared.impact(.light); withAnimation(.spring) { selectedDate = date } }
                                .id(date)
                            }
                        }
                    }.padding(.horizontal, 24).onAppear { proxy.scrollTo(Calendar.current.startOfDay(for: Date()), anchor: .trailing) }
                }
            }
        }
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
    }
}

extension View {
    func dashboardCardStyle() -> some View {
        self.modifier(CardModifier())
    }
}

struct FastingCompactCard: View {
    var allConsumedMeals: [ConsumedMeal]
    
    var body: some View {
        let lastMeal = allConsumedMeals.filter { $0.consumedAt < Date() }.max(by: { $0.consumedAt < $1.consumedAt })
        let hours = lastMeal.map { Date().timeIntervalSince($0.consumedAt) / 3600.0 } ?? 0
        
        return HStack(spacing: 8) {
            Image(systemName: "timer")
                .foregroundColor(.blue)
                .font(.body)
            VStack(alignment: .leading, spacing: 0) {
                Text("Time Since Last Meal")
                    .font(.caption2).foregroundColor(.secondary)
                if lastMeal != nil {
                    Text(String(format: "%.1fh", hours))
                        .font(.subheadline).fontWeight(.bold)
                        .contentTransition(.numericText())
                } else {
                    Text("â€”").font(.subheadline).fontWeight(.bold)
                }
            }
            Spacer()
        }
        .dashboardCardStyle()
        .padding(.horizontal, 24)
    }
}

struct SupplementTrackerCard: View {
    @Environment(\.modelContext) private var context
    var allSupplements: [Supplement]
    var selectedDate: Date
    
    var body: some View {
        let currentDayOfWeek = Calendar.current.component(.weekday, from: selectedDate)
        let todaysSupplements = allSupplements.filter { supp in
            let days = supp.scheduledDays.split(separator: ",").compactMap { Int($0) }
            return days.contains(currentDayOfWeek)
        }
        
        if todaysSupplements.isEmpty { return AnyView(EmptyView()) }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateString = formatter.string(from: selectedDate)
        let columns = [GridItem(.flexible()), GridItem(.flexible())]
        
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack { Image(systemName: "pills.fill").foregroundColor(.pink); Text("Supplements").font(.headline) }
                
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(todaysSupplements) { supp in
                        let isTaken = supp.datesTaken.contains(dateString)
                        
                        Button(action: {
                            HapticManager.shared.impact(.light)
                            withAnimation(.spring) {
                                if isTaken { supp.datesTaken.removeAll(where: { $0 == dateString }) }
                                else { supp.datesTaken.append(dateString) }
                                context.safeSave()
                            }
                        }) {
                            HStack {
                                Image(systemName: isTaken ? "checkmark.circle.fill" : "circle")
                                Text(supp.name).lineLimit(1)
                            }
                            .font(.subheadline).fontWeight(.semibold).foregroundColor(isTaken ? .white : .primary)
                            .padding(.vertical, 12).frame(maxWidth: .infinity)
                            .background(isTaken ? Color.pink : Color.secondary.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .dashboardCardStyle()
            .padding(.horizontal, 24)
        )
    }
}

struct FrequentMealsCard: View {
    @Environment(\.modelContext) private var context
    var frequentMeals: [ConsumedMeal]
    
    var body: some View {
        if frequentMeals.isEmpty { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 16) {
                HStack { Image(systemName: "sparkles").foregroundColor(.yellow); Text("Usually at this time...").font(.headline) }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(frequentMeals, id: \.id) { meal in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(meal.name).font(.subheadline).fontWeight(.bold).lineLimit(1)
                                Text("\(Int(meal.calories)) kcal").font(.caption).foregroundColor(.green)
                                Button(action: {
                                    HapticManager.shared.notification(.success)
                                    let now = Date()
                                    let newMeal = ConsumedMeal(name: meal.name, calories: meal.calories, protein: meal.protein, carbs: meal.carbs, fat: meal.fat, weightGrams: meal.weightGrams, consumedAt: now, mealCategory: autoMealCategory(for: now), fiber: meal.fiber, sugar: meal.sugar, saturatedFat: meal.saturatedFat, sodium: meal.sodium)
                                    context.insert(newMeal)
                                    context.safeSave()
                                    HealthKitManager.shared.saveMeal(name: meal.name, calories: meal.calories, protein: meal.protein, carbs: meal.carbs, fat: meal.fat, date: now)
                                    Task { WidgetCenter.shared.reloadAllTimelines() }
                                }) {
                                    Text("Log").font(.caption).fontWeight(.bold).foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(Color.green).cornerRadius(12)
                                }
                            }
                            .dashboardCardStyle()
                            .frame(width: 140)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        )
    }
}

struct MealTimeline: View {
    @Environment(\.modelContext) private var context
    var selectedDateMeals: [ConsumedMeal]
    var allConsumedMeals: [ConsumedMeal]
    @Binding var editingMeal: ConsumedMeal?
    @Binding var dynamicTarget: Double
    @Binding var consumedCalories: Double
    
    @State private var mealToDelete: ConsumedMeal?
    
    var body: some View {
        let categoryOrder = ["Breakfast", "Lunch", "Dinner", "Snack"]
        let categoryIcons: [String: String] = ["Breakfast": "sunrise.fill", "Lunch": "sun.max.fill", "Dinner": "moon.stars.fill", "Snack": "leaf.fill"]
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack { Image(systemName: "clock.fill").foregroundColor(.blue); Text("Today's Timeline").font(.headline) }
            
            if selectedDateMeals.isEmpty {
                VStack { Image(systemName: "fork.knife").font(.largeTitle).foregroundColor(.secondary.opacity(0.3)); Text("Ready to fuel your day? Log your first meal!").font(.caption).foregroundColor(.secondary) }.frame(maxWidth: .infinity).padding(.vertical, 30)
            } else {
                let grouped = Dictionary(grouping: selectedDateMeals) { meal in
                    categoryOrder.contains(meal.mealCategory) ? meal.mealCategory : "Snack"
                }
                
                ForEach(categoryOrder, id: \.self) { category in
                    if let meals = grouped[category], !meals.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: categoryIcons[category] ?? "fork.knife")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text(LocalizedStringKey(category))
                                    .font(.caption).fontWeight(.bold).foregroundColor(.secondary)
                                    .textCase(.uppercase)
                            }
                            .padding(.top, 4)
                            
                            ForEach(meals.sorted { $0.consumedAt < $1.consumedAt }) { meal in
                                Button(action: {
                                    HapticManager.shared.impact(.light)
                                    editingMeal = meal
                                }) {
                                    MealRow(meal: meal, isNested: true)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button(action: { relogMeal(meal) }) {
                                        Label("Relog Meal", systemImage: "arrow.counterclockwise")
                                    }
                                    Button(role: .destructive, action: { mealToDelete = meal }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .dashboardCardStyle()
        .padding(.horizontal, 24)
        .confirmationDialog("Delete Meal?", isPresented: Binding(
            get: { mealToDelete != nil },
            set: { if !$0 { mealToDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let meal = mealToDelete { deleteMeal(meal) }
            }
        }
    }
    
    private func relogMeal(_ meal: ConsumedMeal) {
        HapticManager.shared.impact(.light)
        let hour = Calendar.current.component(.hour, from: Date())
        let autoCategory: String = hour < 10 ? "Breakfast" : (hour < 14 ? "Lunch" : (hour < 17 ? "Snack" : "Dinner"))
        
        let copy = ConsumedMeal(
            name: meal.name,
            calories: meal.calories,
            protein: meal.protein,
            carbs: meal.carbs,
            fat: meal.fat,
            weightGrams: meal.weightGrams,
            consumedAt: Date(),
            mealCategory: autoCategory,
            fiber: meal.fiber,
            sugar: meal.sugar,
            saturatedFat: meal.saturatedFat,
            sodium: meal.sodium
        )
        withAnimation { context.insert(copy) }
        context.safeSave()
        Task { WidgetCenter.shared.reloadAllTimelines() }
        updateLiveActivity()
    }
    
    private func deleteMeal(_ meal: ConsumedMeal) { 
        HapticManager.shared.impact(.light)
        withAnimation { context.delete(meal) }
        context.safeSave()
        Task { WidgetCenter.shared.reloadAllTimelines() }
        updateLiveActivity()
    }
    
    private func updateLiveActivity() {
        let pastMeals = allConsumedMeals.filter { $0.consumedAt < Date() }.sorted { $0.consumedAt > $1.consumedAt }
        let hoursSinceLastMeal = pastMeals.first.map { Date().timeIntervalSince($0.consumedAt) / 3600.0 } ?? 0
        let calsLeft = max(0, Int(dynamicTarget - consumedCalories))
        var targetHours: Double = 0
        if UserDefaults.standard.bool(forKey: "enableFasting") {
            let scheduleStr = UserDefaults.standard.string(forKey: "fastingSchedule") ?? FastingSchedule.off.rawValue
            let schedule = FastingSchedule(rawValue: scheduleStr) ?? .off
            targetHours = schedule.targetHours
        }
        LiveActivityManager.shared.updateOrStartFastingActivity(caloriesLeft: calsLeft, fastingHours: hoursSinceLastMeal, fastingTargetHours: targetHours)
    }
}
