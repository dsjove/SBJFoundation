#if !os(watchOS) && canImport(UIKit) && canImport(PDFKit)
import Foundation
import PDFKit
import UIKit
import SBJDataDefinition
import SBJLayout

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
        let body = content(catalog, title: title)
        return PDFGenerator(pageLayout: pageLayout, title: title,
                            creator: "SBJDataDefinitionReport")
            .form(body, chrome: PageChrome(footer: JCSPageNumber(font: .systemFont(ofSize: 8)), contentInsets: Insets(bottom: 8), footerGap: 5))
    }

    // The report is intentionally constructed from public SBJLayout renderables.
    // Each row remains an independent pagination unit, preserving section positions.
    private static func content(_ catalog: SBJDefinitionCatalog, title: String) -> Grid {
        var nodes: [Renderables.Node] = []
        let ink = UIColor(red: 0.12, green: 0.20, blue: 0.32, alpha: 1)
        let blue = UIColor(red: 0.15, green: 0.32, blue: 0.52, alpha: 1)
        let muted = UIColor(red: 0.39, green: 0.45, blue: 0.52, alpha: 1)

        // Property metadata is accumulated and rendered as ONE two-column table.
        // Rows share identical columns, instead of sizing labels independently.
        var insideProperty = false
        var firstPropertyRow = false
        var propertyMetadata: [(String, String)] = []
        func flushPropertyMetadata() {
            guard !propertyMetadata.isEmpty else { return }
            var cells: [Grid.Cell] = []
            for (label, value) in propertyMetadata {
                cells.append(JCSText(verbatim: label.uppercased(),
                                     font: .boldSystemFont(ofSize: 8), color: muted))
                cells.append(JCSText(verbatim: value, font: .systemFont(ofSize: 8.5),
                                     color: ink, lines: nil, lineBreakMode: .byWordWrapping))
            }
            let table = Grid(table: [.init(.intrinsic(), align: .leftTop, gap: 8),
                                     .init(.fill(1), align: .leftTop)],
                             rows: .init(align: .leftTop, gap: 2)) {
                Renderables(cells.map { .content($0) })
            }
            nodes.append(.group(PaginationGroup(behavior: .keepWith) { table }))
            propertyMetadata.removeAll()
        }
        func line(_ value: String, size: CGFloat = 9, bold: Bool = false,
                  color: UIColor? = nil, section: String? = nil) {
            if insideProperty { flushPropertyMetadata() }
            let item = JCSText(verbatim: value,
                               font: bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size),
                               color: color ?? ink, lines: nil, lineBreakMode: .byWordWrapping)
            if let section {
                nodes.append(.group(PaginationGroup(sectionID: section) { item }))
            } else {
                let behavior: PaginationBehavior = insideProperty && !firstPropertyRow ? .keepWith : .flow
                nodes.append(.group(PaginationGroup(behavior: behavior) { item }))
                if insideProperty { firstPropertyRow = false }
            }
        }
        func rule(color: UIColor) {
            if insideProperty { flushPropertyMetadata() }
            nodes.append(.group(PaginationGroup(behavior: .keepWith) {
                DefinitionReportRule(stroke: color)
            }))
        }
        func metadata(_ label: String, _ value: String?, keepWithPrevious: Bool = false) {
            guard let value, !value.isEmpty else { return }
            if insideProperty {
                propertyMetadata.append((label, value))
                return
            }
            let row = Grid(table: [.init(.intrinsic(), align: .leftTop, gap: 8),
                                   .init(.fill(1), align: .leftTop)],
                           rows: .init(align: .leftTop, gap: 0)) {
                JCSText(verbatim: label.uppercased(), font: .boldSystemFont(ofSize: 8), color: muted)
                JCSText(verbatim: value, font: .systemFont(ofSize: 8.5), color: ink,
                        lines: nil, lineBreakMode: .byWordWrapping)
            }
            nodes.append(.group(PaginationGroup(behavior: keepWithPrevious ? .keepWith : .flow) { row }))
        }
        func readable(_ identifier: String) -> String {
            let characters = Array(identifier.replacingOccurrences(of: "_", with: " "))
            var output = ""
            for index in characters.indices {
                let c = characters[index]
                if index > 0 && c.isUppercase && (characters[index-1].isLowercase || characters[index-1].isNumber) {
                    output.append(" ")
                }
                output.append(c)
            }
            return output
        }
        func declarationIfDifferent(_ declaration: String, from title: String) -> Bool {
            guard declaration != title else { return false }
            metadata("Declaration", declaration, keepWithPrevious: true)
            return true
        }
        let structureCount = catalog.types.filter {
            if case .structure = $0.content { return true }; return false
        }.count
        let propertyCount = catalog.types.reduce(0) { count, definition in
            if case .structure(let fields) = definition.content { return count + fields.count }
            return count
        }
        let enumCount = catalog.types.count - structureCount
        let caseCount = catalog.types.reduce(0) { count, definition in
            if case .enumeration(let values) = definition.content { return count + values.count }
            return count
        }
        line("DATA DEFINITION / SCHEMA REFERENCE", size: 9, bold: true, color: blue)
        line(title, size: 22, bold: true)
        line("Compiled declaration metadata · No model instances or runtime values", size: 9, color: muted)
        line("\(catalog.types.count) TYPES     \(structureCount) STRUCTURES     \(enumCount) ENUMERATIONS     \(propertyCount) PROPERTIES     \(caseCount) CASES", size: 9, bold: true, color: blue)
        let constraintCount = catalog.types.reduce(0) { sum, definition in
            if case .structure(let fields) = definition.content {
                return sum + fields.reduce(0) { $0 + $1.constraints.count }
            }
            return sum
        }
        let presentationCount = catalog.types.reduce(0) { sum, definition in
            if case .structure(let fields) = definition.content {
                return sum + fields.reduce(0) { $0 + $1.hints.count }
            }
            return sum
        }
        let documentedCount = catalog.types.reduce(0) { sum, definition in
            switch definition.content {
            case .structure(let fields):
                return sum + fields.filter { $0.info != nil }.count
            case .enumeration(let cases):
                return sum + cases.filter { $0.info != nil }.count
            }
        }
        line("ANNOTATIONS  /  \(constraintCount) validation rules  ·  \(presentationCount) presentation hints  ·  \(documentedCount) documented declarations", size: 9, color: muted)
        rule(color: blue)
        // Concrete generic instantiations remain independent catalog entries.
        // Only merge report sections when every field/case has the same metadata;
        // specialized declaration types are listed individually below.
        func familyName(_ definition: SBJDefinitionType) -> String? {
            guard let bracket = definition.swiftName.firstIndex(of: "<") else { return nil }
            return String(definition.swiftName[..<bracket])
        }
        func signature(_ definition: SBJDefinitionType) -> [String] {
            switch definition.content {
            case .structure(let fields):
                return ["struct"] + fields.map { field in
                    [field.swiftIdentifier, field.displayName, field.title ?? "",
                     field.info?.summary ?? "", field.info?.details ?? "",
                     String(describing: field.info?.symbol),
                     String(describing: field.info?.accessibilityLabel),
                     String(describing: field.info?.accessibilityHint),
                     String(describing: field.kind),
                     field.constraints.map(\.description).joined(separator: "|"),
                     field.hints.map(\.description).joined(separator: "|")].joined(separator: "\u{1f}")
                }
            case .enumeration(let cases):
                return ["enum"] + cases.map { item in
                    [item.swiftIdentifier, item.title ?? "", item.info?.summary ?? "",
                     item.info?.details ?? "", String(describing: item.info?.symbol),
                     item.payloads.map { "\($0.name):\($0.typeName)" }.joined(separator: "|"),
                     item.rawValueDescription ?? ""].joined(separator: "\u{1f}")
                }
            }
        }
        var sections: [[SBJDefinitionType]] = []
        for definition in catalog.types {
            if let family = familyName(definition),
               let section = sections.indices.first(where: {
                   guard let first = sections[$0].first else { return false }
                   return family == familyName(first) && signature(first) == signature(definition)
               }) {
                sections[section].append(definition)
            } else {
                sections.append([definition])
            }
        }
        for (index, variants) in sections.enumerated() {
            guard let definition = variants.first else { continue }
            line(" ", size: 4)
            // Do not split on periods inside generic arguments (e.g. Module.UnitValue<Module.LengthUnit>).
            let displayed = SBJDefinitionTypeDisplay.format(definition.swiftName)
            let base = String(displayed.prefix(while: { $0 != "<" }))
            let shortName = base.split(separator: ".").last.map(String.init) ?? base
            line(String(format: "%02d  %@", index + 1, readable(shortName)), size: 16, bold: true,
                 color: blue, section: "type-\(index)")
            switch definition.content {
            case .structure(let properties):
                if variants.count > 1 {
                    metadata("Specializations", variants.map { SBJDefinitionTypeDisplay.format($0.swiftName) }.joined(separator: "\n"), keepWithPrevious: true)
                } else {
                    metadata("Declaration", "struct \(SBJDefinitionTypeDisplay.format(definition.swiftName)) { \(properties.count) properties }", keepWithPrevious: true)
                }
                rule(color: muted)
                for (number, field) in properties.enumerated() {
                    insideProperty = true
                    firstPropertyRow = true
                    let title = field.title ?? field.displayName
                    line("\(number + 1).  \(title)", size: 11, bold: true, color: ink)
                    let corresponding = variants.compactMap { variant -> SBJDefinitionProperty? in
                        if case .structure(let fields) = variant.content, number < fields.count { return fields[number] }
                        return nil
                    }
                    let declarations = corresponding.map { "\(field.swiftIdentifier): \(SBJDefinitionTypeDisplay.format($0.typeName))" }
                    let distinctDeclarations = Array(Set(declarations))
                    let hasDeclaration: Bool
                    if distinctDeclarations.count == 1 {
                        hasDeclaration = declarationIfDifferent(declarations[0], from: title)
                    } else {
                        for (variant, property) in zip(variants, corresponding) {
                            metadata("Declaration", "\(SBJDefinitionTypeDisplay.format(variant.swiftName)): \(property.swiftIdentifier): \(SBJDefinitionTypeDisplay.format(property.typeName))")
                        }
                        hasDeclaration = true
                    }
                    if let summary = field.info?.summary {
                        metadata("Summary", summary, keepWithPrevious: !hasDeclaration)
                    }
                    if let details = field.info?.details {
                        metadata("Description", details, keepWithPrevious: !hasDeclaration && field.info?.summary == nil)
                    }
                    if let symbol = field.info?.symbol { metadata("Symbol", String(describing: symbol)) }
                    if !field.constraints.isEmpty {
                        for constraint in field.constraints { metadata("Validation", constraint.description) }
                    }
                    if !field.hints.isEmpty {
                        for value in field.hints { metadata("Presentation", value.description) }
                    }
                    flushPropertyMetadata()
                    insideProperty = false
                }
            case .enumeration(let cases):
                if variants.count > 1 {
                    metadata("Specializations", variants.map { SBJDefinitionTypeDisplay.format($0.swiftName) }.joined(separator: "\n"), keepWithPrevious: true)
                } else {
                    metadata("Declaration", "enum \(SBJDefinitionTypeDisplay.format(definition.swiftName)) { \(cases.count) cases }", keepWithPrevious: true)
                }
                rule(color: muted)
                for (number, value) in cases.enumerated() {
                    insideProperty = true
                    firstPropertyRow = true
                    line("\(number + 1).  \(value.title ?? readable(value.swiftIdentifier))", size: 11, bold: true)
                    let hasDeclaration = declarationIfDifferent(value.swiftIdentifier, from: value.title ?? readable(value.swiftIdentifier))
                    metadata("Raw value", value.rawValueDescription, keepWithPrevious: !hasDeclaration)
                    if let summary = value.info?.summary {
                        metadata("Summary", summary, keepWithPrevious: !hasDeclaration && (value.rawValueDescription?.isEmpty ?? true))
                    }
                    if let details = value.info?.details { metadata("Description", details) }
                    if let symbol = value.info?.symbol { metadata("Symbol", String(describing: symbol)) }
                    if !value.payloads.isEmpty {
                        for payload in value.payloads {
                            metadata("Associated value", "\(payload.name): \(SBJDefinitionTypeDisplay.format(payload.typeName))")
                        }
                    }
                    flushPropertyMetadata()
                    insideProperty = false
                }
            }
        }
        return Grid(vertFlow: .init(.fill(1), align: .leftTop),
                    rows: .init(gap: 3)) { Renderables(nodes) }
    }

}

/// Measured horizontal rule. JCSLine is a drawing primitive, not a renderable.
private struct DefinitionReportRule: Renderable {
    let stroke: UIColor
    func measure(bounds: CGSize) -> CGSize { CGSize(width: bounds.width, height: 1) }
    func render(in allocated: CGRect, measured: CGSize, align: SBJLayout.Alignment) {
        let y = allocated.midY
        JCSLine(stroke: stroke, lineWidth: 0.5).draw(
            from: CGPoint(x: allocated.minX, y: y),
            to: CGPoint(x: allocated.maxX, y: y))
    }
}
#endif
