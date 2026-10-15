import Foundation
@testable import BurnFuseUI

/// A model watching a few providers, built through the same public calls the
/// app itself uses — `addKey` and `record`, nothing that reaches into state
/// from behind.
///
/// The app ships no sample data of its own, so tests bring their own, exactly
/// as a person's own providers come to life: a name, a cap, and readings.
@MainActor
func sampleModel(at url: URL) -> AppModel {
    let model = AppModel(stateURL: url, pollInterval: 0)
    let openai = model.addKey(name: "OpenAI prod", provider: "openai", cap: 5)
    let claude = model.addKey(name: "Claude batch", provider: "anthropic", cap: 8)
    let fal = model.addKey(name: "Fal images", provider: "fal", cap: 3)
    let histories: [(String, [Double])] = [
        (openai.id, [1.12, 1.28, 1.19, 1.34, 1.22, 1.31]),
        (claude.id, [0.62, 0.58, 0.71, 0.66, 0.69, 0.63]),
        (fal.id, [0.40, 0.50, 0.45, 0.52, 0.48, 0.51]),
    ]
    for (keyID, costs) in histories {
        for cost in costs { model.record(keyID: keyID, cost: cost) }
    }
    return model
}

/// The common case: a fresh temp file for the state.
@MainActor
func sampleModel() -> AppModel {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("burnfuse-sample-\(UUID().uuidString).json")
    return sampleModel(at: url)
}
