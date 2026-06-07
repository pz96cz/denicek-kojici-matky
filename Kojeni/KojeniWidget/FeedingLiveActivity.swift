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
                    VStack(spacing: 4) {
                        breastBadge(for: context.state.currentBreast)
                        Text(timerInterval: context.attributes.sessionStartedAt...context.attributes.sessionStartedAt.addingTimeInterval(8 * 3600),
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
                Text(timerInterval: context.attributes.sessionStartedAt...context.attributes.sessionStartedAt.addingTimeInterval(8 * 3600),
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
                breastBadge(for: context.state.currentBreast)
            }

            // 8h horní hranice — odpovídá iOS Live Activity max lifetime.
            // Bez ní `Text(timerInterval:)` formátuje divně jelikož distantFuture
            // je miliardy let.
            Text(timerInterval: context.attributes.sessionStartedAt...context.attributes.sessionStartedAt.addingTimeInterval(8 * 3600),
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

    /// Plný název prsa pro Lock Screen + center expanded Dynamic Island.
    private func fullName(for breast: Breast) -> String {
        switch breast {
        case .left:  return "Levé prso"
        case .right: return "Pravé prso"
        }
    }

    /// Colored badge — modré pro levé, fialové pro pravé.
    @ViewBuilder
    private func breastBadge(for breast: Breast) -> some View {
        let tint: Color = breast == .left ? .blue : .purple
        HStack(spacing: 4) {
            Image(systemName: "drop.fill")
                .font(.caption2)
            Text(fullName(for: breast))
                .font(.subheadline.bold())
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(tint.gradient))
    }
}
