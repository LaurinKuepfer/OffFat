import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @Query private var allMeals: [ConsumedMeal]
    
    @State private var viewModel = SettingsViewModel()
    
    @AppStorage("isProactiveCoachEnabled") private var isProactiveCoachEnabled = false
    @AppStorage("isAdaptiveCoachingEnabled") private var isAdaptiveCoachingEnabled = false
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial: Bool = true
    @AppStorage("appLanguage", store: UserDefaults(suiteName: "group.com.kuepferlaurin.macrode")) private var appLanguage: String = "system"
    @AppStorage("userGoal") private var userGoal: GoalType = .maintain
    @AppStorage("hasDismissedWidgetPromo") private var hasDismissedWidgetPromo = false
    @AppStorage("enableFasting") private var enableFasting = false
    @AppStorage("enableMicronutrients") private var enableMicronutrients = false

    @State private var showingWeeklyReport = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(uiColor: .systemGroupedBackground),
                        Color.orange.opacity(0.04),
                        Color.mint.opacity(0.04),
                        Color(uiColor: .systemGroupedBackground)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .adaptiveBackgroundTexture()

                List {
                preferencesSection
                integrationsSection
                dataSection
                aboutSection
                dangerZoneSection
            }
            .scrollContentBackground(.hidden)
            .listStyle(.insetGrouped)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingWeeklyReport) {
                WeeklyReportView()
            }
            .fileExporter(
                isPresented: $viewModel.showingExporter,
                document: viewModel.csvDocument,
                contentType: .commaSeparatedText,
                defaultFilename: "Macrode_Backup_\(Date().formatted(date: .numeric, time: .omitted))"
            ) { result in
                switch result {
                case .success(_): viewModel.showAlert(title: String.localizing( "Export Successful!"), message: String.localizing( "Your data has been saved."))
                case .failure(let error): viewModel.showAlert(title: String.localizing( "Export Failed"), message: error.localizedDescription)
                }
            }
            .fileImporter(
                isPresented: $viewModel.showingImporter,
                allowedContentTypes: [.commaSeparatedText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    viewModel.importCSV(from: url, context: context)
                case .failure(let error): viewModel.showAlert(title: String.localizing( "Import Failed"), message: error.localizedDescription)
                }
            }
            .alert(viewModel.alertTitle, isPresented: $viewModel.showingAlert) { 
                Button("OK", role: .cancel) { } 
            } message: {
                if !viewModel.alertMessage.isEmpty {
                    Text(viewModel.alertMessage)
                }
            }
            .confirmationDialog("Are you sure?", isPresented: $viewModel.showingResetConfirm, titleVisibility: .visible) {
                Button("Delete Everything", role: .destructive) { viewModel.resetAllData(context: context) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all your logged meals, daily logs, food library, recipes, and supplements. Export a backup first!")
            }
        }
    }
    
    // MARK: - Sections
    
    private var preferencesSection: some View {
        Section {
            Picker(selection: $appLanguage) {
                Text("System").tag("system")
                Text("English").tag("en")
                Text("Deutsch").tag("de")
                Text("Español").tag("es")
                Text("Français").tag("fr")
            } label: {
                Label("Language", systemImage: "globe")
            }
            
            Toggle(isOn: $isProactiveCoachEnabled) {
                Label("Daily Coach", systemImage: "bell.badge.fill")
            }
            .onChange(of: isProactiveCoachEnabled) { _, newValue in
                HapticManager.shared.impact(.light)
                if newValue {
                    NotificationManager.shared.requestPermission { success in
                        if success {
                            let today = Calendar.current.startOfDay(for: Date())
                            let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
                            let supplements = (try? context.fetch(FetchDescriptor<Supplement>())) ?? []
                            let todayLog = logs.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) })
                            NotificationManager.shared.scheduleDynamicNotifications(meals: allMeals, log: todayLog, supplements: supplements)
                        } else {
                            isProactiveCoachEnabled = false
                            viewModel.showAlert(title: String.localizing( "Permission Denied"), message: String.localizing( "Please enable notifications for Macrode in your iPhone Settings."))
                        }
                    }
                } else {
                    NotificationManager.shared.cancelNotifications()
                }
            }
            
            Toggle(isOn: $isAdaptiveCoachingEnabled) {
                Label("Adaptive TDEE Coaching", systemImage: "brain.head.profile")
            }
            .onChange(of: isAdaptiveCoachingEnabled) { _, _ in
                HapticManager.shared.impact(.light)
            }
            
            NavigationLink(destination: MacroCyclingSettingsView()) {
                Label("Macro Cycling", systemImage: "arrow.triangle.2.circlepath")
            }
            
            NavigationLink(destination: FastingScheduleSettingsView()) {
                Label("Intermittent Fasting", systemImage: "timer")
            }
            
            Toggle(isOn: $enableMicronutrients) {
                Label("Advanced Micronutrients", systemImage: "pills.fill")
            }
            .onChange(of: enableMicronutrients) { _, _ in
                HapticManager.shared.impact(.light)
            }
        } header: {
            Label("Preferences", systemImage: "gearshape.fill")
        } footer: {
            Text("Receive offline daily reminders to take your supplements and hit your protein goals.")
        }
    }
    
    private var integrationsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Available Widgets").font(.caption).foregroundColor(.secondary)
                HStack(spacing: 16) {
                    widgetPreviewCard(icon: "flame.fill", title: "Calories", subtitle: "Remaining kcal", color: .green)
                    widgetPreviewCard(icon: "chart.bar.fill", title: "Macros", subtitle: "P / C / F split", color: .blue)
                    widgetPreviewCard(icon: "drop.fill", title: "Water", subtitle: "Daily intake", color: .cyan)
                }
            }
            .padding(.vertical, 4)
            Text("Long-press your Home Screen → tap **+** in the top-left → search **Macrode** to add widgets.")
                .font(.caption)
                .foregroundColor(.secondary)
                
            Button(action: {
                HapticManager.shared.impact(.light)
                HealthKitManager.shared.requestAuthorization { success, error in
                    if success { 
                        viewModel.showAlert(title: String.localizing( "Connected!"), message: String.localizing( "Macrode will now sync your meals directly to Apple Health.")) 
                    } else { 
                        viewModel.showAlert(title: String.localizing( "Error"), message: error?.localizedDescription ?? String.localizing( "Could not connect to Apple Health.")) 
                    }
                }
            }) {
                Label("Connect Apple Health", systemImage: "heart.text.square.fill")
                    .foregroundColor(.primary)
            }
        } header: {
            Label("Integrations", systemImage: "rectangle.on.rectangle")
        } footer: {
            Text("Sync meals, water, and weight to Apple Health automatically.")
        }
    }
    
    private var dataSection: some View {
        Section {
            Button(action: { showingWeeklyReport = true }) {
                Label("Weekly Progress Report", systemImage: "chart.bar.doc.horizontal")
            }
            
            Button(action: { viewModel.prepareExport(allMeals: allMeals) }) {
                Label("Export Backup (.csv)", systemImage: "square.and.arrow.up")
                    .foregroundColor(.primary)
            }
            
            Button(action: { viewModel.showingImporter = true }) {
                Label("Restore from Backup", systemImage: "square.and.arrow.down")
            }
            .foregroundColor(.orange)
        } header: {
            Label("Data & Backup", systemImage: "externaldrive.fill")
        } footer: {
            Text("Macrode is 100% offline. Use backups to transfer your data to a new device.")
        }
    }
    
    private var aboutSection: some View {
        Section {
            Button(action: {
                HapticManager.shared.impact(.light)
                hasCompletedTutorial = false
                dismiss()
            }) {
                Label("Show Quick Guide", systemImage: "questionmark.circle.fill")
                    .foregroundColor(.primary)
            }
            
            Link(destination: URL(string: "https://github.com/LaurinKuepfer/Macrode")!) {
                HStack {
                    Label("Source Code (GitHub)", systemImage: "curlybraces.square.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right").font(.caption).foregroundColor(.secondary)
                }
            }
        } header: {
            Label("About & Help", systemImage: "info.circle.fill")
        }
    }
    
    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive, action: {
                HapticManager.shared.impact(.light)
                viewModel.showingResetConfirm = true
            }) {
                Label("Reset All Data", systemImage: "trash.fill")
            }
        } header: {
            Label("Danger Zone", systemImage: "exclamationmark.triangle.fill")
        } footer: {
            Text("This will permanently delete all your meals, logs, and settings. This cannot be undone.")
        }
    }
    
    // MARK: - Components
    
    private func widgetPreviewCard(icon: String, title: LocalizedStringKey, subtitle: LocalizedStringKey, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(title)
                .font(.caption2).fontWeight(.bold)
            Text(subtitle)
                .font(.system(size: 9)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(12)
    }
}
