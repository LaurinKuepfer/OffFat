import SwiftUI

struct ReviewReportView: View {
    @Environment(\.dismiss) private var dismiss
    let data: ReviewData
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                            .padding(.bottom, 16)
                            .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                        
                        Text(data.days == 7 ? String.localizing( "Your Weekly Review") : String.localizing( "Your Monthly Review"))
                            .font(.largeTitle.weight(.heavy))
                            .multilineTextAlignment(.center)
                        
                        Text(String.localizing( "Here is a look back at your past \(data.days) days."))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // The Big Picture
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String.localizing( "The Big Picture"))
                            .font(.title2.weight(.bold))
                        
                        Text(data.analysisMessage)
                            .font(.headline)
                            .foregroundColor(.purple)
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String.localizing( "Avg. Intake"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(data.averageCalorieIntake))")
                                    .font(.title.weight(.heavy))
                                    .foregroundColor(.primary)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(String.localizing( "Avg. Target"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(data.averageCalorieTarget))")
                                    .font(.title.weight(.heavy))
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Progress bar representation
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(UIColor.tertiarySystemFill))
                                    .frame(height: 16)
                                
                                let ratio = data.averageCalorieTarget > 0 ? CGFloat(data.averageCalorieIntake / data.averageCalorieTarget) : 0
                                let clampedRatio = min(1.0, max(0.0, ratio))
                                let color: Color = ratio > 1.05 ? .red : .green
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(color)
                                    .frame(width: proxy.size.width * clampedRatio, height: 16)
                            }
                        }
                        .frame(height: 16)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    
                    // Consistency Score
                    VStack(spacing: 16) {
                        Text(String.localizing( "Consistency"))
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            ZStack {
                                Circle()
                                    .stroke(Color.green.opacity(0.2), lineWidth: 10)
                                    .frame(width: 80, height: 80)
                                
                                let progress = Double(data.daysGoalMet) / Double(max(1, data.days))
                                Circle()
                                    .trim(from: 0, to: CGFloat(progress))
                                    .stroke(Color.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                    .rotationEffect(.degrees(-90))
                                    .frame(width: 80, height: 80)
                                    .animation(.easeOut(duration: 1.0), value: progress)
                                
                                Text("\(data.daysGoalMet)")
                                    .font(.title.weight(.bold))
                                    .foregroundColor(.green)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String.localizing( "Goals Met"))
                                    .font(.headline)
                                Text(String.localizing( "You stayed within your calorie target on \(data.daysGoalMet) out of \(data.days) days."))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 16)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    
                    // Macro Champion
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String.localizing( "Macro Champion"))
                            .font(.title2.weight(.bold))
                        
                        HStack(spacing: 16) {
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(data.bestMacroName)")
                                    .font(.title3.weight(.bold))
                                Text(String.localizing( "You hit \(Int(data.bestMacroPercentage))% of your target on average."))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(20)
                    
                    // Weight Change
                    if let weightChange = data.weightChange {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(String.localizing( "Weight Trend"))
                                .font(.title2.weight(.bold))
                            
                            HStack(spacing: 16) {
                                Image(systemName: weightChange > 0 ? "arrow.up.right.circle.fill" : (weightChange < 0 ? "arrow.down.right.circle.fill" : "minus.circle.fill"))
                                    .font(.system(size: 40))
                                    .foregroundColor(weightChange > 0 ? .red : (weightChange < 0 ? .green : .blue))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    let absChange = abs(weightChange)
                                    if weightChange > 0 {
                                        Text(String.localizing( "Gained \(String(format: "%.1f", absChange)) kg"))
                                            .font(.title3.weight(.bold))
                                    } else if weightChange < 0 {
                                        Text(String.localizing( "Lost \(String(format: "%.1f", absChange)) kg"))
                                            .font(.title3.weight(.bold))
                                    } else {
                                        Text(String.localizing( "Maintained Weight"))
                                            .font(.title3.weight(.bold))
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(20)
                    }
                    
                    // Motivational Message
                    VStack(alignment: .center, spacing: 16) {
                        Image(systemName: "quote.opening")
                            .font(.largeTitle)
                            .foregroundColor(.blue.opacity(0.5))
                        
                        Text(data.motivationalMessage)
                            .font(.headline)
                            .italic()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.1), .blue.opacity(0.3)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .cornerRadius(20)
                    
                }
                .padding()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
