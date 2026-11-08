import Foundation

/// The PNG files a layer export writes: the layers chosen, top first as the panel lists them, each named for its layer
/// and told apart from another of the same name. The Mac's Export Layers writes them to a folder; the iOS app offers
/// them together, by these names.
nonisolated enum LayerExportPlan {
    struct File: Equatable, Sendable {
        let id: UUID
        /// The layer's own name, for saying which one couldn't be exported.
        let layerName: String
        /// The file's, with its extension.
        let name: String
    }

    /// The files for `selected`, or for `active` while nothing is selected, as a row menu acts on the layer it was
    /// opened on. A layer of the same name lower in the panel takes the next number, so the upper keeps the name.
    static func files(in snapshot: ProjectSnapshot, selected: Set<UUID>, active: UUID?) -> [File] {
        let chosen = selected.isEmpty ? Set(active.map { [$0] } ?? []) : selected
        guard !chosen.isEmpty else { return [] }
        var used: Set<String> = []
        return snapshot.manifest.layers.reversed().filter { chosen.contains($0.id) }.map { layer in
            let base = fileName(layer.name)
            var name = base, number = 2
            while !used.insert(name.lowercased()).inserted { name = "\(base) \(number)"; number += 1 }
            return File(id: layer.id, layerName: layer.name, name: name + ".png")
        }
    }

    /// A layer's name as a file name: the separators a name can't hold in a file are dashes, and a name that would be
    /// hidden, or none at all, still makes a file.
    static func fileName(_ name: String) -> String {
        let cleaned = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty || cleaned.hasPrefix(".") ? "Layer" + cleaned : cleaned
    }
}
