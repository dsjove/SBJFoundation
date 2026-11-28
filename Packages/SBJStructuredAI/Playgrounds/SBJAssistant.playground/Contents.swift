import Foundation
import Observation
import PlaygroundSupport
import SwiftUI
import SBJStructure
import SBJStructuredAI

// This playground is a host, not an assistant implementation.
@MainActor
@Observable
final class RecipeDocument {
    typealias Assistant = any SBJAssistantCoordinating & SBJAssistantPresenting

    private(set) var model = SBJStructureSampleModel()
    private(set) var revision = 0
    private(set) var assistant: Assistant?
    private(set) var traversalOptions: SBJTraversalOptions = .all
    private(set) var allowsEditing = true
    private(set) var sessionID = UUID()
    private let documentID = UUID().uuidString

    var isBusy: Bool {
        guard let assistant else { return false }
        return assistant.isResponding || assistant.isPersisting || assistant.pendingProposal != nil
    }

    func configure(traversalOptions: SBJTraversalOptions, allowsEditing: Bool) {
        guard !isBusy else { return }
        assistant?.deactivate()
        self.traversalOptions = traversalOptions
        self.allowsEditing = allowsEditing
        assistant = SBJAIAvailability.makeAssistant(
            snapshot: { [weak self] in self?.snapshot() },
            persist: { [weak self] candidate, id, revision, completion in
                guard let self else {
                    completion(.failure(DocumentError.closed))
                    return
                }
                completion(Result { try self.commit(candidate, id: id, revision: revision) })
            },
            domainInstructions: "The business domain is a cooking recipe.",
            traversalOptions: traversalOptions
        )
        sessionID = UUID()
        assistant?.activate()
    }

    private func snapshot() -> SBJAssistantDocument<SBJStructureSampleModel> {
        .init(id: documentID, revision: revision, model: model, allowsEditing: allowsEditing)
    }

    // The host checks the expected identity and revision atomically on MainActor.
    // The library already validates and asks for approval before invoking this callback.
    private func commit(_ candidate: SBJStructureSampleModel, id: String, revision: Int) throws {
        guard allowsEditing else { throw DocumentError.readOnly }
        guard id == documentID, revision == self.revision else { throw DocumentError.stale }
        model = candidate
        self.revision += 1
    }

    func restoreSample() {
        guard !isBusy else { return }
        model = SBJStructureSampleModel()
        revision += 1
        assistant?.synchronize()
    }

    enum DocumentError: LocalizedError {
        case closed, readOnly, stale
        var errorDescription: String? {
            switch self {
            case .closed: "The sample document is closed."
            case .readOnly: "The sample document is read-only."
            case .stale: "The sample document has changed."
            }
        }
    }
}

@MainActor
struct AssistantPlayground: View {
    @State private var document = RecipeDocument()
    @State private var selectedOptions: SBJTraversalOptions = .all
    @State private var allowsEditing = true
    @State private var showRestoreConfirmation = false

    // Presentation configuration is independent of document traversal.
    private let viewOptions = SBJAssistantViewOptions(
        hasDiagnostics: true,
        hasShareDialog: true,
        hasResetButton: true
    )

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recipe document").font(.title2.bold())
                Text("Revision \(document.revision)").monospacedDigit()
                    .foregroundStyle(.secondary)
                GroupBox("Model configuration") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Button("All") { selectedOptions = .all }
                            Button("Stored only") { selectedOptions = .all.subtracting(.computed) }
                            Button("Editable") { selectedOptions = .editor }
                        }
                        HStack {
                            flag("Stored", .stored)
                            flag("Computed", .computed)
                        }
                        HStack {
                            flag("Read-only", .readOnly)
                            flag("Read/write", .readWrite)
                        }
                        HStack {
                            flag("Public", .publicAccess)
                            flag("Package", .packageAccess)
                            flag("Internal", .internalAccess)
                        }
                        Toggle("Allow assistant mutations", isOn: $allowsEditing)
                        Button("Apply configuration (new session)") {
                            document.configure(traversalOptions: selectedOptions, allowsEditing: allowsEditing)
                        }
                        .disabled(document.isBusy || !hasValidOptions ||
                            (selectedOptions == document.traversalOptions && allowsEditing == document.allowsEditing))
                    }
                    .disabled(document.isBusy)
                }
                HStack {
                    Text(document.model.name).font(.headline)
                    Spacer()
                    Button("Restore sample", role: .destructive) { showRestoreConfirmation = true }
                        .disabled(document.isBusy)
                }
                Text("Servings: \(document.model.servings) • Ingredients: \(document.model.ingredients.count) • Steps: \(document.model.steps.count)")
                    .font(.caption)
                // Existing public Swift-source export shows committed model values.
                ScrollView([.vertical, .horizontal]) {
                    Text(SBJSwiftEncoder().encode(document.model, named: "recipe"))
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
            }
            .padding()
            .frame(minWidth: 420, idealWidth: 480)

            Group {
                if let assistant = document.assistant {
                    SBJAssistantView(assistant: assistant, options: viewOptions)
                        .id(document.sessionID)
                } else {
                    SBJAssistantAvailabilityView(state: SBJAIAvailability.state,
                        providerName: "Apple Intelligence",
                        message: SBJAIAvailability.message(for: SBJAIAvailability.state))
                }
            }
            .frame(minWidth: 380, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 1100, height: 750)
        .onAppear {
            document.configure(traversalOptions: selectedOptions, allowsEditing: allowsEditing)
        }
        .onDisappear { document.assistant?.deactivate() }
        .alert("Restore sample recipe?", isPresented: $showRestoreConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Restore", role: .destructive) { document.restoreSample() }
        } message: {
            Text("This replaces the in-memory document, including approved changes. The assistant's Reset button does not restore the document.")
        }
    }

    private var hasValidOptions: Bool {
        !selectedOptions.intersection([.stored, .computed]).isEmpty &&
        !selectedOptions.intersection([.readOnly, .readWrite]).isEmpty &&
        !selectedOptions.intersection([.publicAccess, .packageAccess, .internalAccess]).isEmpty
    }

    private func flag(_ title: String, _ option: SBJTraversalOptions) -> some View {
        Toggle(title, isOn: Binding(
            get: { selectedOptions.contains(option) },
            set: { enabled in
                if enabled { selectedOptions.insert(option) }
                else { selectedOptions.remove(option) }
            }
        ))
    }
}

PlaygroundPage.current.needsIndefiniteExecution = true
PlaygroundPage.current.setLiveView(AssistantPlayground())
