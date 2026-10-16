import Foundation

public extension Data {
    var sbjHexDescription: String {
        sbjHexFormat(bytesPerRow: 16)
    }

    /// Formats bytes as uppercase, space-separated hexadecimal suitable for editing.
    func sbjHexFormat(bytesPerRow: Int = 16, indent: String = "") -> String {
        guard !isEmpty else { return "" }
        let rowSize = Swift.max(1, bytesPerRow)
        var rows: [String] = []
        rows.reserveCapacity((count + rowSize - 1) / rowSize)
        for rowStart in stride(from: 0, to: count, by: rowSize) {
            let rowEnd = Swift.min(rowStart + rowSize, count)
            let row = self[rowStart..<rowEnd]
                .map { String(format: "%02X", $0) }
                .joined(separator: " ")
            rows.append(indent + row)
        }
        return rows.joined(separator: "\n")
    }
}
