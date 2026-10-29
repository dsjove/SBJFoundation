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
    public let title: String

    @State private var presentation = PDFPresentationController<String>(layout: .verticalSinglePage)
    @State private var exportURL: URL?
    @State private var typeSort: SBJDefinitionSort
    @State private var propertySort: SBJDefinitionSort
    @State private var caseSort: SBJDefinitionSort

    public init(catalog: SBJDefinitionCatalog, pageLayout: PageLayout = .init(), title: String = "Data Definitions") {
        self.title = title
        self.catalog = catalog
        self.pageLayout = pageLayout
        _typeSort = State(initialValue: catalog.options.typeSort)
        _propertySort = State(initialValue: catalog.options.propertySort)
        _caseSort = State(initialValue: catalog.options.caseSort)
    }

    public var body: some View {
        PDFPresentationView(presentation: presentation)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PDFPageControlView(controller: presentation.continuousController)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Types", selection: $typeSort) {
                            Text("Alphabetical").tag(SBJDefinitionSort.alphabetical)
                            Text("Declaration order").tag(SBJDefinitionSort.declaration)
                        }
                        Picker("Properties", selection: $propertySort) {
                            Text("Alphabetical").tag(SBJDefinitionSort.alphabetical)
                            Text("Declaration order").tag(SBJDefinitionSort.declaration)
                        }
                        Picker("Enum cases", selection: $caseSort) {
                            Text("Alphabetical").tag(SBJDefinitionSort.alphabetical)
                            Text("Declaration order").tag(SBJDefinitionSort.declaration)
                        }
                    } label: {
                        Label("Sort report", systemImage: "arrow.up.arrow.down")
                    }
                    if let exportURL {
                        ShareLink(item: exportURL, preview: SharePreview(title)) {
                            Label("Share PDF", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityLabel("Share PDF report")
                    }
                }
            }
            .task(id: sortOptions) {
                let result = SBJDefinitionPDFReport.makePDFResult(
                    catalog: catalog.sorted(using: sortOptions), pageLayout: pageLayout, title: title)
                presentation.update(PDFPresentationUpdate(
                    content: .init(document: result.document, positions: result.positions)))
                exportURL = Self.exportFile(for: result.data)
            }
    }

    private var sortOptions: SBJDefinitionCatalogOptions {
        SBJDefinitionCatalogOptions(typeSort: typeSort, propertySort: propertySort, caseSort: caseSort)
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
