import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    private let supplementNagMessages = [
        String.localizing( "💊 Hey! Did you forget your supplements today?"),
        String.localizing( "Time to take your vitamins! ⚡️"),
        String.localizing( "Your supplements are waiting for you. ⏰"),
        String.localizing( "Boost your day! Don't forget your supplements. 💊")
    ]
    
    private let eveningSuccessMessages = [
        String.localizing( "Goal Achieved! 🎉 You hit your calorie target today."),
        String.localizing( "Incredible work today! 🌟 You nailed your macros."),
        String.localizing( "Perfect day! Keep up the great consistency. 🔥"),
        String.localizing( "You crushed it today! Rest up for tomorrow. 🌙")
    ]
    
    private func eveningRemainingMessages(cals: Int) -> [String] {
        return [
            String.localizing( "Dinner time! 🍽️ You have \(cals) kcal left to hit your goal."),
            String.localizing( "Evening check-in 🌙 You can still eat \(cals) kcal today!"),
            String.localizing( "Almost there! You've got \(cals) kcal remaining for a late snack. 🍎"),
            String.localizing( "Don't starve yourself! You still have \(cals) kcal to hit your target. 🎯")
        ]
    }
    
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { success, error in
            DispatchQueue.main.async { completion(success) }
        }
    }
    
    func cancelNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    func scheduleDynamicNotifications(meals: [ConsumedMeal], log: DailyLog?, supplements: [Supplement]) {
        cancelNotifications()
        
        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Water Reminders (Fixed but useful)
        let waterHours = [10, 12, 14, 16, 18]
        let waterMessages = [
            String.localizing( "Hydration Check 💧 Grab a glass of water!"),
            String.localizing( "Stay sharp! 🧠 Time for some water."),
            String.localizing( "Midday thirst? 🚰 Keep that water target in mind."),
            String.localizing( "Almost evening! 💧 Don't forget to hydrate."),
            String.localizing( "Last water check! 🚰 Finish strong.")
        ]
        
        for (index, hour) in waterHours.enumerated() {
            scheduleNotification(id: "water_reminder_\(hour)", title: "Hydration Coach", body: waterMessages[index], hour: hour, minute: 0, repeats: true)
        }
        
        // 2. Dynamic Supplement Nag (10:00 AM)
        let todayString = now.formatted(.iso8601.year().month().day())
        let dayOfWeek = String(calendar.component(.weekday, from: now))
        let supplementsForToday = supplements.filter { $0.scheduledDays.contains(dayOfWeek) }
        let supplementsNotTaken = supplementsForToday.filter { !$0.datesTaken.contains(todayString) }
        
        if !supplementsNotTaken.isEmpty {
            let msg = supplementNagMessages.randomElement() ?? supplementNagMessages[0]
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = 10
            comps.minute = 0
            if let date = calendar.date(from: comps), date > now {
                scheduleSpecificNotification(id: "supplement_nag_today", title: "Supplement Reminder", body: msg, date: date)
            }
        }
        
        // 3. Dynamic Evening Calories (20:00 PM)
        if let currentLog = log {
            let todayMeals = meals.filter { calendar.isDate($0.consumedAt, inSameDayAs: now) }
            let totalCals = todayMeals.reduce(0) { $0 + $1.calories }
            let remaining = Int(currentLog.calorieTarget - totalCals)
            
            let title = remaining <= 0 ? "Goal Met! 🏆" : "Evening Check-in 🌙"
            let bodyMsg = remaining <= 0 ? (eveningSuccessMessages.randomElement() ?? "") : (eveningRemainingMessages(cals: remaining).randomElement() ?? "")
            
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = 20
            comps.minute = 0
            if let date = calendar.date(from: comps), date > now {
                scheduleSpecificNotification(id: "evening_cal_today", title: title, body: bodyMsg, date: date)
            }
        }
        
        // 4. Fallback Evening check-ins for future days (so the app still reminds them tomorrow if they don't open it)
        for dayOffset in 1...3 {
            if let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: now) {
                let title = "Evening Check-in 🌙"
                let body = "Did you hit your goals today? Log your dinner to keep your streak alive!"
                var comps = calendar.dateComponents([.year, .month, .day], from: targetDate)
                comps.hour = 20
                comps.minute = 0
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                let req = UNNotificationRequest(identifier: "evening_future_\(dayOffset)", content: content, trigger: trigger)
                center.add(req)
            }
        }
    }
    
    private func scheduleNotification(id: String, title: String, body: String, hour: Int, minute: Int, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: repeats)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
    
    private func scheduleSpecificNotification(id: String, title: String, body: String, date: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}