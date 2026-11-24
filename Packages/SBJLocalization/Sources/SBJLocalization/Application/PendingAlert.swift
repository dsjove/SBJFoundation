import SwiftUI

public struct PendingAlert: Identifiable {
	public let id: UUID
	public let alertable: any Alertable
	public let action: () -> Void
	public let dismissAction: () -> Void

	public init(
		_ alertable: any Alertable,
		id: UUID = UUID(),
		action: @escaping () -> Void = {},
		dismissAction: @escaping () -> Void = {}
	) {
		self.id = id
		self.alertable = alertable
		self.action = action
		self.dismissAction = dismissAction
	}
}

public protocol Alertable {
	var title: String { get }
	var message: String { get }
	var primaryButtonTitle: String { get }
}

// MARK: - SwiftUI presentation

public extension View {
	/// Presents a `PendingAlert` when the binding contains a value.
	///
	/// The existing `Alertable` convention is intentionally preserved here:
	/// an empty `primaryButtonTitle` means this is an informational alert with
	/// only an OK button; a non-empty title presents the supplied action plus a
	/// system cancel button.
	///
	/// Example:
	/// ```swift
	/// @State private var pendingAlert: PendingAlert?
	///
	/// body
	///     .pendingAlert($pendingAlert)
	/// ```
	func pendingAlert(_ pendingAlert: Binding<PendingAlert?>) -> some View {
		alert(item: pendingAlert) { pending in
			if pending.alertable.primaryButtonTitle.isEmpty {
				Alert(
					title: Text(pending.alertable.title),
					message: Text(pending.alertable.message),
					dismissButton: .default(Text("OK"))
				)
			} else {
				Alert(
					title: Text(pending.alertable.title),
					message: Text(pending.alertable.message),
					primaryButton: .default(Text(pending.alertable.primaryButtonTitle)) {
						pending.action()
					},
					secondaryButton: .cancel()
				)
			}
		}
	}
}

// MARK: - Localization design notes

// TODO: Localization collapse
// `Alertable` currently exposes runtime `String` values. Passing those values to
// `Text` means they arrive here as already-resolved/verbatim presentation text;
// they do not have the same localization semantics as a source-code string
// literal passed directly to `Text`. Do not invent a PendingAlert-specific
// localization mechanism. When the shared SBJ text/localization representation
// is designed, `title`, `message`, and button titles should participate in it.
//
// This type is a useful test case for that future representation because alerts
// can contain several different kinds of text:
//   - app-owned/localizable vocabulary;
//   - vendor-overridden vocabulary;
//   - terminology/document-dependent vocabulary;
//   - formatted/interpolated values;
//   - server-provided or user-authored text that may need to remain verbatim.
// The eventual API must preserve which category a value belongs to instead of
// flattening everything to String before PendingAlert sees it.
//
// TODO: The empty `primaryButtonTitle` sentinel mixes presentation text with
// control flow. Once the text model is revisited, represent the primary action
// explicitly/optionally rather than using `""` to mean "no primary action".
// This matters for localization too: presence of an action is semantic state,
// not a property of a localized button label.
//
// TODO: `"OK"` is framework-owned localizable vocabulary. It is deliberately a
// SwiftUI string literal today, while `.cancel()` delegates its title to the
// system. Both should be accounted for when deciding how framework-owned copy
// participates in the shared localization/catalog design.
