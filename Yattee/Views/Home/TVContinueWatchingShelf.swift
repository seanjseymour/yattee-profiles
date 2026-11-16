//
//  TVContinueWatchingShelf.swift
//  Yattee
//
//  Two presentations of the same Continue Watching data and actions.
//

import Foundation
import SwiftUI

#if os(tvOS)
struct TVContinueWatchingShelf: View {
    let entries: [WatchEntry]
    let theme: TVDesignTheme
    let queueSource: QueueSource
    let loadMoreVideos: LoadMoreVideosCallback
    let onRemove: (WatchEntry) -> Void

    @Environment(\.tvDesignPalette) private var palette

    private var videos: [Video] { entries.map { $0.toVideo() } }

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            if theme == .horizon, let first = entries.first {
                TVResumeHero(entry: first, queueSource: queueSource,
                             videos: videos, loadMoreVideos: loadMoreVideos,
                             onRemove: { onRemove(first) })
                if entries.count > 1 {
                    cards(Array(entries.dropFirst()))
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("home.section.continueWatching")
                        .font(.largeTitle.bold())
                    Text("Pick up where you left off.")
                        .font(.title3)
                        .foregroundStyle(palette.secondary)
                }
                cards(entries)
            }
        }
        .foregroundStyle(palette.foreground)
    }

    private func cards(_ items: [WatchEntry]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 300, maximum: 480), spacing: 40)],
                  alignment: .leading, spacing: 40) {
            ForEach(items, id: \.videoIdentifier) { entry in
                ContinueWatchingGridCard(entry: entry)
                    .tappableVideo(
                        entry.toVideo(), startTime: entry.watchedSeconds,
                        customActions: [VideoContextAction(
                            String(localized: "continueWatching.remove"),
                            systemImage: "xmark.circle", role: .destructive,
                            action: { onRemove(entry) }
                        )],
                        context: .continueWatching,
                        queueSource: queueSource,
                        sourceLabel: String(localized: "queue.source.continueWatching"),
                        videoList: videos,
                        videoIndex: entries.firstIndex { $0.videoIdentifier == entry.videoIdentifier },
                        loadMoreVideos: loadMoreVideos
                    )
                    .modifier(TVDesignCardFocus())
            }
        }
        .padding(12)
        .focusSection()
    }
}

private struct TVResumeHero: View {
    let entry: WatchEntry
    let queueSource: QueueSource
    let videos: [Video]
    let loadMoreVideos: LoadMoreVideosCallback
    let onRemove: () -> Void
    @Environment(\.tvDesignPalette) private var palette
    @FocusState private var resumeFocused: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 48) {
            VStack(alignment: .leading, spacing: 22) {
                Text("home.section.continueWatching")
                    .font(.headline)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.accent)
                Text(entry.title)
                    .font(.system(size: 48, weight: .bold))
                    .lineLimit(3)
                Text(entry.authorName)
                    .font(.title3)
                    .foregroundStyle(palette.secondary)
                    .lineLimit(1)
                if !entry.isLive {
                    Text(String(localized: "home.history.remaining \(entry.remainingTime)"))
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                }
                // Reuse the existing authenticated playback/queue path, with
                // explicit resume time, rather than bypassing the video router.
                Label("Resume", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundStyle(resumeFocused ? palette.focusForeground : palette.foreground)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 20)
                    .background(resumeFocused ? palette.accent : palette.surface,
                                in: RoundedRectangle(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(resumeFocused ? palette.accent : palette.border, lineWidth: 3)
                    }
                    .tappableVideo(
                        entry.toVideo(),
                        startTime: entry.isLive ? nil : entry.watchedSeconds,
                        forcePlayback: true,
                        customActions: [VideoContextAction(
                            String(localized: "continueWatching.remove"),
                            systemImage: "xmark.circle", role: .destructive, action: onRemove
                        )],
                        context: .continueWatching,
                        queueSource: queueSource,
                        sourceLabel: String(localized: "queue.source.continueWatching"),
                        videoList: videos,
                        videoIndex: 0,
                        loadMoreVideos: loadMoreVideos
                    )
                    .focused($resumeFocused)
                    .accessibilityIdentifier("home.horizon.resume")
                    .accessibilityLabel(Text("Resume \(entry.title)"))
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VideoThumbnailView(url: entry.thumbnailURL, cornerRadius: 28,
                               watchProgress: entry.progress, placeholderTitle: entry.title)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)
        }
        .padding(16)
        .focusSection()
    }
}

struct TVHomeEmptyState: View {
    let browseSources: () -> Void
    @Environment(\.tvDesignPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("home.section.continueWatching")
                .font(.largeTitle.bold())
            Image(systemName: "play.circle")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(palette.accent)
                .accessibilityHidden(true)
            Text("Nothing to resume yet")
                .font(.title2.bold())
            Text("Start a video to see it here next time.")
                .font(.title3)
                .foregroundStyle(palette.secondary)
            Button(action: browseSources) {
                Text("Browse sources")
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
            .buttonStyle(TVDesignButtonStyle())
            .accessibilityIdentifier("home.empty.browseSources")
        }
        .padding(48)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(palette.foreground)
        .background(palette.surface, in: RoundedRectangle(cornerRadius: 28))
    }
}

private struct TVDesignCardFocus: ViewModifier {
    @Environment(\.tvDesignPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focused($focused)
            .padding(10)
            .background(focused ? palette.surface : Color.clear, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(focused ? palette.accent : Color.clear, lineWidth: 3)
            }
            .scaleEffect(focused && !reduceMotion ? 1.025 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: focused)
    }
}
#endif
