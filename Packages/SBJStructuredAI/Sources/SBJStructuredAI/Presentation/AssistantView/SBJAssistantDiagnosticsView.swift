import SwiftUI
import SBJLocalization

@MainActor
struct SBJAssistantDiagnosticsView: View {
    private typealias N = SBJAssistantNomenclature
    let lines: [String]
    @State private var showsFrameworkDiagnostics = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                showsFrameworkDiagnostics.toggle()
            } label: {
                Label(N.backendDiagnostics.title, systemImage: "stethoscope")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            if showsFrameworkDiagnostics {
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
