import Foundation

public enum NetworkError: Error {
    case invalidResponse(statusCode: Int)
    case transport(Error)
}

extension NetworkError: Equatable {
     public static func == (lhs: NetworkError, rhs: NetworkError) -> Bool {
         switch (lhs, rhs) {
         case let (.invalidResponse(l), .invalidResponse(r)):
             return l == r
         case (.transport, .transport):
             return true
         default:
             return false
         }
     }
 }
