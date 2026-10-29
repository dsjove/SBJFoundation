#if DEBUG && os(iOS)
import Foundation
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

/// Source-only integration fixture. Embed this SwiftUI view in any client or a
/// SwiftUI #Preview; SBJLayout does not contain an application target.
@MainActor
public struct LayoutPDFPreview: View {
    public enum Sample: String, CaseIterable, Identifiable {
        case rental = "Rental Application"
        case components = "JCS Constructs"
        case diagnostics = "Diagnostics"

        public var id: Self { self }
    }

    @State private var sample: Sample = .rental
    @State private var presentation = PDFPresentationController<String>()
    @State private var exportedFile: URL?
    @State private var showShare = false
    @State private var exportError: String?

    private let logo: UIImage?

    /// Inject the fixture image; the preview makes no assumptions about app assets.
    public init(logo: UIImage? = nil) {
        self.logo = logo ?? UIImage(named: "SBJLayoutPreviewLogo", in: .module, compatibleWith: nil)
    }

    public var body: some View {
        PDFPresentationView(presentation: presentation)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("SBJLayout PDF Preview")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("Document", selection: $sample) {
                        ForEach(Sample.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.menu)
                }
                ToolbarItem(placement: .topBarLeading) {
                    PDFPageControlView(controller: presentation.continuousController)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        shareCurrentDocument()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share PDF")
                    .disabled(presentation.displayedDocument == nil)
                }
            }
            .onAppear(perform: regenerate)
            .onChange(of: sample) { _, _ in regenerate() }
            .sheet(isPresented: $showShare, onDismiss: clearExport) {
                if let exportedFile {
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("Share the PDF including current form entries")
                            ShareLink(item: exportedFile, preview: SharePreview(exportedFile.lastPathComponent)) {
                                Label("Share PDF", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .navigationTitle("Export PDF")
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { showShare = false }
                            }
                        }
                    }
                }
            }
            .alert("PDF Export Failed", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK") { exportError = nil }
            } message: {
                Text(exportError ?? "Unable to export PDF")
            }
    }

    private func regenerate() {
        let result: PDFRenderResult
        switch sample {
        case .rental:
            result = RentalApplicationExample.create(logo: logo)
        case .components:
            result = JCSComponentPreview.create(logo: logo)
        case .diagnostics:
            result = JCSComponentPreview.create(logo: logo, showBounds: true)
        }
        presentation.update(.init(content: .init(
            document: result.document,
            positions: result.positions
        )))
        if let document = result.document {
            let report = LayoutPDFPreviewAudit.inspect(document, expectedPages: sample == .rental ? 2 : nil)
            print("SBJLayout PDF preview: \(sample.rawValue), pages=\(report.pages), text=\(report.textFields), checkbox=\(report.checkboxes), radio=\(report.radioWidgets), allowsFormFieldEntry=\(document.allowsFormFieldEntry)")
            report.warnings.forEach { print("SBJLayout PDF warning: \($0)") }
        }
    }

    /// Serialize the currently presented document at the moment of export,
    /// so user-entered values are included rather than just the initial fixture.
    private func shareCurrentDocument() {
        guard let document = presentation.displayedDocument,
              let data = document.dataRepresentation()
        else {
            exportError = "There is no PDF document to export."
            return
        }
        let filename: String
        switch sample {
        case .rental: filename = "PropertiesByJove-RentalApplication.pdf"
        case .components: filename = "SBJLayout-JCS-Preview.pdf"
        case .diagnostics: filename = "SBJLayout-JCS-Diagnostics.pdf"
        }
        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(filename)
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
            exportedFile = destination
            showShare = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func clearExport() {
        // File stays available until the OS share operation has finished reading it.
        exportedFile = nil
    }
}

/// Structural audit used by both sample modes and the Xcode console.
public enum LayoutPDFPreviewAudit {
    public struct Result {
        public let pages: Int
        public let textFields: Int
        public let checkboxes: Int
        public let radioWidgets: Int
        public let fieldNames: [String]
        public let warnings: [String]
    }

    public static func inspect(_ document: PDFDocument, expectedPages: Int? = nil) -> Result {
        let widgets = (0..<document.pageCount).flatMap { index in
            document.page(at: index)?.annotations.filter {
                $0.widgetFieldType == .text || $0.widgetFieldType == .button || $0.widgetFieldType == .choice
            } ?? []
        }
        var warnings: [String] = []
        if let expectedPages, document.pageCount != expectedPages {
            warnings.append("Expected \(expectedPages) pages; got \(document.pageCount)")
        }
        for index in 0..<document.pageCount {
            guard let page = document.page(at: index) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            for widget in page.annotations where widget.widgetFieldType == .text || widget.widgetFieldType == .button || widget.widgetFieldType == .choice {
                if widget.isReadOnly { warnings.append("Page \(index + 1): read-only field \(widget.fieldName ?? "<unnamed>")") }
                if widget.fieldName == nil { warnings.append("Page \(index + 1): unnamed widget") }
                if !bounds.contains(widget.bounds) {
                    warnings.append("Page \(index + 1): widget outside page: \(widget.fieldName ?? "<unnamed>")")
                }
            }
        }
        for (name, group) in Dictionary(grouping: widgets, by: { $0.fieldName ?? "" }) where group.count > 1 {
            if !group.allSatisfy({ $0.widgetControlType == .radioButtonControl }) {
                warnings.append("Duplicate non-radio field: \(name)")
            }
        }
        return Result(pages: document.pageCount,
                      textFields: widgets.filter { $0.widgetFieldType == .text }.count,
                      checkboxes: widgets.filter { $0.widgetControlType == .checkBoxControl }.count,
                      radioWidgets: widgets.filter { $0.widgetControlType == .radioButtonControl }.count,
                      fieldNames: widgets.compactMap(\.fieldName).sorted(),
                      warnings: warnings)
    }
}
#endif

#if DEBUG && os(iOS)
#Preview("SBJLayout PDF Forms") {
    NavigationStack {
        LayoutPDFPreview()
    }
}
#endif
