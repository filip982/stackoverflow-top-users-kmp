import Foundation

final class UserDefaultsFollowStore: FollowStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "followed_user_ids"
    
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }
    
    private var ids: Set<Int> {
        get {
            let array = defaults.array(forKey: key) as? [Int] ?? []
            return Set(array)
        }
        set {
            defaults.set(Array(newValue), forKey: key)
        }
    }
    
    func isFollowed(_ id: Int) -> Bool {
        ids.contains(id)
    }
    
    func setFollowed(_ followed: Bool, for id: Int) {
        var current = ids
        if followed { current.insert(id) } else { current.remove(id) }
        ids = current
    }
}
