# Viewer history implementation and review boundary

Base: build 283, `dafe9869f3bb73266c38c2a80c8c8e9461a4ea3e`.
This change is separate from Viewer layout. Neither ships alone; the combined
candidate requires independent visual and history review, then one internal
TestFlight upload handled by the build thread.

## Ownership and existing data

New tvOS progress uses the stable viewer UUID and a canonical full source plus
video ID. The name, selected server account, and raw video ID alone are not
ownership keys. Full source identity distinguishes federated servers and media
URLs as well as provider names. Renaming retains the UUID.

No original viewer can be proven from profile order or the currently selected
viewer. All existing SwiftData WatchEntry rows remain untouched and unassigned.
This build does not import, copy, claim, clear or migrate them. A later explicit
import can offer an idempotent copy to a deliberately chosen viewer, preserving
the originals. No live NAS/history was examined.

## Read/write coverage

| Path | New boundary |
| --- | --- |
| Home and ContinueWatchingView | Viewer-scoped history, count and in-progress filter; switch notifications reload even into an empty viewer |
| PlayerService periodic/final/completed saves | Captured opening owner; a profile switch does not retarget an existing playback session |
| PlayerService and TappableVideoModifier resume | Full-source video identity and captured/session or current UI viewer as appropriate |
| VideoInfo, thumbnails, search, channel, subscription, playlist, download and bookmark progress indicators | Viewer-scoped reads/maps; bookmark records remain shared and unchanged |
| Local History count, remove, date-based clear, clear-all, mark watched/unwatched | Current viewer only; full source identity for row actions |
| Account History | Remains account-shared and explicitly labeled; personal resume data refreshes on viewer change |
| WatchHistorySyncService | Existing account capture/mirroring remains account-shared; no viewer IDs are added to server identities |
| CloudKit | Existing shared IDs and rows only. Initial upload explicitly enumerates `legacyWatchHistory`; viewer records never enter the mapper |
| Top Shelf | Rebuild Continue Watching for the active viewer, including empty state. A late A save while B is active rebuilds B, never A. Notify tvOS to refresh; its display update is asynchronous |

NAS connections, accounts, credentials, cloud settings, bookmarks and app
identity are unchanged. Account-server history is not promised isolated.
Top Shelf's existing deep links contain no saved timestamp, so a stale system
tile opens with the active viewer's resume lookup rather than another viewer's
position. System caching/overscan still require device verification.

## Playback ownership

An explicit opening captures a `ViewerPlaybackOwnership.Session` before async
loading. Quality changes/retries and automatic queue playback retain it. An
explicit opening by another viewer gets a new session, even for the same video.
The prior owner is saved before state replacement; the old timer is invalidated
and the clock reset. The periodic-save deduplication key includes the session.
Load-generation guards reject stale async results. Crossing a viewer boundary
uses a new backend and rejects callbacks from the retired viewer's backend.

## Bounded local recovery proposal

The full viewer history is a separate versioned JSON file under Library/Caches,
written atomically. It never falls back silently to an in-memory history store.
Unreadable or newer-version bytes are preserved and writes fail closed.

A separate defaults key holds at most 20 recent records per viewer and at most
128 KiB total. Older records remain in the primary file; they are not deleted to
fit the recovery snapshot. Projected app defaults must stay below 384 KiB or the
save is rejected with a visible warning. Nothing changes the existing defaults
keys. This is bounded resume recovery, not an unbounded defaults history blob.

If the primary cache disappears, restore the recovery snapshot and explicitly
report whether recovery was partial. Cache recovery may lose older records;
defaults writes are asynchronous, so it is not a crash-proof transaction or a
reinstall/device-loss backup. No cloud recovery is added or enabled.

**Product decision before release:** accept the 20-per-viewer / 128-KiB recent
recovery boundary, or require a separate external backup design before shipping.
Do not describe unlimited history as durable. Apple documents a tvOS defaults
warning at 512 KiB and termination at 1 MiB:
https://developer.apple.com/documentation/foundation/userdefaults/sizelimitexceededmessage

## Acceptance tests and limits

Synthetic tests cover A/B watching the same video at distinct timestamps;
A → B → A reads; same ID across sources; removing B without changing A;
relaunch; captured A ownership through a B selection/quality retry and late
close; bounded cache-loss recovery; non-resurrection after removal; preservation
of separate legacy bytes and unknown versions; capacity/invalid-progress errors.

Model tests alone do not establish actual player-backend timing, Top Shelf
refresh, UI cache behavior, or hardware playback. Those require integration and
device checks. Validate a synthetic SwiftData legacy row remains untouched and
absent from each new viewer, and run the existing gesture suite on the combined
candidate. No real NAS/history, credentials or account writes belong in CI.

Reviewer must inspect the source-aware compatibility adapters, CloudKit initial
upload boundary, stale-session/backend guards, and storage error/partial-recovery
UI. Import is deliberately deferred, not silently assigned to Leslie or Sean.
