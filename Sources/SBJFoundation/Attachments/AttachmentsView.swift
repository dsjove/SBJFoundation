#if !os(watchOS)
import Foundation
import Observation
import SwiftUI
import UniformTypeIdentifiers
import SBJDataDefinition
import SBJFileResources
import SBJUIVocabulary
import SBJSharing

public extension SBJBundledContentReference {
    static var attachmentsHelp: SBJBundledContentReference {
        .help("Attachments", bundle: .module)
    }
}

/// Standard editor for a collection of named attachments.
///
/// Use the binding initializer when attachments are staged by a containing
/// editor. `init(owner:)` remains available for models that edit their owner
/// directly.
@MainActor
public struct AttachmentsView<Attachment: Attaching>: View {
    @Environment(\.dismiss) private var dismiss

    @Binding private var attachments: [Attachment]
    private let createAttachment: (URL) throws -> Attachment
    private let attachmentPreview: (Attachment) throws -> URLAttachment
    private let validateAttachmentURL: (URL) throws -> Void
    private let removeAttachment: ((Attachment) -> Void)?
    private let hasDoneButton: Bool

    @State private var preview: URLAttachment?
    @State private var isImporterPresented = false
    @State private var importerError: String?
    @State private var pendingRemovalIDs: [Attachment.ID] = []
    @State private var pendingRemovalNames: [String] = []

    private var sortedAttachmentIDs: [Attachment.ID] {
        attachments.enumerated()
            .sorted { lhs, rhs in
                let comparison = lhs.element.displayName.localizedCaseInsensitiveCompare(rhs.element.displayName)
                return comparison == .orderedSame
                    ? lhs.offset < rhs.offset
                    : comparison == .orderedAscending
            }
            .map { $0.element.id }
    }

    public init(
        attachments: Binding<[Attachment]>,
        createAttachment: @escaping (URL) throws -> Attachment,
        attachmentPreview: @escaping (Attachment) throws -> URLAttachment,
        validateAttachmentURL: @escaping (URL) throws -> Void = { _ in },
        removeAttachment: ((Attachment) -> Void)? = nil,
        hasDoneButton: Bool = true
    ) {
        self._attachments = attachments
        self.createAttachment = createAttachment
        self.attachmentPreview = attachmentPreview
        self.validateAttachmentURL = validateAttachmentURL
        self.removeAttachment = removeAttachment
        self.hasDoneButton = hasDoneButton
    }

    /// Convenience for attachments whose preview is already represented by a URL.
    public init(
        attachments: Binding<[Attachment]>,
        createAttachment: @escaping (URL) throws -> Attachment,
        attachmentURL: @escaping (Attachment) throws -> URL,
        validateAttachmentURL: @escaping (URL) throws -> Void = { _ in },
        removeAttachment: ((Attachment) -> Void)? = nil,
        hasDoneButton: Bool = true
    ) {
        self.init(
            attachments: attachments,
            createAttachment: createAttachment,
            attachmentPreview: { attachment in
                URLAttachment(
                    url: try attachmentURL(attachment),
                    displayName: attachment.displayName
                )
            },
            validateAttachmentURL: validateAttachmentURL,
            removeAttachment: removeAttachment,
            hasDoneButton: hasDoneButton
        )
    }

    public init<Owner: AttachmentOwner & Observable>(
        owner: Owner,
        hasDoneButton: Bool = true
    ) where Owner.Attachment == Attachment {
        self.init(
            attachments: Binding(
                get: { owner.__attachments ?? [] },
                set: { owner.__attachments = $0 }
            ),
            createAttachment: owner.__createAttachment,
            attachmentPreview: { attachment in
                URLAttachment(
                    url: try owner.__attachmentURL(attachment),
                    displayName: attachment.displayName
                )
            },
            removeAttachment: owner.__removeAttachment,
            hasDoneButton: hasDoneButton
        )
    }

