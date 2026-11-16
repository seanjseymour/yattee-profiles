//
//  ViewerFocusUITestFixture.swift
//  Yattee
//
//  Explicit, simulator-only fixture for real Home remote-navigation UI tests.
//

#if DEBUG && os(tvOS) && targetEnvironment(simulator)
import Foundation
import SwiftData
import SwiftUI
import UIKit

@MainActor
enum ViewerFocusUITestFixture {
    nonisolated static var itemCount: Int? {
        guard let value = ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_ITEMS"],
              let count = Int(value), (0...5).contains(count) else { return nil }
        return count
    }

    private static func thumbnail(index: Int) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("theme-fixture-\(index).png")
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 360))
        let image = renderer.image { context in
            let colours: [UIColor] = [.systemTeal, .systemIndigo, .systemOrange, .systemBlue, .systemPurple]
            UIColor(red: 0.05, green: 0.10, blue: 0.15, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 360))
            colours[index].withAlphaComponent(0.45).setFill()
            context.fill(CGRect(x: 0, y: 180, width: 640, height: 180))
            colours[index].withAlphaComponent(0.7).setFill()
            UIBezierPath(ovalIn: CGRect(x: 450, y: 45, width: 90, height: 90)).fill()
            let ridge = UIBezierPath()
            ridge.move(to: CGPoint(x: 0, y: 300))
            ridge.addLine(to: CGPoint(x: 180, y: 200))
            ridge.addLine(to: CGPoint(x: 380, y: 310))
            ridge.addLine(to: CGPoint(x: 640, y: 230))
            ridge.addLine(to: CGPoint(x: 640, y: 360))
            ridge.addLine(to: CGPoint(x: 0, y: 360))
            ridge.close()
            UIColor.black.withAlphaComponent(0.35).setFill()
            ridge.fill()
        }
        try! image.pngData()!.write(to: url, options: .atomic)
        return url
    }

    static func configure(_ environment: AppEnvironment, itemCount: Int) {
        let settings = environment.settingsManager
        settings.iCloudSyncEnabled = false
        let flags = ProcessInfo.processInfo.environment
        if let theme = flags["YATTEE_THEME"].flatMap(TVDesignTheme.init(rawValue:)) {
            settings.tvDesignTheme = theme
        }
        if let mode = flags["YATTEE_MODE"].flatMap(AppTheme.init(rawValue:)) {
            settings.tvAppearanceMode = mode
        }
        settings.homeSectionLayout = .grid
        settings.homeSectionVisibility = Dictionary(uniqueKeysWithValues:
            HomeSectionItem.defaultOrder.map { ($0, $0 == .continueWatching) })
        let suite = "ViewerUIFixture.\(UUID())"
        environment.dataManager.viewerWatchStore = ViewerWatchStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent(suite).appendingPathComponent("watch.json"),
            defaults: UserDefaults(suiteName: suite)!, defaultsDomainName: suite)
        for index in 0..<itemCount {
            let entry = WatchEntry(
                videoID: "focus-fixture-\(index)", sourceRawValue: "global",
                globalProvider: "youtube", title: ["Signal at Low Tide", "Night Transit", "After the Rain", "Field Notes", "Beyond the Horizon"][index],
                authorName: "UI fixture", authorID: "fixture", duration: 600,
                thumbnailURLString: thumbnail(index: index).absoluteString,
                watchedSeconds: 120
            )
            entry.updatedAt = Date(timeIntervalSince1970: 2_000_000_000 - Double(index))
            let owner = environment.viewerProfilesManager.profiles[0].id
            environment.dataManager.updateWatchProgressLocal(for: entry.toVideo(), seconds: 120, viewerID: owner)
            if var record = environment.dataManager.viewerWatchStore?.record(viewerID: owner, key: entry.videoIdentifier.watchHistoryKey) {
                record.updatedAt = entry.updatedAt
                try! environment.dataManager.viewerWatchStore?.save(record)
            }
        }
        environment.dataManager.save()
        let viewers = environment.viewerProfilesManager
        do {
            try viewers.rename(id: viewers.profiles[0].id, name: ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_VIEWER_NAME"] ?? "Alpha")
            if !viewers.profiles.contains(where: { $0.name == "Beta" }) {
                try viewers.add(name: "Beta")
            }
            try viewers.select(id: viewers.profiles[0].id)
        } catch {
            preconditionFailure("Invalid isolated UI-test viewer fixture: \(error)")
        }
        if ProcessInfo.processInfo.environment["YATTEE_HISTORY_SMOKE"] == "1" {
            do {
                try ViewerHistorySmokeChecks.run()
                let marker = WatchEntry(videoID: "history-integration-pass", sourceRawValue: "global", globalProvider: "youtube",
                                        title: "History isolation checks passed", authorName: "Fixture", authorID: "fixture", duration: 600)
                environment.dataManager.updateWatchProgressLocal(for: marker.toVideo(), seconds: 120)
            } catch { preconditionFailure("History integration fixture failed: \(error)") }
        }
        if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SETTINGS"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.settings)
        } else if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SEARCH"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.search)
        } else if ProcessInfo.processInfo.environment["YATTEE_FOCUS_UI_SOURCES"] == "1" {
            environment.navigationCoordinator.router.applyStartupTabIfNeeded(.sources)
        }
    }
}
/// Test-only accessibility report of real stored settings and inherited traits.
/// It does not force the colour scheme or intercept any focus events.
struct ThemeValidationState: View {
    @Environment(\.appEnvironment) private var environment
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        if ViewerFocusUITestFixture.itemCount != nil, let settings = environment?.settingsManager {
            let report = "\(settings.tvDesignTheme.rawValue)|\(settings.tvAppearanceMode.rawValue)|\(scheme == .dark ? "dark" : "light")"
            HStack(spacing: 8) {
                ThemeValidationWindowProbe()
                    .frame(width: 65, height: 18)
                Text("Validation")
                    .font(.caption2)
                    .accessibilityIdentifier("theme.validation.state")
                    .accessibilityValue(report)
                    .onChange(of: report, initial: true) { _, value in
                        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                        try? Data(value.utf8).write(to: directory.appendingPathComponent("theme-validation-state.txt"), options: .atomic)
                    }
                    .allowsHitTesting(false)
            }
            .allowsHitTesting(false)
        }
    }
}

