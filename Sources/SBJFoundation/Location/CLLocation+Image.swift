import CoreLocation
import ImageIO
import UniformTypeIdentifiers

public struct LocationJSON: SBJFoundationType {
	public var latitude: CLLocationDegrees
	public var longitude: CLLocationDegrees
	public var altitude: CLLocationDistance
	public var horizontalAccuracy: CLLocationAccuracy
	public var verticalAccuracy: CLLocationAccuracy
	public var course: CLLocationDirection
	public var courseAccuracy: CLLocationDirectionAccuracy
	public var speed: CLLocationSpeed
	public var speedAccuracy: CLLocationSpeedAccuracy
	public var timestamp: Date

	public init(_ location: CLLocation) {
		latitude = location.coordinate.latitude
		longitude = location.coordinate.longitude
		altitude = location.altitude
		horizontalAccuracy = location.horizontalAccuracy
		verticalAccuracy = location.verticalAccuracy
		course = location.course
		courseAccuracy = location.courseAccuracy
		speed = location.speed
		speedAccuracy = location.speedAccuracy
		timestamp = location.timestamp
	}

	public var location: CLLocation {
		CLLocation(
			coordinate: .init(latitude: latitude, longitude: longitude),
			altitude: altitude,
			horizontalAccuracy: horizontalAccuracy,
			verticalAccuracy: verticalAccuracy,
			course: course,
			courseAccuracy: courseAccuracy,
			speed: speed,
			speedAccuracy: speedAccuracy,
			timestamp: timestamp
		)
	}
}

extension CLLocation {
	public convenience init?(gpsMetadata: [String: Any]?) {
		guard let gpsMetadata else { return nil }
		func number(_ key: CFString) -> Double? {
			let value = gpsMetadata[key as String]
			if let value = value as? Double { return value }
			if let value = value as? Float { return Double(value) }
			if let value = value as? Int { return Double(value) }
			if let value = value as? NSNumber { return value.doubleValue }
			if let value = value as? String { return Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
			return nil
		}

		func int(_ key: CFString) -> Int? {
			let value = gpsMetadata[key as String]
			if let value = value as? Int { return value }
			if let value = value as? NSNumber { return value.intValue }
			if let value = value as? String { return Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) }
			return nil
		}

		func string(_ key: CFString) -> String? {
			let value = gpsMetadata[key as String]
			if let value = value as? String { return value }
			if let value = value as? NSString { return value as String }
			if let value = value as? NSNumber { return value.stringValue }
			return nil
		}

		guard
			let latitude = number(kCGImagePropertyGPSLatitude),
			let latitudeRef = string(kCGImagePropertyGPSLatitudeRef),
			let longitude = number(kCGImagePropertyGPSLongitude),
			let longitudeRef = string(kCGImagePropertyGPSLongitudeRef)
		else {
			return nil
		}
		let signedLatitude = latitudeRef.uppercased().hasPrefix("S") ? -abs(latitude) : abs(latitude)
		let signedLongitude = longitudeRef.uppercased().hasPrefix("W") ? -abs(longitude) : abs(longitude)

		guard CLLocationCoordinate2DIsValid(
			CLLocationCoordinate2D(latitude: signedLatitude, longitude: signedLongitude)
		) else {
			return nil
		}

		let timestamp: Date = {
			guard
				let dateString = string(kCGImagePropertyGPSDateStamp),
				let timeString = string(kCGImagePropertyGPSTimeStamp)
			else {
				return Date()
			}

			let combined = "\(dateString) \(timeString)"

			let formats = [
				"yyyy:MM:dd HH:mm:ss.SSSSSS",
				"yyyy:MM:dd HH:mm:ss.SSS",
				"yyyy:MM:dd HH:mm:ss",
				"yyyy-MM-dd HH:mm:ss.SSSSSS",
				"yyyy-MM-dd HH:mm:ss.SSS",
				"yyyy-MM-dd HH:mm:ss"
			]

			for format in formats {
				let formatter = DateFormatter()
				formatter.locale = Locale(identifier: "en_US_POSIX")
				formatter.timeZone = TimeZone(secondsFromGMT: 0)
				formatter.dateFormat = format

				if let date = formatter.date(from: combined) {
					return date
				}
			}

			return Date()
		}()

		var altitude: CLLocationDistance = 0
		var verticalAccuracy: CLLocationAccuracy = -1

		if let encodedAltitude = number(kCGImagePropertyGPSAltitude) {
			let altitudeRef = int(kCGImagePropertyGPSAltitudeRef) ?? 0
			altitude = altitudeRef == 1 ? -abs(encodedAltitude) : abs(encodedAltitude)
			verticalAccuracy = 0
		}

		let horizontalAccuracy =
			number(kCGImagePropertyGPSDOP).map { CLLocationAccuracy($0) } ?? -1

		let course =
			number(kCGImagePropertyGPSImgDirection).map { CLLocationDirection($0) } ?? -1

		self.init(
			coordinate: CLLocationCoordinate2D(
				latitude: signedLatitude,
				longitude: signedLongitude
			),
			altitude: altitude,
			horizontalAccuracy: horizontalAccuracy,
			verticalAccuracy: verticalAccuracy,
			course: course,
			speed: -1,
			timestamp: timestamp
		)
	}
}

