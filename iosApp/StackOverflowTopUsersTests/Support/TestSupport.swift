import Foundation
import XCTest
@testable import StackOverflowTopUsers

/// A few users taken from /fixtures/users.json (same ids/values the Android and shared tests use).
enum FixtureUsers {
    static let jon = UserModel(
        id: 22656, displayName: "Jon Skeet", reputation: 1_520_345,
        avatarUrl: "http://localhost:8080/avatars/22656.png",
        location: "Reading, United Kingdom", websiteUrl: "http://csharpindepth.com",
        creationDate: 1_222_430_705, lastModifiedDate: 1_727_873_400
    )
    static let gordon = UserModel(
        id: 1_144_035, displayName: "Gordon Linoff", reputation: 1_300_000,
        avatarUrl: "http://localhost:8080/avatars/1144035.png",
        location: "New York, United States", websiteUrl: "http://www.data-miners.com",
        creationDate: 1_326_311_637, lastModifiedDate: 1_727_000_000
    )
    static let alex = UserModel(
        id: 95810, displayName: "Alex Martelli", reputation: 900_000,
        avatarUrl: nil,
        location: "Sunnyvale, CA", websiteUrl: "http://www.aleax.it",
        creationDate: 1_240_500_000, lastModifiedDate: nil
    )
    static let quentin = UserModel(
        id: 19068, displayName: "Quentin", reputation: 960_000,
        avatarUrl: "http://localhost:8080/avatars/19068.png", location: nil, websiteUrl: nil,
        creationDate: 1_222_900_000, lastModifiedDate: 1_727_300_000
    )

    /// Deliberately not in reputation order.
    static let all: [UserModel] = [alex, jon, quentin, gordon]
    static let byReputationDesc: [UserModel] = [jon, gordon, quentin, alex]
    static let byNameAsc: [UserModel] = [alex, gordon, jon, quentin]
}

extension XCTestCase {
    /// Polls `condition` on the main actor, letting store tasks run in between.
    @MainActor
    func waitUntil(
        timeout: TimeInterval = 2,
        _ message: @autoclosure () -> String = "condition not met in time",
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail(message(), file: file, line: line)
                return
            }
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    /// Gives already-scheduled main-actor work a chance to run (for "nothing changed" assertions).
    @MainActor
    func settle() async {
        for _ in 0..<20 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }
}
