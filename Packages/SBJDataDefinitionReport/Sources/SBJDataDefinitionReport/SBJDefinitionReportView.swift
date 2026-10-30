#if !os(watchOS) && canImport(UIKit) && canImport(PDFKit)
import Foundation
import SwiftUI
import PDFKit
import SBJLayout
import SBJDataDefinition
import SBJSharing
import SBJLocalization
import SBJUIVocabulary

/// Hosts the Layout PDF viewer. No report content is composed in SwiftUI.
@MainActor
public struct SBJDefinitionReportView: View {
    public let catalog: SBJDefinitionCatalog
    @AppStorage("SBJDataDefinitionReport.pageLayout") private var storedPageLayout = ""
    @State private var isPageLayoutPresented = false
    public let title: String

    @State private var presentation = PDFPresentationController<String>(layout: .verticalSinglePage)
    @State private var pageLayout: PageLayout
    @State private var exportURL: URL?
    @State private var typeSort: SBJDefinitionSort
    @State private var propertySort: SBJDefinitionSort
    @State private var caseSort: SBJDefinitionSort

    public init(catalog: SBJDefinitionCatalog, pageLayout: PageLayout = .init(), title: String = "Data Definitions") {
        self.title = title
        self.catalog = catalog
        let saved = UserDefaults.standard.string(forKey: "SBJDataDefinitionReport.pageLayout")
        let restored = saved.flatMap { $0.data(using: .utf8) }
            .flatMap { try? JSONDecoder().decode(PageLayout.self, from: $0) }
        _pageLayout = State(initialValue: restored ?? pageLayout)
        _typeSort = State(initialValue: catalog.options.typeSort)
        _propertySort = State(initialValue: catalog.options.propertySort)
        _caseSort = State(initialValue: catalog.options.caseSort)
    }

    public var body: some View {
        SBJSharePresentationHost { sharePresenter in
        PDFPresentationView(presentation: presentation)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    PDFPageControlView(controller: presentation.continuousController)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    SBJSymbolButton(
                        SBJLayoutSymbology.pageLayoutLabel
                    ) {
                        isPageLayoutPresented = true
                    }
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
                        Label(SBJDataDefinitionReportSymbology.sortReportLabel)
                    }
                    if let exportURL {
                        SBJShareButton("Share PDF", presenter: sharePresenter, prepare: {
                            SBJSharePayload(exportURL)
                        })
                        .accessibilityLabel("Share PDF report")
                    }
                }
            }
            .sheet(isPresented: $isPageLayoutPresented) {
                PageLayoutEditorView(
                    pageLayout: pageLayout,
                ) { pageLayout = $0 }
            }
            .onChange(of: pageLayout) { _, updated in
                if let data = try? JSONEncoder().encode(updated),
                   let value = String(data: data, encoding: .utf8) {
                    storedPageLayout = value
                }
            }
            .task(id: renderKey) {
                let result = SBJDefinitionPDFReport.makePDFResult(
                    catalog: catalog.sorted(using: sortOptions), pageLayout: pageLayout, title: title)
                presentation.update(PDFPresentationUpdate(
                    content: .init(document: result.document, positions: result.positions)))
                exportURL = Self.exportFile(for: result.data)
            }
        }
    }

    /// A stable task identity. Do not use JSON text here: JSONEncoder does not
    /// guarantee key ordering, so equivalent layouts can have different strings
    /// across SwiftUI body evaluations and repeatedly restart PDF generation.
    private struct RenderKey: Equatable {
        let typeSort: SBJDefinitionSort
        let propertySort: SBJDefinitionSort
        let caseSort: SBJDefinitionSort
        let pageLayout: PageLayout
    }

    private var renderKey: RenderKey {
        RenderKey(typeSort: typeSort,
                  propertySort: propertySort,
                  caseSort: caseSort,
                  pageLayout: pageLayout)
    }

    private var sortOptions: SBJDefinitionCatalogOptions {
        SBJDefinitionCatalogOptions(typeSort: typeSort, propertySort: propertySort, caseSort: caseSort)
    }

    /// Sharing needs a file URL so receiving apps see a PDF, not opaque bytes.
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
