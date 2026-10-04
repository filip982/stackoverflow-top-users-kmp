import Foundation

struct UsersResponse: Decodable {
    let items: [StackOverflowUser]
}
