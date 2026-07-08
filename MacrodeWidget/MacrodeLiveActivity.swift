import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.1, *)
struct MacrodeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MacrodeAttributes.self) { context in
            HStack {
                VStack(alignment: .leading) {
                    Text("Macrode").font(.headline)
                    Text("\(context.state.caloriesLeft) kcal left").font(.title).fontWeight(.bold).foregroundColor(.green)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Image(systemName: "timer").foregroundColor(.purple)
                    if context.state.fastingTargetHours > 0 {
                        Text(String(format: "%.1fh / %.0fh", context.state.fastingHours, context.state.fastingTargetHours)).font(.subheadline)
                    } else {
                        Text(String(format: "%.1fh fasting", context.state.fastingHours)).font(.subheadline)
                    }
                }
            }
            .padding()
            .activitySystemActionForegroundColor(Color.black)
            .activityBackgroundTint(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Left").font(.caption).foregroundColor(.secondary)
                        Text("\(context.state.caloriesLeft)").font(.title2).fontWeight(.bold).foregroundColor(.green)
                    }
                    .padding(.leading, 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Fasting").font(.caption).foregroundColor(.secondary)
                        Text(String(format: "%.1fh", context.state.fastingHours)).font(.title2).fontWeight(.bold).foregroundColor(.purple)
                    }
                    .padding(.trailing, 8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.fastingTargetHours > 0 {
                        ProgressView(value: min(1.0, context.state.fastingHours / context.state.fastingTargetHours))
                            .progressViewStyle(.linear)
                            .tint(.purple)
                            .padding(.horizontal)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 8, height: 8)
                    Text("\(context.state.caloriesLeft)").font(.caption2).fontWeight(.bold)
                }
            } compactTrailing: {
                HStack(spacing: 4) {
                    Image(systemName: "timer").font(.caption2).foregroundColor(.purple)
                    Text(String(format: "%.1f", context.state.fastingHours)).font(.caption2).fontWeight(.bold)
                }
            } minimal: {
                Text("\(context.state.caloriesLeft)").font(.caption2).fontWeight(.bold).foregroundColor(.green)
            }
        }
    }
}
