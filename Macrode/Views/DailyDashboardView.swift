import SwiftUI
import SwiftData
import WidgetKit

struct DailyDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query private var selectedDateMeals: [ConsumedMeal]
    @Query private var allDailyLogs: [DailyLog]
    @Query private var allConsumedMeals: [ConsumedMeal]
    
    @AppStorage("userGoal") private var userGoal: GoalType = .maintain
    
    // Layout customization properties
    @AppStorage("activeDashboardBlocks") private var activeBlocksRaw: String = DashboardBlock.allCases.map { $0.rawValue }.joined(separator: ",")
    @AppStorage("enableMicronutrients") private var enableMicronutrients = false
    @State private var showingEditLayout = false
    
    @State private var viewModel = DashboardViewModel()
    @State private var showingCustomWaterAlert = false
    @State private var customWaterInput = ""
    
    var selectedDate: Date
    var currentLog: DailyLog
    var allSupplements: [Supplement]
    
    init(selectedDate: Date, currentLog: DailyLog, allSupplements: [Supplement]) {
        self.selectedDate = selectedDate
        self.currentLog = currentLog
        self.allSupplements = allSupplements
        
        let start = Calendar.current.startOfDay(for: selectedDate)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
        self._selectedDateMeals = Query(
            filter: #Predicate<ConsumedMeal> { $0.consumedAt >= start && $0.consumedAt < end },
            sort: \.consumedAt, order: .reverse
        )
        
        let lookback = Calendar.current.date(byAdding: .day, value: -60, to: start) ?? start.addingTimeInterval(-60 * 86400)
        self._allConsumedMeals = Query(filter: #Predicate<ConsumedMeal> { $0.consumedAt >= lookback })
        self._allDailyLogs = Query(filter: #Predicate<DailyLog> { $0.date >= lookback })
    }
    
    private var consumedCalories: Double { selectedDateMeals.reduce(0) { $0 + $1.calories } }
    private var consumedProtein: Double { selectedDateMeals.reduce(0) { $0 + $1.protein } }
    private var consumedCarbs: Double { selectedDateMeals.reduce(0) { $0 + $1.carbs } }
    private var consumedFat: Double { selectedDateMeals.reduce(0) { $0 + $1.fat } }
    
    private var consumedVitaminA: Double { selectedDateMeals.reduce(0) { $0 + ($1.vitaminA ?? 0) } }
    private var consumedVitaminC: Double { selectedDateMeals.reduce(0) { $0 + ($1.vitaminC ?? 0) } }
    private var consumedVitaminD: Double { selectedDateMeals.reduce(0) { $0 + ($1.vitaminD ?? 0) } }
    private var consumedCalcium: Double { selectedDateMeals.reduce(0) { $0 + ($1.calcium ?? 0) } }
    private var consumedIron: Double { selectedDateMeals.reduce(0) { $0 + ($1.iron ?? 0) } }
    private var consumedPotassium: Double { selectedDateMeals.reduce(0) { $0 + ($1.potassium ?? 0) } }
    private var consumedMagnesium: Double { selectedDateMeals.reduce(0) { $0 + ($1.magnesium ?? 0) } }
    
    private var baseTarget: Double {
        if let tdee = viewModel.cachedTDEE?.tdee {
            switch userGoal {
            case .lose: return tdee - 500
            case .gain: return tdee + 300
            case .maintain: return tdee
            }
        }
        return currentLog.calorieTarget
    }

    private var dynamicTarget: Double {
        return baseTarget
    }
    
    private var dynamicProteinTarget: Double {
        return currentLog.proteinTarget
    }

    private var dynamicCarbsTarget: Double {
        return currentLog.carbsTarget
    }
    
    private var dynamicFatTarget: Double {
        return currentLog.fatTarget
    }
    
    var activeBlocks: [DashboardBlock] {
        activeBlocksRaw.split(separator: ",").compactMap { DashboardBlock(rawValue: String($0)) }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            tdeeHeader
            
            ForEach(activeBlocks, id: \.self) { block in
                switch block {
                case .energyOverview:
                    energySection
                case .macros:
                    macrosSection
                    if enableMicronutrients {
                        micronutrientsSection
                    }
                case .quickActions:
                    actionsSection
                case .water:
                    waterSection
                case .fasting:
                    FastingCompactCard(allConsumedMeals: allConsumedMeals)
                case .frequentMeals:
                    FrequentMealsCard(frequentMeals: viewModel.frequentMeals)
                case .supplements:
                    SupplementTrackerCard(allSupplements: allSupplements, selectedDate: selectedDate)
                case .timeline:
                    MealTimeline(
                        selectedDateMeals: selectedDateMeals,
                        allConsumedMeals: allConsumedMeals,
                        editingMeal: $viewModel.editingMeal,
                        dynamicTarget: .constant(dynamicTarget),
                        consumedCalories: .constant(consumedCalories)
                    )
                }
            }
            
            Button(action: {
                HapticManager.shared.impact(.light)
                showingEditLayout = true
            }) {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Customize Layout")
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color(uiColor: .tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 10)
        }
        .onAppear {
            updateLiveActivity()
            recalculateEngines()
        }
        .onChange(of: consumedCalories) { _, _ in updateLiveActivity() }
        .onChange(of: allConsumedMeals.count) { _, _ in recalculateEngines() }
        .onChange(of: selectedDate) { _, _ in recalculateEngines() }
        .sheet(isPresented: $showingEditLayout) {
            EditDashboardLayoutView()
        }
        .sheet(isPresented: $viewModel.showingSmartSuggester) {
            SmartSuggesterView(
                remProtein: max(0, dynamicProteinTarget - consumedProtein),
                remCarbs: max(0, dynamicCarbsTarget - consumedCarbs),
                remFat: max(0, dynamicFatTarget - consumedFat),
                selectedDate: selectedDate
            ).presentationDetents([.fraction(0.6), .large])
        }
        .sheet(item: $viewModel.editingMeal) { meal in
            EditMealView(meal: meal).presentationDetents([.fraction(0.8), .large])
        }
        .sheet(isPresented: $viewModel.showingQuickAddSheet) { 
            QuickEstimateView(selectedDate: selectedDate, isRootPresented: $viewModel.showingQuickAddSheet, mainTabSelection: .constant(0)).presentationDetents([.fraction(0.5), .large]) 
        }
        .alert("Custom Water", isPresented: $showingCustomWaterAlert) {
            TextField("Amount (ml)", text: $customWaterInput)
                .keyboardType(.numberPad)
            Button("Add") {
                if let amount = Int(customWaterInput), amount > 0 {
                    addWater(amount)
                }
                customWaterInput = ""
            }
            Button("Cancel", role: .cancel) {
                customWaterInput = ""
            }
        } message: {
            Text("Enter the amount of water in ml.")
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private var tdeeHeader: some View {
        if let tdeeResult = viewModel.cachedTDEE {
            if let tdee = tdeeResult.tdee {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").foregroundColor(.yellow)
                    ProgressView(value: 21.0, total: 21.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                        .frame(width: 40)
                    Text("\(Int(tdee)) kcal")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.yellow)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.badge.clock.fill").foregroundColor(.yellow)
                    ProgressView(value: Double(tdeeResult.validDaysLogged), total: 21.0)
                        .progressViewStyle(LinearProgressViewStyle(tint: .yellow))
                        .frame(width: 40)
                    Text("\(tdeeResult.validDaysLogged)/21")
                        .font(.caption2).fontWeight(.bold).foregroundColor(.yellow)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }
    
    private var energySection: some View {
        FlipCardView {
            VStack(spacing: 6) {
                CalorieHUD(consumed: consumedCalories, target: dynamicTarget, isSocialDay: currentLog.isSocialDay)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: consumedCalories)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: dynamicTarget)
            }
            .padding(.horizontal, 24)
        } back: {
            VStack(spacing: 8) {
                Image(systemName: "flame.fill").font(.largeTitle).foregroundColor(.orange)
                Text("Energy Trend")
                    .font(.subheadline).foregroundColor(.secondary)
                Text("7-Day Avg: \(Int(baseTarget)) kcal")
                    .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, minHeight: 220)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 24)
        }
    }
    
    private var macrosSection: some View {
        FlipCardView {
            VStack(spacing: 12) {
                MacroBar(title: "Protein", consumed: consumedProtein, target: dynamicProteinTarget, baseColor: .red)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: consumedProtein)
                MacroBar(title: "Carbs", consumed: consumedCarbs, target: dynamicCarbsTarget, baseColor: .blue)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: consumedCarbs)
                MacroBar(title: "Fats", consumed: consumedFat, target: dynamicFatTarget, baseColor: .orange)
                    .animation(.spring(response: 0.4, dampingFraction: 0.6), value: consumedFat)
            }
            .padding(.horizontal, 24)
        } back: {
            VStack(spacing: 8) {
                Image(systemName: "chart.pie.fill").font(.largeTitle).foregroundColor(.blue)
                Text("Macro Split")
                    .font(.subheadline).foregroundColor(.secondary)
                HStack(spacing: 16) {
                    Text("\(Int(dynamicProteinTarget))g P").foregroundColor(.red).fontWeight(.bold)
                    Text("\(Int(dynamicCarbsTarget))g C").foregroundColor(.blue).fontWeight(.bold)
                    Text("\(Int(dynamicFatTarget))g F").foregroundColor(.orange).fontWeight(.bold)
                }
                .font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 24)
        }
    }
    
    private var micronutrientsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "pills.fill").foregroundColor(.purple)
                Text("Micronutrients")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    MicroCard(title: "Vit A", value: consumedVitaminA, unit: "mcg")
                    MicroCard(title: "Vit C", value: consumedVitaminC, unit: "mg")
                    MicroCard(title: "Vit D", value: consumedVitaminD, unit: "mcg")
                    MicroCard(title: "Calcium", value: consumedCalcium, unit: "mg")
                    MicroCard(title: "Iron", value: consumedIron, unit: "mg")
                    MicroCard(title: "Potassium", value: consumedPotassium, unit: "mg")
                    MicroCard(title: "Magnesium", value: consumedMagnesium, unit: "mg")
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .padding(.horizontal, 24)
    }
    
    private var actionsSection: some View {
        HStack(spacing: 12) {
            Button(action: { playHaptic(); viewModel.showingSmartSuggester = true }) {
                Label("Smart Suggest", systemImage: "wand.and.stars")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(16)
            }
            Button(action: { playHaptic(); viewModel.showingQuickAddSheet = true }) {
                Label("Quick Add", systemImage: "bolt.fill")
                    .font(.subheadline).fontWeight(.bold)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(16)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var waterSection: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Image(systemName: "drop.fill").foregroundColor(.cyan).font(.title3)
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(currentLog.waterML) ml")
                        .font(.subheadline).fontWeight(.bold)
                        .contentTransition(.numericText())
                    Text("/ \(currentLog.waterTargetML)")
                        .font(.caption2).foregroundColor(.secondary)
                        .contentTransition(.numericText())
                }
                Spacer()
                Button(action: { 
                    if currentLog.waterML >= 250 { playHaptic(); withAnimation { currentLog.waterML -= 250 } } 
                    else { withAnimation { currentLog.waterML = 0 } } 
                }) {
                    Image(systemName: "minus.circle.fill").font(.title3).foregroundColor(.secondary.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain)
                
                Menu {
                    Button(action: { addWater(250) }) { Label("Glass (250 ml)", systemImage: "cup.and.saucer") }
                    Button(action: { addWater(500) }) { Label("Flask (500 ml)", systemImage: "waterbottle") }
                    Button(action: { addWater(1000) }) { Label("Large Bottle (1L)", systemImage: "drop.fill") }
                    Button(action: { showingCustomWaterAlert = true }) { Label("Custom Amount...", systemImage: "pencil") }
                } label: { 
                    Image(systemName: "plus.circle.fill").font(.title2).foregroundColor(.blue)
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                } primaryAction: {
                    addWater(250)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
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
        .padding(.horizontal, 24)
    }
    
    // MARK: - Logic
    
    private func recalculateEngines() {
        viewModel.recalculateEngines(allDailyLogs: allDailyLogs, allConsumedMeals: allConsumedMeals, userGoal: userGoal, selectedDate: selectedDate)
        viewModel.updateFrequentMeals(allConsumedMeals: allConsumedMeals)
    }
    
    private func playHaptic() { HapticManager.shared.impact(.light) }
    
    private func addWater(_ amount: Int) { 
        playHaptic()
        withAnimation { currentLog.waterML += amount }
        try? context.save()
        HealthKitManager.shared.saveWater(amountML: Double(amount), date: Date())
        Task { WidgetCenter.shared.reloadAllTimelines() } 
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

struct MicroCard: View {
    let title: String
    let value: Double
    let unit: String
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value > 0 ? "\(value, specifier: "%.1f")" : "—")
                .font(.subheadline)
                .fontWeight(.bold)
            Text(unit)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(width: 70)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
