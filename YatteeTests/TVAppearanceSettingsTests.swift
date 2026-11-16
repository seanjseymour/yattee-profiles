//
//  TVAppearanceSettingsTests.swift
//  YatteeTests
//
//  Independent, device-local TV layout and appearance preferences.
//

import Foundation
import SwiftUI
import Testing
@testable import Yattee
#if canImport(UIKit)
import UIKit
#endif

@Suite("TV appearance preferences", .serialized)
@MainActor
struct TVAppearanceSettingsTests {
    private func withCleanDefaults(_ body: (SettingsManager) -> Void) {
        let settings = SettingsManager()
        let keys = [SettingsKey.tvDesignTheme, .tvAppearanceMode].map(settings.platformKey)
        let saved = keys.map { UserDefaults.standard.object(forKey: $0) }
        for key in keys { UserDefaults.standard.removeObject(forKey: key) }
        defer {
            for (key, value) in zip(keys, saved) {
                if let value {
                    UserDefaults.standard.set(value, forKey: key)
                } else {
                    UserDefaults.standard.removeObject(forKey: key)
                }
            }
            SettingsManager.applyTVAppearance(SettingsManager().tvAppearanceMode)
        }
        body(settings)
    }

    @Test("Defaults are Horizon and System, without storing a resolved scheme")
    func defaults() {
        withCleanDefaults { settings in
            #expect(settings.tvDesignTheme == .horizon)
            #expect(settings.tvAppearanceMode == .system)
            #expect(settings.tvAppearanceMode.colorScheme == nil)
            #expect(settings.localDefaults.object(forKey: settings.platformKey(.tvAppearanceMode)) == nil)
        }
    }

    @Test("TV choices are excluded from iCloud sync")
    func localOnly() {
        for key in [SettingsKey.tvDesignTheme, .tvAppearanceMode] {
            #expect(key.isLocalOnly)
            #expect(key.isPlatformSpecific)
        }
    }

    @Test("All combinations round-trip without one choice resetting the other")
    func independentPersistence() {
        withCleanDefaults { settings in
            let originalSyncedTheme = settings.theme
            for mode in AppTheme.allCases {
                settings.tvAppearanceMode = mode
                for theme in TVDesignTheme.allCases {
                    settings.tvDesignTheme = theme
                    #expect(settings.tvAppearanceMode == mode)
                    let relaunched = SettingsManager()
                    #expect(relaunched.tvDesignTheme == theme)
                    #expect(relaunched.tvAppearanceMode == mode)
                    #expect(relaunched.theme == originalSyncedTheme)
                }
            }
            settings.tvDesignTheme = .slate
            settings.tvAppearanceMode = .light
            settings.tvAppearanceMode = .dark
            settings.tvAppearanceMode = .system
            settings.clearCache()
            #expect(settings.tvDesignTheme == .slate)
            #expect(settings.tvAppearanceMode == .system)
        }
    }

    @Test("Unrecognized persisted values safely fall back")
    func invalidValues() {
        withCleanDefaults { settings in
            settings.localDefaults.set("unknown-theme", forKey: settings.platformKey(.tvDesignTheme))
            settings.localDefaults.set("unknown-mode", forKey: settings.platformKey(.tvAppearanceMode))
            #expect(settings.tvDesignTheme == .horizon)
            #expect(settings.tvAppearanceMode == .system)
        }
    }

    #if canImport(UIKit)
    @Test("System removes the UIKit override rather than locking a resolved style")
    func platformMapping() {
        #expect(AppTheme.system.userInterfaceStyle == .unspecified)
        #expect(AppTheme.light.userInterfaceStyle == .light)
        #expect(AppTheme.dark.userInterfaceStyle == .dark)
    }
    #endif
}
