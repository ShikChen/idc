import Foundation
import ObjCExceptionCatcher

enum PredicateValidationError: Error, CustomStringConvertible {
    case invalid(String)

    var description: String {
        switch self {
        case let .invalid(message):
            return message
        }
    }
}

enum PredicateValidator {
    static func validate(_ format: String) throws {
        var errorMessage: NSString?
        let predicate = ObjCExceptionCatcher.perform({
            NSPredicate(format: format, argumentArray: [])
        }, errorMessage: &errorMessage) as? NSPredicate
        guard predicate != nil else {
            throw PredicateValidationError.invalid(errorMessage as String? ?? "Invalid predicate.")
        }
    }
}
