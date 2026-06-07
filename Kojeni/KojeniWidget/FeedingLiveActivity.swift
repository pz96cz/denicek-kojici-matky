import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

struct FeedingLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FeedingAttributes.self) { context in
            // Lock Screen / Notification Center
            lockScreenView(context: context)
                .padding()
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(.primary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("🤱")
                        .font(.title2)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text("Prso \(label(for: context.state.currentBreast))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                             countsDown: false)
                            .font(.title3.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 8) {
                        Button(intent: SwitchBreastIntent()) {
                            Text("Přehodit")
                        }
                        .buttonStyle(.bordered)
                        .tint(.blue)

                        Button(intent: StopFeedingIntent()) {
                            Text("Stop")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                    }
                }
            } compactLeading: {
                Text(label(for: context.state.currentBreast))
                    .font(.caption.bold())
            } compactTrailing: {
                Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                     countsDown: false)
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: 44)
            } minimal: {
                Text("🤱")
            }
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<FeedingAttributes>) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("🤱 Kojení")
                    .font(.headline)
                Spacer()
                Text("Prso \(label(for: context.state.currentBreast))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(timerInterval: context.attributes.sessionStartedAt...Date.distantFuture,
                 countsDown: false)
                .font(.system(size: 44, weight: .bold, design: .monospaced))
                .monospacedDigit()

            HStack(spacing: 12) {
                Button(intent: SwitchBreastIntent()) {
                    Text("Přehodit prso")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button(intent: StopFeedingIntent()) {
                    Text("Stop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
            }
        }
    }

    private func label(for breast: Breast) -> String {
        switch breast {
        case .left:  return "L"
        case .right: return "P"
        }
    }
}
