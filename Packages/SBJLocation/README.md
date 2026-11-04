# SBJLocation

`SBJLocation` provides an abstraction for acquiring and observing the device's location without binding application code to a concrete `CLLocationManager` implementation. Use it for features that need a cached location, authorization state, and notifications of authorization changes.

## Getting started

```swift
import CoreLocation
import SBJLocation

@MainActor
func checkLocation() {
    let provider = LocationFactory.make()
    if provider.canGetLocation, let location = provider.currentLocation {
        print(location.coordinate.latitude, location.coordinate.longitude)
    }
}
```

`LocationFactory.make()` returns a `LocationProvider`. Keep the provider alive for as long as your feature needs it. `currentLocation` may be `nil`; do not interpret that as a location at `(0, 0)`. For changing permissions, use `observeAuthorization(_:)` and retain its returned `ObserveToken` for the desired observation lifetime.

Apps must supply the appropriate Core Location usage-description entries in their own Info.plist and handle authorization before relying on coordinates. `LocationValue` provides a Codable representation when a model needs to store location data.

## macOS

Native macOS 14+ is supported using the same `CoreLocation` implementation as iOS;
no AppKit-specific adapter is required. The host application, not this package,
must provide `NSLocationWhenInUseUsageDescription` in its Info.plist. If the app
uses App Sandbox, enable the Location entitlement (`com.apple.security.personal-information.location`).
The system may return no location when Location Services are disabled or permission
has not yet been granted.
