#if !os(watchOS) && canImport(UIKit) && canImport(PDFKit)
import Foundation
import UIKit
import PDFKit
import SBJLayout
import SBJDataDefinition

/// Generates paginated reports using SBJLayout's native PDF renderer.
/// No model values or SwiftUI view hierarchy are constructed to create the PDF.
@MainActor
public enum SBJDefinitionPDFReport {
    public static func makePDF(
        catalog: SBJDefinitionCatalog,
        pageLayout: PageLayout = .init(),
        title: String = "Data Definitions"
    ) -> Data {
        makePDFResult(catalog: catalog, pageLayout: pageLayout, title: title).data
    }

    public static func makePDFResult(
        catalog: SBJDefinitionCatalog,
        pageLayout: PageLayout = .init(),
        title: String = "Data Definitions"
    ) -> PDFRenderResult {
        let body = content(catalog)
        return PDFGenerator(pageLayout: pageLayout, title: title,
                            creator: "SBJDataDefinitionReport")
            .form(body)
    }

    private static func content(_ catalog: SBJDefinitionCatalog) -> Grid {
        var nodes: [Renderables.Node] = []
        func add(_ text: String, font: UIFont, color: UIColor = .label,
                 section: String? = nil) {
            // Each record is an individual pagination unit; a long definition
            // can continue on the next page without duplicating its parent type.
            let item = JCSText(verbatim: text, font: font, color: color,
                               lines: nil, lineBreakMode: .byWordWrapping)
            if let section {
                nodes.append(.group(PaginationGroup(sectionID: section) { item }))
            } else {
                nodes.append(.content(item))
            }
        }
        add("Data Definition Report", font: .boldSystemFont(ofSize: 19))
        add("\(catalog.types.count) registered definitions", font: .systemFont(ofSize: 10), color: .darkGray)
        for (index, definition) in catalog.types.enumerated() {
            add(" ", font: .systemFont(ofSize: 9))
            add(definition.swiftName, font: .boldSystemFont(ofSize: 15),
                section: "type-\(index)")
            switch definition.content {
            case .structure(let properties):
                add("STRUCTURE · \(properties.count) properties", font: .systemFont(ofSize: 9), color: .darkGray)
                for field in properties {
                    let label = field.title.map { "\($0) (\(field.swiftIdentifier))" } ?? field.swiftIdentifier
                    add("\(label): \(field.typeName)", font: .boldSystemFont(ofSize: 10))
                    let details = ["Kind: \(field.kind)",
                                   field.isStored ? "Stored" : "Presentation-only"]
                    add(details.joined(separator: " · "), font: .systemFont(ofSize: 9))
                    if !field.constraints.isEmpty {
                        add("Constraints: \(field.constraints.map { String(describing: $0) }.joined(separator: ", "))",
                            font: .systemFont(ofSize: 9))
                    }
                    if !field.hints.isEmpty {
                        add("Presentation: \(field.hints.map { String(describing: $0) }.joined(separator: ", "))",
                            font: .systemFont(ofSize: 9))
                    }
                }
            case .enumeration(let cases):
                add("ENUMERATION · \(cases.count) cases", font: .systemFont(ofSize: 9), color: .darkGray)
                for value in cases {
                    let label = value.title.map { "\($0) (\(value.swiftIdentifier))" } ?? value.swiftIdentifier
                    add(label + (value.rawValueDescription.map { " = " + $0 } ?? ""),
                        font: .boldSystemFont(ofSize: 10))
                    for payload in value.payloads {
                        add("    \(payload.name): \(payload.typeName)", font: .systemFont(ofSize: 9))
                    }
                }
            }
        }
        return Grid(vertFlow: .init(.fill(1), align: .leftTop),
                    rows: .init(gap: 5)) { Renderables(nodes) }
    }
}

#endif
