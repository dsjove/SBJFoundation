import Foundation

import SBJDataDefinition
@propertyWrapper
public struct DefaultsStorage<Value> {
	public let key: String
	public let store: UserDefaults
	public let defaultValue: Value
	private let getter: (UserDefaults, String, Value) -> Value
	private let setter: (UserDefaults, String, Value) -> Void

	public init(
		wrappedValue defaultValue: Value,
		_ key: String,
		store: UserDefaults = .standard,
		get: @escaping (UserDefaults, String, Value) -> Value,
		set: @escaping (UserDefaults, String, Value) -> Void
	) {
		self.key = key
		self.store = store
		self.defaultValue = defaultValue
		self.getter = get
		self.setter = set
	}

	public var wrappedValue: Value {
		get { getter(store, key, defaultValue) }
		nonmutating set { setter(store, key, newValue) }
	}

	public func erase() {
		store.removeObject(forKey: key)
	}
}

// MARK: - DefaultsStorageValue support

public protocol DefaultsStorageValue {
	static func read(from defaults: UserDefaults, key: String) -> Self?
	func write(to defaults: UserDefaults, key: String)
}

extension DefaultsStorage where Value: DefaultsStorageValue {
	public init(
		wrappedValue defaultValue: Value,
		_ key: String,
		store: UserDefaults = .standard
	) {
		self.init(
			wrappedValue: defaultValue,
			key,
			store: store,
			get: { defaults, key, defaultValue in
				Value.read(from: defaults, key: key) ?? defaultValue
			},
			set: { defaults, key, newValue in
				newValue.write(to: defaults, key: key)
			}
		)
	}
}

// MARK: - RawRepresentable support

extension DefaultsStorage where Value: RawRepresentable, Value.RawValue: DefaultsStorageValue {
	public init(
		wrappedValue defaultValue: Value,
		_ key: String,
		store: UserDefaults = .standard
	) {
		self.init(
			wrappedValue: defaultValue,
			key,
			store: store,
			get: { defaults, key, defaultValue in
				if let raw = Value.RawValue.read(from: defaults, key: key) {
					if let wrapped = Value(rawValue: raw) {
						return wrapped
					}
				}
				return defaultValue
			},
			set: { defaults, key, newValue in
				newValue.rawValue.write(to: defaults, key: key)
			}
		)
	}
}

// MARK: - Optional support

extension DefaultsStorage {
	public init<Wrapped>(
		wrappedValue defaultValue: Value = nil,
		_ key: String,
		store: UserDefaults = .standard
	) where Value == Optional<Wrapped>, Wrapped: DefaultsStorageValue {
		self.init(
			wrappedValue: defaultValue,
			key,
			store: store,
			get: { defaults, key, defaultValue in
				Wrapped.read(from: defaults, key: key) ?? defaultValue
			},
			set: { defaults, key, newValue in
				if let newValue {
					newValue.write(to: defaults, key: key)
				} else {
					defaults.removeObject(forKey: key)
				}
			}
		)
	}

	public init<Wrapped>(
		wrappedValue defaultValue: Value = nil,
		_ key: String,
		store: UserDefaults = .standard
	) where Value == Optional<Wrapped>, Wrapped: RawRepresentable, Wrapped.RawValue: DefaultsStorageValue {
		self.init(
			wrappedValue: defaultValue,
			key,
			store: store,
			get: { defaults, key, defaultValue in
				if let raw = Wrapped.RawValue.read(from: defaults, key: key) {
					if let wrapped = Wrapped(rawValue: raw) {
						return wrapped
					}
				}
				return defaultValue
			},
			set: { defaults, key, newValue in
				if let newValue {
					newValue.rawValue.write(to: defaults, key: key)
				} else {
					defaults.removeObject(forKey: key)
				}
			}
		)
	}
}

// MARK: - Conversion types
// NOTE: Codable support is intentionally outside the scope of this UserDefaults wrapper.

extension UUID: DefaultsStorageValue {
	public static func read(from defaults: UserDefaults, key: String) -> UUID? {
		UUID(uuidString: defaults.object(forKey: key) as? String ?? "")
	}

	public func write(to defaults: UserDefaults, key: String) {
		defaults.set(self.uuidString, forKey: key)
	}
}

// Note: Collection support not consistent
// Note: Specialized read required for consistent behavior
extension URL: DefaultsStorageValue {
	public static func read(from defaults: UserDefaults, key: String) -> URL? {
		defaults.url(forKey: key)
	}

	public func write(to defaults: UserDefaults, key: String) {
		defaults.set(self, forKey: key)
	}
}

// MARK: - Native UserDefaults-supported types

public protocol PropertyListType {}

extension DefaultsStorageValue where Self: PropertyListType {
	public static func read(from defaults: UserDefaults, key: String) -> Self? {
		defaults.object(forKey: key) as? Self
	}

	public func write(to defaults: UserDefaults, key: String) {
		defaults.set(self, forKey: key)
	}
}

extension Bool: DefaultsStorageValue, PropertyListType {}
extension Int: DefaultsStorageValue, PropertyListType {}
extension Double: DefaultsStorageValue, PropertyListType {}
extension Float: DefaultsStorageValue, PropertyListType {}
extension String: DefaultsStorageValue, PropertyListType {}
extension Data: DefaultsStorageValue, PropertyListType {}
extension Date: DefaultsStorageValue, PropertyListType {}
//Note: Collections of DefaultsStorageValue is intentionally not supported
extension Array: DefaultsStorageValue, PropertyListType
	where Element: PropertyListType {}
extension Dictionary: DefaultsStorageValue, PropertyListType
	where Key == String, Value: PropertyListType {}
