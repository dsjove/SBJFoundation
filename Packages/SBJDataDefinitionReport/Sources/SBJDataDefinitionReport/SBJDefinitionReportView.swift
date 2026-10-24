#if !os(watchOS) && canImport(UIKit) && canImport(PDFKit)
import Foundation
import SwiftUI
import PDFKit
import SBJLayout
import SBJDataDefinition

/// Hosts the Layout PDF viewer. No report content is composed in SwiftUI.
@MainActor
public struct SBJDefinitionReportView: View {
    public let catalog: SBJDefinitionCatalog
    public let pageLayout: PageLayout

    @State private var presentation = PDFPresentationController<String>()
    @State private var exportURL: URL?

    public init(catalog: SBJDefinitionCatalog, pageLayout: PageLayout = .init()) {
        self.catalog = catalog
        self.pageLayout = pageLayout
    }

    public var body: some View {
        PDFPresentationView(presentation: presentation)
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    PDFPageControlView(controller: presentation.continuousController)
                    if let exportURL {
                        ShareLink(item: exportURL, preview: SharePreview("Data Definition Report")) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share PDF report")
                    }
                }
            }
            .task {
                let result = SBJDefinitionPDFReport.makePDFResult(
                    catalog: catalog, pageLayout: pageLayout)
                presentation.update(PDFPresentationUpdate(
                    content: .init(document: result.document, positions: result.positions)))
                exportURL = Self.exportFile(for: result.data)
            }
    }

    /// ShareLink needs a file URL so receiving apps see a PDF, not opaque bytes.
    private static func exportFile(for data: Data) -> URL? {
        guard !data.isEmpty else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("SBJDefinitionReport-\(UUID().uuidString)")
            .appendingPathExtension("pdf")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

public typealias SBJDefinitionPDFReportView = SBJDefinitionReportView

#if DEBUG
#Preview("Recipe Data Definition PDF") {
    NavigationStack {
        SBJDefinitionReportView(
            catalog: SBJDefinitionCatalog(SBJStructureSampleModel.self))
    }
}
#endif
#endif
