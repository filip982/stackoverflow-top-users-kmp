import Foundation

protocol FollowStoring: Sendable {
    func isFollowed(_ id: Int) -> Bool
    func setFollowed(_ followed: Bool, for id: Int)
}

