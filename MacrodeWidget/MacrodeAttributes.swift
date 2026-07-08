import Foundation
import ActivityKit

public struct MacrodeAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var caloriesLeft: Int
        public var fastingHours: Double
        public var fastingTargetHours: Double
        
        public init(caloriesLeft: Int, fastingHours: Double, fastingTargetHours: Double = 0) {
            self.caloriesLeft = caloriesLeft
            self.fastingHours = fastingHours
            self.fastingTargetHours = fastingTargetHours
        }
    }
    
    public var name: String
    
    public init(name: String) {
        self.name = name
    }
}
