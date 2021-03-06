@testable import FinchCore
import SnapshotTesting
import XCTest

final class ConfigurationTests: TestCase {
    func testOverriddenWithPartialConfig() {
        var config: Configuration = .mockExcludedSection
        let otherConfig: Configuration = .default(projectDir: "")

        otherConfig.merge(into: &config)

        assertSnapshot(matching: config, as: .dump)
    }
}