    public var body: some View {
        Group {
        if attachments.isEmpty {
            ContentUnavailableView {
                    Label {
                        Text("No Attachments")
                    } icon: {
                        Image(symbol: SBJAttachmentSymbology.attachments)
                    }
                } description: {
                    Text("Select Add Attachment to add a file.")
            }
        } else {
        List {
            ForEach(sortedAttachmentIDs, id: \.self) { id in
                if let attachment = attachments.first(where: { $0.id == id }) {
                    HStack {
                        TextField(
                            "Name",
                            text: editableNameBinding(for: id)
                        )
                        .oneLiner()
                        .applyIf(Attachment.propertyInfo(for: \Attachment.name)?.accessibilityLabel) { view, label in
                            view.accessibilityLabel(label)
                        }
                        .applyIf(Attachment.propertyInfo(for: \Attachment.name)?.accessibilityHint) { view, hint in
                            view.accessibilityHint(hint)
                        }

                        if let ext = filenameExtension(attachment.name) {
                            Text(".\(ext)")
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        SBJRemoveButton(
                            accessibilityLabel: "Remove \(attachment.displayName)"
                        ) {
                            requestRemoval(ids: [id])
                        }

#if canImport(QuickLook) && canImport(UIKit) && !os(visionOS)
                        SBJSymbolButton(
                            SBJAttachmentSymbology.previewAttachment,
                            accessibilityLabel: "Preview \(attachment.displayName)"
                        ) {
                            openAttachment(attachment)
                        }
#endif
                    }
                }
            }
            .onDelete(perform: deleteAttachments)
        }
        }
        }
#if !os(tvOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .navigationTitle("Attachments")
        .toolbar {
            if hasDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }

            ToolbarItemGroup(placement: .primaryAction) {
                SBJAddButton("Attachment") {
                    isImporterPresented = true
                }
            }
        }
#if !os(tvOS)
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true,
            onCompletion: handleImportResult
        )
#endif
        .alert("Error", isPresented: importerErrorPresented) {
            Button("OK") { importerError = nil }
        } message: {
            Text(importerError ?? "")
        }
        .alert(removalAlertTitle, isPresented: removalAlertPresented) {
            Button("Remove", role: .destructive) { confirmRemoval() }
            Button("Cancel", role: .cancel) { clearPendingRemoval() }
        } message: {
            Text(removalAlertMessage)
        }
#if canImport(QuickLook) && canImport(UIKit) && !os(visionOS)
        .fullScreenCover(item: $preview) { item in
            DocumentPreviewSheet(url: item.url, displayName: item.displayName)
        }
#endif
    }

    private var importerErrorPresented: Binding<Bool> {
        Binding(
            get: { importerError != nil },
            set: { if !$0 { importerError = nil } }
        )
    }

    private func editableNameBinding(for id: Attachment.ID) -> Binding<String> {
        Binding(
            get: {
                guard let attachment = attachments.first(where: { $0.id == id }) else {
                    return ""
                }
                return editableName(attachment.name)
            },
            set: { proposedName in
                setEditableName(proposedName, for: id)
            }
        )
    }

    private func editableName(_ filename: String) -> String {
        let url = URL(fileURLWithPath: filename)
        return url.pathExtension.isEmpty
            ? filename
            : url.deletingPathExtension().lastPathComponent
    }

    private func filenameExtension(_ filename: String) -> String? {
        let ext = URL(fileURLWithPath: filename).pathExtension
        return ext.isEmpty ? nil : ext
    }

    private func setEditableName(_ proposedName: String, for id: Attachment.ID) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }

        let currentName = attachments[index].name
        let ext = filenameExtension(currentName)
        let sanitizedStem = proposedName.sanitizedFilename()
        let fallbackStem = editableName(currentName)
        let stem = sanitizedStem.isEmpty ? fallbackStem : sanitizedStem
        let proposedFilename = ext.map { "\(stem).\($0)" } ?? stem
        let existingNames = attachments.enumerated().compactMap { offset, attachment in
            offset == index ? nil : attachment.name
        }

        attachments[index].name = proposedFilename.uniqueFilename(existingNames: existingNames)
    }

    // MARK: - Import

    private func handleImportResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                importAttachment(at: url)
            }
        case .failure(let error):
            importerError = error.localizedDescription
        }
    }

    private func importAttachment(at url: URL) {
        do {
            try url.withSecurityScopedAccess { scopedURL in
                try validateAttachmentURL(scopedURL)
                var attachment = try createAttachment(scopedURL)
                attachment.name = attachment.name.uniqueFilename(existingNames: attachments.map(\.name))
                attachments.append(attachment)
            }
        } catch {
            importerError = error.localizedDescription
        }
    }

    // MARK: - Preview

    private func openAttachment(_ attachment: Attachment) {
        do {
            preview = try attachmentPreview(attachment)
        } catch {
            importerError = error.localizedDescription
        }
    }

    // MARK: - Delete

    private var removalAlertPresented: Binding<Bool> {
        Binding(
            get: { !pendingRemovalIDs.isEmpty },
            set: { if !$0 { clearPendingRemoval() } }
        )
    }

    private var removalAlertTitle: String {
        pendingRemovalIDs.count == 1 ? "Remove Attachment?" : "Remove Attachments?"
    }

    private var removalAlertMessage: String {
        if pendingRemovalNames.count == 1, let name = pendingRemovalNames.first {
            return "Remove \"\(name)\"?"
        }
        return "Remove \(pendingRemovalIDs.count) attachments?"
    }

    private func requestRemoval(ids: [Attachment.ID]) {
        pendingRemovalIDs = ids
        pendingRemovalNames = attachments
            .filter { ids.contains($0.id) }
            .map(\.displayName)
    }

    private func confirmRemoval() {
        let ids = pendingRemovalIDs
        clearPendingRemoval()
        let removed = attachments.filter { ids.contains($0.id) }
        attachments.removeAll { ids.contains($0.id) }
        removed.forEach { removeAttachment?($0) }
    }

    private func clearPendingRemoval() {
        pendingRemovalIDs = []
        pendingRemovalNames = []
    }

    private func deleteAttachments(at offsets: IndexSet) {
        requestRemoval(ids: offsets.map { sortedAttachmentIDs[$0] })
    }
}
#endif
