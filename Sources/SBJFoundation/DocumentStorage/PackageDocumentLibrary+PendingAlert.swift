#if !os(watchOS)
import SwiftUI

private struct PackageDocumentInformationalAlert: Alertable {
    let title: String
    let message: String
    let primaryButtonTitle = ""
}

public extension View {
    /// Opts a view into the standard informational alerts emitted by a package
    /// document library. Apps that prefer custom presentation can omit this
    /// modifier and observe `library.notices` directly.
    func packageDocumentAlerts<Document: PackageDocument>(
        _ library: PackageDocumentLibrary<Document>
    ) -> some View {
        pendingAlert(Binding(
            get: {
                guard let notice = library.notices.first else { return nil }
                return PendingAlert(
                    PackageDocumentInformationalAlert(title: notice.title, message: notice.message),
                    id: notice.id,
                    dismissAction: { library.dismissNotice(id: notice.id) }
                )
            },
            set: { value in
                if value == nil, let notice = library.notices.first {
                    library.dismissNotice(id: notice.id)
                }
            }
        ))
    }
}
#endif