/// Reads the actual containing window, never sets an appearance or focus value.
/// Separate from the original three-part state/file contract above.
private struct ThemeValidationWindowProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> ThemeWindowProbeLabel { ThemeWindowProbeLabel() }
    func updateUIView(_ uiView: ThemeWindowProbeLabel, context: Context) { uiView.report() }
}

private final class ThemeWindowProbeLabel: UILabel {
    override init(frame: CGRect) {
        super.init(frame: frame)
        text = "Window"
        font = .systemFont(ofSize: 12)
        textColor = .secondaryLabel
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        accessibilityIdentifier = "theme.validation.window"
        accessibilityLabel = "Window appearance diagnostics"
    }
    required init?(coder: NSCoder) { fatalError("Not used by the simulator fixture") }
    override var canBecomeFocused: Bool { false }
    override func didMoveToWindow() {
        super.didMoveToWindow()
        report()
    }
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        report()
    }
    func report() {
        guard let window else { accessibilityValue = "detached"; return }
        func style(_ value: UIUserInterfaceStyle) -> String {
            switch value {
            case .light: return "light"
            case .dark: return "dark"
            case .unspecified: return "unspecified"
            @unknown default: return "unknown"
            }
        }
        let scene = window.windowScene.map { style($0.traitCollection.userInterfaceStyle) } ?? "missing"
        accessibilityValue = "\(style(window.overrideUserInterfaceStyle))|\(style(window.traitCollection.userInterfaceStyle))|\(scene)"
    }
}
#endif
