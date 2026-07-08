import Foundation

@Observable
public class RecipeScraperManager {
    public static let shared = RecipeScraperManager()
    
    public var isScraping = false
    public var errorMessage: String? = nil
    
    public struct ScrapedRecipe {
        public let name: String
        public let ingredients: [String]
        public let instructions: [String]
        public let calories: Double
        public let protein: Double
        public let carbs: Double
        public let fat: Double
        public let prepTimeMinutes: Int
    }
    
    public func scrapeRecipe(from urlString: String) async throws -> ScrapedRecipe {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10
        
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeRawData)
        }
        
        return try parseJSONLD(from: html)
    }
    
    private func parseJSONLD(from html: String) throws -> ScrapedRecipe {
        let pattern = "(?s)<script type=\"application/ld\\+json\">(.*?)</script>"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
        
        for match in matches {
            guard let range = Range(match.range(at: 1), in: html) else { continue }
            let jsonString = String(html[range])
            
            guard let jsonData = jsonString.data(using: .utf8) else { continue }
            
            if let parsed = try? JSONSerialization.jsonObject(with: jsonData, options: []) {
                if let recipe = findRecipeObject(in: parsed) {
                    return extractRecipeData(from: recipe)
                }
            }
        }
        
        throw NSError(domain: "RecipeScraper", code: 404, userInfo: [NSLocalizedDescriptionKey: String.localizing("Could not find a valid Recipe schema on this page.")])
    }
    
    private func findRecipeObject(in json: Any) -> [String: Any]? {
        if let dict = json as? [String: Any] {
            if let type = dict["@type"] as? String, type == "Recipe" {
                return dict
            } else if let typeArray = dict["@type"] as? [String], typeArray.contains("Recipe") {
                return dict
            } else if let graph = dict["@graph"] as? [[String: Any]] {
                for item in graph {
                    if let type = item["@type"] as? String, type == "Recipe" {
                        return item
                    }
                }
            } else {
                for (_, value) in dict {
                    if let found = findRecipeObject(in: value) {
                        return found
                    }
                }
            }
        } else if let array = json as? [[String: Any]] {
            for item in array {
                if let found = findRecipeObject(in: item) {
                    return found
                }
            }
        }
        return nil
    }
    
    private func extractRecipeData(from dict: [String: Any]) -> ScrapedRecipe {
        let name = (dict["name"] as? String) ?? "Imported Recipe"
        
        var ingredients: [String] = []
        if let ingArray = dict["recipeIngredient"] as? [String] {
            ingredients = ingArray
        }
        
        var instructions: [String] = []
        if let instArray = dict["recipeInstructions"] as? [[String: Any]] {
            for inst in instArray {
                if let text = inst["text"] as? String {
                    instructions.append(text)
                }
            }
        } else if let instArray = dict["recipeInstructions"] as? [String] {
            instructions = instArray
        }
        
        var calories = 0.0
        var protein = 0.0
        var carbs = 0.0
        var fat = 0.0
        
        if let nutrition = dict["nutrition"] as? [String: Any] {
            calories = parseNutritionValue(nutrition["calories"])
            protein = parseNutritionValue(nutrition["proteinContent"])
            carbs = parseNutritionValue(nutrition["carbohydrateContent"])
            fat = parseNutritionValue(nutrition["fatContent"])
        }
        
        var prepTimeMinutes = 10
        if let pt = dict["prepTime"] as? String {
            prepTimeMinutes = parseISO8601Duration(pt)
        }
        
        return ScrapedRecipe(
            name: name,
            ingredients: ingredients,
            instructions: instructions,
            calories: calories > 0 ? calories : 100, // Fallback if missing
            protein: protein,
            carbs: carbs,
            fat: fat,
            prepTimeMinutes: prepTimeMinutes > 0 ? prepTimeMinutes : 10
        )
    }
    
    private func parseNutritionValue(_ value: Any?) -> Double {
        if let str = value as? String {
            let numberString = str.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted).joined()
            return Double(numberString) ?? 0.0
        } else if let num = value as? Double {
            return num
        } else if let num = value as? Int {
            return Double(num)
        }
        return 0.0
    }
    
    private func parseISO8601Duration(_ duration: String) -> Int {
        var totalMinutes = 0
        let regex = try? NSRegularExpression(pattern: "PT(?:(\\d+)H)?(?:(\\d+)M)?")
        if let match = regex?.firstMatch(in: duration, range: NSRange(duration.startIndex..., in: duration)) {
            if let hRange = Range(match.range(at: 1), in: duration), let h = Int(duration[hRange]) {
                totalMinutes += h * 60
            }
            if let mRange = Range(match.range(at: 2), in: duration), let m = Int(duration[mRange]) {
                totalMinutes += m
            }
        }
        return totalMinutes
    }
}
