import SwiftUI

/// The sections of the app, shown in the unified window's sidebar.
public enum AppSection: String, CaseIterable, Identifiable, Sendable {
    case overview
    case insights
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: return "Overview"
        case .insights: return "Insights"
        case .settings: return "Settings"
        }
    }

    public var symbol: String {
        switch self {
        case .overview: return "flame"
        case .insights: return "chart.line.uptrend.xyaxis"
        case .settings: return "gearshape"
        }
    }
}

/// Which section the unified window is showing. Owned outside the view so the
/// menu bar can open the window straight onto a section.
public final class AppNavigation: ObservableObject {
    @Published public var section: AppSection

    public init(section: AppSection = .overview) {
        self.section = section
    }
}

/// The whole app in one window: Overview, Insights and Settings behind a
/// sidebar. No scattered windows, no submenus — open BurnFuse and everything
/// is here.
///
/// The sidebar is drawn directly rather than with `NavigationSplitView` so the
/// window renders identically in the app and in the offscreen screenshot pass.
public struct RootView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var nav: AppNavigation
    /// Renderer-only, like the same parameters on `SettingsView`: seeds the
    /// add-a-key field so a screenshot can show a pasted key being recognised,
    /// and shows the real state path instead of the renderer's temp file. Never
    /// set in the running app.
    var previewAddKey: String = ""
    var displayStatePath: String? = nil

    public init(
        model: AppModel,
        nav: AppNavigation = AppNavigation(),
        previewAddKey: String = "",
        displayStatePath: String? = nil
    ) {
        self.model = model
        self.nav = nav
        self.previewAddKey = previewAddKey
        self.displayStatePath = displayStatePath
    }

    public var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 760, minHeight: 540)
        .background(.background)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: DS.Space.sm) {
                BrandMark(size: 18)
                Text("burnfuse").font(.headline)
                Spacer()
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.top, DS.Space.md)
            .padding(.bottom, DS.Space.sm)

            VStack(spacing: 2) {
                ForEach(AppSection.allCases) { item in
                    SidebarRow(
                        title: item.title,
                        symbol: item.symbol,
                        selected: nav.section == item
                    ) {
                        nav.section = item
                    }
                }
            }
            .padding(.horizontal, DS.Space.sm)

            Spacer(minLength: DS.Space.md)

            HStack(spacing: DS.Space.sm) {
                Circle()
                    .fill(model.state.hasBreach ? DS.Tone.breach : DS.Tone.calm)
                    .frame(width: 6, height: 6)
                Text(model.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, DS.Space.md)
            .padding(.bottom, DS.Space.md)
        }
        .frame(width: 200)
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        switch nav.section {
        case .overview:
            scrollable {
                OverviewView(
                    model: model,
                    onAddKey: { nav.section = .settings },
                    onSeeTrips: { nav.section = .insights }
                )
            }
        case .insights:
            scrollable { InsightsView(model: model, width: nil) }
        case .settings:
            scrollable {
                SettingsView(
                    model: model,
                    width: nil,
                    displayStatePath: displayStatePath,
                    previewAddKey: previewAddKey
                )
            }
        }
    }

    private func scrollable<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        ScrollView(.vertical, showsIndicators: false) { content() }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background)
    }
}

/// One row in the sidebar: an icon, a label, and a selected state that reads on
/// both appearances without relying on colour alone.
struct SidebarRow: View {
    let title: String
    let symbol: String
    let selected: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 18)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
            .padding(.horizontal, DS.Space.sm + 2)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selected
                          ? DS.accent
                          : Color.primary.opacity(hovering ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}