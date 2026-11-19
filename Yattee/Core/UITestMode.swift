//
//  UITestMode.swift
//  Yattee
//
//  Debug-only tvOS launch mode for UI tests: throwaway stores, two fixed viewers
//  and a generated local clip. Compiled out of Release and TestFlight builds.
//

#if DEBUG && os(tvOS)
import AVFoundation
import CoreVideo
import Foundation

/// Enabled only by the `-YatteeUITestMode` launch argument, and only in builds
/// that define `DEBUG` (the Debug and Debug-CKDev configurations).
///
/// When active it never touches the real viewer store or SwiftData store: the
/// viewers and their history live in their own `UserDefaults` suite and a temp
/// folder, and `DataManager` is in-memory. `SettingsManager` reads
/// `UserDefaults.standard` directly, so the app's standard domain is cleared at
/// launch instead; every launch starts from default settings.
enum UITestMode {
    static let launchArgument = "-YatteeUITestMode"
    /// Optional: `-YatteeUITestStartTab <SidebarMainItem raw value>`.
    static let startTabArgument = "-YatteeUITestStartTab"

    static let isActive: Bool = ProcessInfo.processInfo.arguments.contains(launchArgument)

    // Fixed IDs so tests can address `viewerPicker.select.<UUID>`.
    static let viewerA = UUID(uuidString: "0000000A-0000-4000-8000-000000000000")!
    static let viewerB = UUID(uuidString: "0000000B-0000-4000-8000-000000000000")!

    /// In-progress history seeded for viewer A only. Not playable; never select it.
    static let seededTitle = "UITest A Seeded Video"
    /// A generated local clip, bookmarked so every viewer can play it from Home.
    static let clipTitle = "UITest Local Clip"
    /// Long enough that a test never reaches the 90% "finished" mark.
    static let clipSeconds = 600

    static let suiteName = "YatteeUITestMode"

    static var rootDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("YatteeUITestMode", isDirectory: true)
    }
    static var watchStoreURL: URL { rootDirectory.appendingPathComponent("ViewerWatch-v1.json") }
    static var clipURL: URL { rootDirectory.appendingPathComponent("uitest-clip.mp4") }
    static var defaults: UserDefaults { UserDefaults(suiteName: suiteName)! }

    static var startTab: SidebarMainItem? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: startTabArgument), index + 1 < arguments.count else { return nil }
        return SidebarMainItem(rawValue: arguments[index + 1])
    }

    /// Clears everything test mode owns and writes the two viewers. Runs once,
    /// before any store is created.
    static let prepare: Void = {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: rootDirectory)
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        // Debug builds send LoggingService output to os_log only when this is on;
        // CI collects it from the simulator log.
        UserDefaults.standard.set(true, forKey: "loggingEnabled")
        writeViewers()
        NSLog("UITestMode: prepared \(rootDirectory.path)")
    }()

    /// Same shape as `ViewerProfilesManager`'s private snapshot (version 1).
    private struct ViewerSnapshot: Codable {
        var version = 1
        var profiles: [ViewerProfile]
        var activeViewerID: UUID?
    }

    private static func writeViewers() {
        let snapshot = ViewerSnapshot(
            profiles: [ViewerProfile(id: viewerA, name: "A"), ViewerProfile(id: viewerB, name: "B")],
            activeViewerID: viewerA
        )
        // Key matches `ViewerProfilesManager.storageKey`.
        defaults.set(try? JSONEncoder().encode(snapshot), forKey: "yatteeProfiles.localViewers.v1")
    }

    static var seededVideo: Video {
        Video(id: VideoID(source: .global(provider: ContentSource.youtubeProvider), videoID: "uitestSeededA1"),
              title: seededTitle, description: nil, author: Author(id: "uitest", name: "UITest"),
              duration: 600, publishedAt: nil, publishedText: nil, viewCount: nil, likeCount: nil,
              thumbnails: [], isLive: false, isUpcoming: false, scheduledStartTime: nil)
    }

    /// Played through the app's normal direct-media path (`PlayerService` → MPV).
    static var clipVideo: Video {
        Video(id: VideoID(source: .extracted(extractor: DirectMediaHelper.provider, originalURL: clipURL),
                          videoID: clipURL.absoluteString),
              title: clipTitle, description: nil, author: Author(id: "uitest", name: "UITest"),
              duration: Double(clipSeconds), publishedAt: nil, publishedText: nil, viewCount: nil, likeCount: nil,
              thumbnails: [], isLive: false, isUpcoming: false, scheduledStartTime: nil)
    }

    /// Settings and seed data. Called at the end of `AppEnvironment.init`.
    @MainActor
    static func configure(_ environment: AppEnvironment) {
        let settings = environment.settingsManager
        // Select plays (no info screen) and never opens the queue sheet.
        settings.tvOSVideoTapAction = .playVideo
        settings.queueEnabled = false
        var sections = settings.homeSectionVisibility
        sections[.bookmarks] = true
        settings.homeSectionVisibility = sections
        var sidebar = settings.sidebarMainItemVisibility
        sidebar[.continueWatching] = true
        settings.sidebarMainItemVisibility = sidebar
        if let startTab {
            settings.sidebarStartupTab = startTab
        }

        let dataManager = environment.dataManager
        _ = dataManager.saveViewerProgress(for: seededVideo, seconds: 120, duration: 600,
                                           isLive: false, viewerID: viewerA)
        if makeClip() {
            dataManager.addBookmark(for: clipVideo)
            NSLog("UITestMode: clip ready at \(clipURL.path)")
        } else {
            NSLog("UITestMode: could not generate the local clip")
        }
    }

    /// Writes a silent 320×180 H.264 clip, one grey frame per second.
    private static func makeClip() -> Bool {
        let url = clipURL
        try? FileManager.default.removeItem(at: url)
        guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return false }
        let width = 320, height = 180
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ])
        guard writer.canAdd(input) else { return false }
        writer.add(input)
        guard writer.startWriting() else { return false }
        writer.startSession(atSourceTime: .zero)

        for second in 0..<clipSeconds {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            guard let pool = adaptor.pixelBufferPool else { return false }
            var pixelBuffer: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard let buffer = pixelBuffer else { return false }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, Int32(40 + (second * 7) % 180), CVPixelBufferGetDataSize(buffer))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(second), timescale: 1)) else {
                return false
            }
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(clipSeconds), timescale: 1))
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()
        return writer.status == .completed
    }
}
#endif
