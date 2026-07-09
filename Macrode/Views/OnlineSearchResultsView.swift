import SwiftUI
import SwiftData
import VisionKit
import WidgetKit


struct OnlineSearchResultsView: View {
    let query: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var isSearching = true
    @State private var results: [OFFProductResult] = []
    
    var body: some View {
        List {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("Community Data. Please verify with the product label if accuracy is critical.").font(.footnote).foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
            if isSearching {
                HStack {
                    Spacer()
                    VStack(spacing: 16) {
                        ProgressView().scaleEffect(1.5)
                        Text("Searching globally...").foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if results.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("Could not find anything for '\(query)'."))
                    .listRowBackground(Color.clear)
            } else {
                ForEach(results, id: \.name) { res in
                    Button(action: {
                        let newFood = FoodItem(name: res.name, calories: res.calories, protein: res.protein, carbs: res.carbs, fat: res.fat, barcode: nil, category: res.category, fiber: res.fiber, sugar: res.sugar, saturatedFat: res.saturatedFat, sodium: res.sodium, imageUrl: res.imageUrl, nutriscore: res.nutriscore, ecoscore: res.ecoscore, novaGroup: res.novaGroup, ingredients: res.ingredients, allergens: res.allergens, brand: res.brand)
                        context.insert(newFood)
                        context.safeSave()
                        HapticManager.shared.impact(.light)
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(res.name).font(.headline).foregroundColor(.primary)
                                Spacer()
                                if let nutriscore = res.nutriscore {
                                    Text("N: \(nutriscore.uppercased())").font(.caption2).fontWeight(.bold).padding(.horizontal, 6).padding(.vertical, 2).background(Color.secondary.opacity(0.2)).cornerRadius(4).foregroundColor(.primary)
                                }
                            }
                            if let brand = res.brand {
                                Text(brand).font(.caption).foregroundColor(.secondary)
                            }
                            HStack(spacing: 8) {
                                Text("\(Int(res.calories)) kcal").foregroundColor(.green)
                                Text("â€¢  \(Int(res.protein))g P | \(Int(res.carbs))g C | \(Int(res.fat))g F").foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Global Results")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let res = try? await OpenFoodFactsAPI.searchProducts(query: query) {
                await MainActor.run {
                    self.results = res
                    self.isSearching = false
                }
            } else {
                await MainActor.run { self.isSearching = false }
            }
        }
    }
}