extension CLLocation {
	public convenience init?(image data: Data) {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil)
		else {
			return nil
		}
		let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
		let existingGPS = props?[kCGImagePropertyGPSDictionary] as? [String: Any]
		self.init(gpsMetadata: existingGPS)
	}

	public var gpsMetadata: [String: Any] {
		let coordinate = self.coordinate
		let altitude = self.altitude
		let timestamp = self.timestamp

		let lat = abs(coordinate.latitude)
		let lon = abs(coordinate.longitude)

		let dateFormatter = DateFormatter()
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.dateFormat = "yyyy:MM:dd"

		let timeFormatter = DateFormatter()
		timeFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		timeFormatter.dateFormat = "HH:mm:ss.SSSSSS"

		var gps: [String: Any] = [
			kCGImagePropertyGPSLatitude as String: lat,
			kCGImagePropertyGPSLatitudeRef as String: coordinate.latitude >= 0 ? "N" : "S",
			kCGImagePropertyGPSLongitude as String: lon,
			kCGImagePropertyGPSLongitudeRef as String: coordinate.longitude >= 0 ? "E" : "W",
			kCGImagePropertyGPSTimeStamp as String: timeFormatter.string(from: timestamp),
			kCGImagePropertyGPSDateStamp as String: dateFormatter.string(from: timestamp),
			kCGImagePropertyGPSDOP as String: self.horizontalAccuracy,
			kCGImagePropertyGPSImgDirection as String: self.course >= 0 ? self.course : 0,
			kCGImagePropertyGPSImgDirectionRef as String: "T"
		]
		if verticalAccuracy >= 0 {
			gps[kCGImagePropertyGPSAltitude as String] = abs(altitude)
			gps[kCGImagePropertyGPSAltitudeRef as String] = altitude >= 0 ? 0 : 1
		}
		return gps
	}

	public func injectInto(image data: Data, override: Bool = false) -> Data {
		guard let source = CGImageSourceCreateWithData(data as CFData, nil)
		else {
			return data
		}

		var props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]
		let existingGPS = props[kCGImagePropertyGPSDictionary] as? [String: Any] ?? [:]
		guard override || existingGPS.isEmpty
		else {
			return data
		}

		let gpsMetadata = self.gpsMetadata
		guard !gpsMetadata.isEmpty,
			  let type = CGImageSourceGetType(source),
			  let output = NSMutableData() as CFMutableData?,
			  let destination = CGImageDestinationCreateWithData(output, type, 1, nil)
		else {
			return data
		}

		props[kCGImagePropertyGPSDictionary] = gpsMetadata
		CGImageDestinationAddImageFromSource(destination, source, 0, props as CFDictionary)
		guard CGImageDestinationFinalize(destination)
		else {
			return data
		}

		return output as Data
	}
}
