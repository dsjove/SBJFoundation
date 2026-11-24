import Foundation

/// General domain-invariant helpers that do not depend on SBJStructure.
public enum SBJInvariantCheck {
    public static func validate<T>(_ value: T, at keyPath: SBJValidationKeyPath) throws {
        if let checkable = value as? any HasContentCheckable {
            try checkable.invariant(at: keyPath)
        }
    }

    public static func validationError<T>(_ value: T, at keyPath: SBJValidationKeyPath) -> SBJValidationError? {
        do {
            try validate(value, at: keyPath)
            return nil
        } catch let error as SBJValidationError {
            return error
        } catch {
            return SBJValidationError(error.localizedDescription, at: keyPath)
        }
    }

    public static func require(
        _ condition: @autoclosure () -> Bool,
        at keyPath: SBJValidationKeyPath,
        _ message: String
    ) throws {
        guard condition() else { throw SBJValidationError(message, at: keyPath) }
    }

    private static func require<Value>(
        _ condition: @autoclosure () -> Bool,
        value: Value,
        at keyPath: SBJValidationKeyPath,
        _ message: String
    ) throws {
        guard condition() else { throw SBJValidationError(value, at: keyPath, message) }
    }

}
