# SBJLocation

`SBJLocation` supplies a Core Location-backed, observable location provider and a
Codable representation of location measurements. It depends on `SBJLocalization`.

## Use a location provider

```swift
import CoreLocation
import SBJLocation

@MainActor
func beginLocationFeature() -> any LocationProvider {
    let provider = LocationFactory.make()
    // Hold onto this provider while the feature needs location updates.
    return provider
}
```

`LocationFactory.make()` creates an eager provider: it checks authorization and
starts acquisition on supported platforms once authorized. When permission is
not determined, it requests *when-in-use* access. This package does not expose
explicit one-shot requests, background-location configuration, or a user-selected
accuracy mode. The provider caches the newest accepted valid position; it is not
a guarantee that the value is recent or meets your application's accuracy needs.

Use `authorizationStatus` and `canGetLocation` to check permission.
`currentLocation` is `nil` until a valid fix is available and after permission is
lost. **Do not interpret nil as (0, 0)**: the coordinate (0, 0) can be valid.

## Observe permission changes

```swift
import SBJLocation
import SBJLocalization

@MainActor
func watchPermission(_ provider: any LocationProvider) -> ObserveToken {
    provider.observeAuthorization { status in
        // Update your UI based on Core Location's authorization status.
    }
}
```

Retain the `ObserveToken` until observation is no longer needed. Calling
`cancel()` or releasing the token stops future callbacks. Registration schedules
an **asynchronous initial callback** with the current authorization status;
subsequent changes are reported on the main actor. The example returns the
token so the caller can retain it. The provider must also remain alive.

The provider caches live updates as they arrive; it does **not** deliver a
separate notification callback for location changes. Its concrete implementation
is Observation-enabled, but the returned `LocationProvider` interface does not
promise an observation mechanism for `currentLocation`.

## Persist a fix and examine meaningful content

```swift
import SBJLocation

if let fix = provider.currentLocation {
    let value = LocationValue(fix)
    if value.hasContent {
        // Use or encode the meaningful location measurement.
    }
}
```

`LocationValue` preserves the coordinate, altitude, accuracies, course, speed,
and timestamp through Codable conversion. It adopts `HasContentCheckable` from
`SBJLocalization`; `hasContent` means that latitude/longitude are valid and
horizontal accuracy is known (nonnegative and finite). It does **not** mean
that a fix is sufficiently recent or accurate for your particular use case.
Unknown altitude, course, and speed do not invalidate a position.
`LocationValue` intentionally does not adopt `SBJStructuralComparable`: its
`Equatable` contract already compares its stored measurements and no different
structural equivalence is specified.

## Application setup and platform limitations

The **host app** must include the appropriate location usage description in
its Info.plist (for when-in-use requests, `NSLocationWhenInUseUsageDescription`).
For sandboxed macOS apps, enable the Location entitlement
(`com.apple.security.personal-information.location`). System-level Location
Services and the user's authorization must also allow access. Test permissions
on actual hardware when integrating; the package's unit tests do not request
location permission or require GPS.

The package declares iOS 17+, macOS 14+, Mac Catalyst 17+, watchOS 10+,
tvOS 17+, and visionOS 1+. Continuous `startUpdatingLocation` is excluded on
tvOS; do not assume continuous live updates there. Updates stop when permission
is revoked on supported platforms. Location acquisition is an active service;
keep the provider only for the period your feature requires it.
