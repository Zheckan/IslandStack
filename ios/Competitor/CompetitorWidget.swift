import ActivityKit
import SwiftUI
import WidgetKit

private struct CompetitorLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: CompetitorAttributes.self) { context in
      HStack(spacing: 12) {
        Image(systemName: CompetitorStyle.symbol)
          .foregroundStyle(CompetitorStyle.color)
        Text(context.attributes.title)
        Spacer()
        CompetitorCountdown(endsAt: context.state.endsAt)
          .frame(width: 56)
      }
      .padding()
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: CompetitorStyle.symbol)
            .foregroundStyle(CompetitorStyle.color)
        }
        DynamicIslandExpandedRegion(.center) {
          Text(context.attributes.title)
        }
        DynamicIslandExpandedRegion(.trailing) {
          CompetitorCountdown(endsAt: context.state.endsAt)
            .frame(width: 56)
            .foregroundStyle(CompetitorStyle.color)
        }
      } compactLeading: {
        Image(systemName: CompetitorStyle.symbol)
          .foregroundStyle(CompetitorStyle.color)
      } compactTrailing: {
        CompetitorCountdown(endsAt: context.state.endsAt)
          .font(.caption)
          .frame(width: 44)
          .foregroundStyle(CompetitorStyle.color)
      } minimal: {
        Image(systemName: CompetitorStyle.symbol)
          .foregroundStyle(CompetitorStyle.color)
      }
      .keylineTint(CompetitorStyle.color)
    }
  }
}

private struct CompetitorCountdown: View {
  let endsAt: Date

  var body: some View {
    Text(
      timerInterval: endsAt.addingTimeInterval(-20 * 60)...endsAt,
      countsDown: true,
      showsHours: false
    )
    .monospacedDigit()
    .multilineTextAlignment(.trailing)
  }
}

@main
struct CompetitorWidgets: WidgetBundle {
  var body: some Widget {
    CompetitorLiveActivity()
  }
}
