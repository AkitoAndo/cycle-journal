import SwiftUI
import XCTest
@testable import Cycle

final class AppearanceModeTests: XCTestCase {
    func testSystemModeUsesDeviceAppearance() {
        XCTAssertNil(AppearanceMode.system.colorScheme)
    }

    func testExplicitModesMapToExpectedColorSchemes() {
        XCTAssertEqual(AppearanceMode.light.colorScheme, .light)
        XCTAssertEqual(AppearanceMode.dark.colorScheme, .dark)
    }

    func testStoredRawValuesCanBeRestored() {
        for mode in AppearanceMode.allCases {
            XCTAssertEqual(AppearanceMode(rawValue: mode.rawValue), mode)
        }
    }
}
