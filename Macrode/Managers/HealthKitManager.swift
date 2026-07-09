import Foundation
import HealthKit

@MainActor
class HealthKitManager {
    static let shared = HealthKitManager()
    let healthStore = HKHealthStore()
    
    private var typesToWrite: Set<HKSampleType> {
        guard let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let energyType = HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed),
              let proteinType = HKObjectType.quantityType(forIdentifier: .dietaryProtein),
              let carbsType = HKObjectType.quantityType(forIdentifier: .dietaryCarbohydrates),
              let fatType = HKObjectType.quantityType(forIdentifier: .dietaryFatTotal),
              let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return [] }
        return [weightType, energyType, proteinType, carbsType, fatType, waterType]
    }
    
    private var typesToRead: Set<HKObjectType> {
        guard let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else { return [] }
        return [stepsType, weightType, energyType]
    }
    
    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(domain: "Macrode", code: 1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device."])
        }
        try await healthStore.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }
    
    func fetchTodaySteps() async throws -> Double {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            throw NSError(domain: "HealthKitManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Step Count type is unavailable."])
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: HKUnit.count()))
            }
            healthStore.execute(query)
        }
    }
    
    func fetchActiveEnergy() async throws -> Double {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            throw NSError(domain: "HealthKitManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Active Energy type is unavailable."])
        }
        
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: HKUnit.kilocalorie()))
            }
            healthStore.execute(query)
        }
    }
    
    func saveWeight(weightInKg: Double, date: Date) async throws {
        guard HKHealthStore.isHealthDataAvailable(),
              let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw NSError(domain: "HealthKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Body mass type is unavailable."])
        }
        
        let weightQty = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weightInKg)
        let weightSample = HKQuantitySample(type: weightType, quantity: weightQty, start: date, end: date)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(weightSample) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(domain: "HealthKitManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown error saving weight."]))
                }
            }
        }
    }
    
    func fetchLatestWeight() async throws -> (Double, Date)? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            throw NSError(domain: "HealthKitManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Body mass type is unavailable."])
        }
        
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let weightInKg = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: (weightInKg, sample.startDate))
            }
            healthStore.execute(query)
        }
    }
    
    func saveMeal(name: String, calories: Double, protein: Double, carbs: Double, fat: Double, date: Date) {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        var samples: [HKQuantitySample] = []
        
        if calories > 0, let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) {
            let energyQty = HKQuantity(unit: HKUnit.kilocalorie(), doubleValue: calories)
            samples.append(HKQuantitySample(type: energyType, quantity: energyQty, start: date, end: date))
        }
        if protein > 0, let proteinType = HKQuantityType.quantityType(forIdentifier: .dietaryProtein) {
            let proteinQty = HKQuantity(unit: HKUnit.gram(), doubleValue: protein)
            samples.append(HKQuantitySample(type: proteinType, quantity: proteinQty, start: date, end: date))
        }
        if carbs > 0, let carbsType = HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates) {
            let carbsQty = HKQuantity(unit: HKUnit.gram(), doubleValue: carbs)
            samples.append(HKQuantitySample(type: carbsType, quantity: carbsQty, start: date, end: date))
        }
        if fat > 0, let fatType = HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal) {
            let fatQty = HKQuantity(unit: HKUnit.gram(), doubleValue: fat)
            samples.append(HKQuantitySample(type: fatType, quantity: fatQty, start: date, end: date))
        }
        
        guard !samples.isEmpty else { return }
        healthStore.save(samples) { success, error in
            if let error = error {
                print("Error saving nutrition to HealthKit: \(error.localizedDescription)")
            }
        }
    }
    
    func saveWater(amountML: Double, date: Date) {
        guard HKHealthStore.isHealthDataAvailable(), amountML > 0 else { return }
        
        guard let waterType = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else { return }
        let waterQty = HKQuantity(unit: HKUnit.literUnit(with: .milli), doubleValue: amountML)
        let sample = HKQuantitySample(type: waterType, quantity: waterQty, start: date, end: date)
        
        healthStore.save(sample) { success, error in
            if let error = error {
                print("Error saving water to HealthKit: \(error.localizedDescription)")
            }
        }
    }
}