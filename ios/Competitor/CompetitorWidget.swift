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
        Text(context.state.endsAt, style: .timer)
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
          Text(context.state.endsAt, style: .timer)
            .foregroundStyle(CompetitorStyle.color)
        }
      } compactLeading: {
        Image(systemName: CompetitorStyle.symbol)
          .foregroundStyle(CompetitorStyle.color)
      } compactTrailing: {
        Text(context.state.endsAt, style: .timer)
          .foregroundStyle(CompetitorStyle.color)
      } minimal: {
        Image(systemName: CompetitorStyle.symbol)
          .foregroundStyle(CompetitorStyle.color)
      }
      .keylineTint(CompetitorStyle.color)
    }
  }
}

@main
struct CompetitorWidgets: WidgetBundle {
  var body: some Widget {
    CompetitorLiveActivity()
  }
}
