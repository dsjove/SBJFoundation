import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantDiagnosticsView: View {
    private typealias N = SBJAssistantNomenclature
    let lines: [String]
    let canPrintInstructions: Bool
    let printInstructions: () -> Void
    @State private var showsFrameworkDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showsFrameworkDiagnostics.toggle()
            } label: {
                Label(N.backendDiagnostics.title, systemImage: "stethoscope")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            if showsFrameworkDiagnostics {
                if canPrintInstructions {
                    Button(action: printInstructions) {
                        Label(N.printInstructions.title, systemImage: "doc.text")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .frame(minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                }
                ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(.caption2, design: .monospaced))
#if !os(watchOS) && !os(tvOS)
                        .textSelection(.enabled)
#endif
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}
