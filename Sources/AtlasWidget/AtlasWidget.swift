import WidgetKit
import SwiftUI

/// The Notification Centre widget.
///
/// Runs in its own process and shares nothing with the app but a JSON file.
/// That is deliberate: an App Group would need a paid team identifier, which an
/// ad-hoc signed build cannot have, so the two processes meet at a path both can
/// resolve — see `SharedPaths`, which reads the real home directory rather than
/// trusting `NSHomeDirectory()`.
struct Provider: TimelineProvider {

    func placeholder(in context: Context) -> WidgetSnapshotEntry {
        WidgetSnapshotEntry(date: Date(), snapshot: Snapshot.placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetSnapshotEntry) -> Void) {
        completion(WidgetSnapshotEntry(date: Date(), snapshot: WidgetBridge.read() ?? .placeholder))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetSnapshotEntry>) -> Void) {
        let entry = WidgetSnapshotEntry(date: Date(), snapshot: WidgetBridge.read())
        // The app reloads timelines itself whenever it writes a new snapshot,
        // so this refresh only exists to keep the relative date honest.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - Widget

struct AtlasWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "uz.overview.CodeMap", provider: Provider()) { entry in
            AtlasWidgetView(entry: entry)
        }
        .configurationDisplayName("Atlas")
        .description("Oxirgi tahlil qilingan loyiha holati.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct AtlasWidgetBundle: WidgetBundle {
    var body: some Widget { AtlasWidget() }
}
