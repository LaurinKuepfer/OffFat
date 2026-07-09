import SwiftUI
import SwiftData
import VisionKit

// MARK: - THE INGREDIENT PICKER SHEET
struct IngredientPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var foodLibrary: [FoodItem]
    var onFoodSelected: (FoodItem) -> Void
    
    @State private var searchText = ""
    @State private var isShowingScanner = false
    @State private var scannedBarcode: String? = nil
    
    @State private var isFetchingAPI = false
    @State private var navigateToCreateFood = false
    @State private var prefilledAPIResult: (name: String, calories: Double, protein: Double, carbs: Double, fat: Double, barcode: String, category: String, fiber: Double?, sugar: Double?, saturatedFat: Double?, sodium: Double?, imageUrl: String?, nutriscore: String?, ecoscore: String?, novaGroup: Int?, ingredients: String?, allergens: String?, brand: String?)? = nil
    @State private var onlineSearchQuery: String? = nil
    
    var filteredFoods: [FoodItem] {
        if searchText.isEmpty { return foodLibrary }
        return foodLibrary.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    if !searchText.isEmpty {
                        Section {
                            Button(action: {
                                onlineSearchQuery = searchText
                            }) {
                                HStack {
                                    Image(systemName: "globe")
                                    Text("Search '\(searchText)' Globally")
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                                }
                                .foregroundColor(.blue)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    if filteredFoods.isEmpty {
                        ContentUnavailableView("No Foods Locally", systemImage: "carrot", description: Text("Search globally above, or scan a barcode."))
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredFoods) { food in
                            Button(action: {
                                onFoodSelected(food)
                                dismiss()
                            }) {
                                HStack {
                                    Text(food.name).foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                        .foregroundColor(.green)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .searchable(text: $searchText, prompt: "Search ingredients...")
                
                if isFetchingAPI {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack {
                        ProgressView().scaleEffect(1.5).padding()
                        Text("Looking up product...").font(.headline).foregroundColor(.white)
                    }
                }
            }
            .navigationTitle("Pick Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                        Button(action: { isShowingScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }
            }
            .sheet(isPresented: $isShowingScanner) {
                ScannerView(scannedBarcode: $scannedBarcode).ignoresSafeArea()
            }
            .onChange(of: scannedBarcode) { _, newValue in
                if let barcode = newValue {
                    isShowingScanner = false
                    fetchFromOpenFoodFacts(barcode: barcode)
                }
            }
            .navigationDestination(isPresented: $navigateToCreateFood) { 
                CreateFoodView(prefilledData: prefilledAPIResult, mainTabSelection: .constant(0)) 
            }
            .navigationDestination(item: Binding<String?>(
                get: { onlineSearchQuery },
                set: { onlineSearchQuery = $0 }
            )) { query in
                OnlineSearchResultsView(query: query)
            }
        }
    }
    
    private func fetchFromOpenFoodFacts(barcode: String) {
        if let existingFood = foodLibrary.first(where: { $0.barcode == barcode }) {
            onFoodSelected(existingFood)
            dismiss()
            return
        }
        
        isFetchingAPI = true
        Task {
            if let result = try? await OpenFoodFactsAPI.fetchProduct(barcode: barcode) {
                await MainActor.run { 
                    prefilledAPIResult = (name: result.name, calories: result.calories, protein: result.protein, carbs: result.carbs, fat: result.fat, barcode: barcode, category: result.category, fiber: result.fiber, sugar: result.sugar, saturatedFat: result.saturatedFat, sodium: result.sodium, imageUrl: result.imageUrl, nutriscore: result.nutriscore, ecoscore: result.ecoscore, novaGroup: result.novaGroup, ingredients: result.ingredients, allergens: result.allergens, brand: result.brand)
                    isFetchingAPI = false
                    navigateToCreateFood = true 
                }
            } else {
                await MainActor.run { 
                    isFetchingAPI = false
                    prefilledAPIResult = nil
                    navigateToCreateFood = true 
                }
            }
        }
    }
}

// MARK: - Edit Recipe