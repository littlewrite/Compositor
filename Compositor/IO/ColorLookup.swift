import CoreGraphics
import CoreImage
import Foundation
import UniformTypeIdentifiers

/// A color lookup table read from a .cube or .3dl file, resampled to one fixed grid so a project can carry it.
nonisolated struct ColorLookupTable: Codable, Equatable, Sendable {
    /// The grid every table is resampled to, as most color-grading LUTs are authored in sRGB at 33 or 32.
    static let size = 33
    /// The file's name without its extension, as the filter panel shows it.
    var name: String
    /// Samples on each axis; always `size` once read.
    var dimension: Int
    /// RGBA samples, 8 bits a channel, red varying fastest within a row.
    var pixels: Data

    var isValid: Bool {
        dimension == Self.size && pixels.count == dimension * dimension * dimension * 4
    }

    /// Core Image's cube data: RGBA as floats with alpha one.
    var cubeData: Data {
        var floats = [Float](repeating: 1, count: pixels.count)
        for (index, byte) in pixels.enumerated() where index % 4 != 3 {
            floats[index] = Float(byte) / 255
        }
        return floats.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

/// Reads .cube and .3dl color lookup tables into `ColorLookupTable`.
nonisolated enum ColorLookupReader {
    static let fileExtensions = ["cube", "3dl"]
    static var contentTypes: [UTType] { fileExtensions.compactMap { UTType(filenameExtension: $0) } }

    static func matches(_ url: URL) -> Bool {
        fileExtensions.contains(url.pathExtension.lowercased())
    }

    static func read(_ url: URL) throws -> ColorLookupTable {
        let data = try Data(contentsOf: url)
        guard data.count <= 32 << 20 else { throw ColorLookupError.tooLarge }
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw ColorLookupError.unreadable
        }
        let name = url.deletingPathExtension().lastPathComponent
        switch url.pathExtension.lowercased() {
        case "cube": return try cube(text, name: name)
        case "3dl": return try threeDL(text, name: name)
        default: throw ColorLookupError.unsupported
        }
    }

    /// Whether the array's side lengths form a grid this size can hold.
    private static func side(of count: Int) -> Int? {
        guard count > 1 else { return nil }
        let side = Int(cbrt(Double(count)).rounded())
        return side * side * side == count ? side : nil
    }

    private static func byte(_ value: Double) -> UInt8 {
        UInt8(min(255, max(0, (value * 255).rounded())))
    }

    private static func cube(_ text: String, name: String) throws -> ColorLookupTable {
        var size1D: Int?
        var size3D: Int?
        var minimum = [0.0, 0.0, 0.0]
        var maximum = [1.0, 1.0, 1.0]
        var entries: [(Double, Double, Double)] = []
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let parts = line.split(whereSeparator: \.isWhitespace)
            switch parts.first?.uppercased() {
            case "TITLE": continue
            case "LUT_3D_SIZE": size3D = parts.count > 1 ? Int(parts[1]) : nil
            case "LUT_1D_SIZE": size1D = parts.count > 1 ? Int(parts[1]) : nil
            case "DOMAIN_MIN":
                if parts.count >= 4 { minimum = parts[1...3].map { Double($0) ?? 0 } }
            case "DOMAIN_MAX":
                if parts.count >= 4 { maximum = parts[1...3].map { Double($0) ?? 1 } }
            default:
                if parts.count >= 3, let red = Double(parts[0]), let green = Double(parts[1]), let blue = Double(parts[2]) {
                    entries.append((red, green, blue))
                }
            }
        }
        // A .cube may shape the input with a 1D table first, then map it through the 3D table.
        var oneDimensional: [(Double, Double, Double)]?
        var threeDimensional: [(Double, Double, Double)]?
        if let size1D, let size3D {
            guard size1D >= 2, size3D >= 2, size3D <= 128, entries.count == size1D + size3D * size3D * size3D else {
                throw ColorLookupError.incomplete
            }
            oneDimensional = Array(entries.prefix(size1D))
            threeDimensional = Array(entries.dropFirst(size1D))
        } else if let size3D {
            guard size3D >= 2, size3D <= 128, entries.count == size3D * size3D * size3D else { throw ColorLookupError.incomplete }
            threeDimensional = entries
        } else if let size1D {
            guard size1D >= 2, entries.count == size1D else { throw ColorLookupError.incomplete }
            oneDimensional = entries
        } else {
            // A file without a size line still makes a table when its entries form a grid.
            guard let side = side(of: entries.count) else { throw ColorLookupError.incomplete }
            size3D = side
            threeDimensional = entries
        }
        return build(name: name, oneDimensional: oneDimensional,
                     threeDimensional: threeDimensional, size3D: size3D ?? 2,
                     minimum: minimum, maximum: maximum)
    }

    private static func threeDL(_ text: String, name: String) throws -> ColorLookupTable {
        var entries: [(Double, Double, Double)] = []
        var values: [Int] = []
        var is3D = false
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            let lower = line.lowercased()
            if lower.contains("3dmesh") || lower.hasPrefix("mesh") {
                is3D = true
                continue
            }
            let numbers = line.split(whereSeparator: \.isWhitespace).compactMap { Int($0) }
            guard numbers.count >= 3 else { continue }
            entries.append((Double(numbers[0]), Double(numbers[1]), Double(numbers[2])))
            values.append(contentsOf: numbers.prefix(3))
        }
        guard !entries.isEmpty else { throw ColorLookupError.incomplete }
        // .3dl values are 8 or 12 bits, depending on the file.
        let high = values.max() ?? 255
        let scale = high > 4095 ? 65535.0 : high > 255 ? 4095.0 : 255.0
        let normalized = entries.map { ($0.0 / scale, $0.1 / scale, $0.2 / scale) }
        if is3D {
            guard let side = side(of: normalized.count), side <= 128 else { throw ColorLookupError.incomplete }
            return build(name: name, oneDimensional: nil, threeDimensional: normalized, size3D: side,
                         minimum: [0, 0, 0], maximum: [1, 1, 1])
        }
        return build(name: name, oneDimensional: normalized, threeDimensional: nil, size3D: 2,
                     minimum: [0, 0, 0], maximum: [1, 1, 1])
    }

    /// Resamples a source grid — or a 1D shaper, or both — onto `ColorLookupTable.size`.
    private static func build(name: String, oneDimensional: [(Double, Double, Double)]?,
                              threeDimensional: [(Double, Double, Double)]?, size3D: Int,
                              minimum: [Double], maximum: [Double]) -> ColorLookupTable {
        let size = ColorLookupTable.size
        var bytes = [UInt8](repeating: 255, count: size * size * size * 4)
        for blue in 0..<size {
            for green in 0..<size {
                for red in 0..<size {
                    var input = [Double(red), Double(green), Double(blue)].map { $0 / Double(size - 1) }
                    if let oneDimensional {
                        input = (0..<3).map { sample(oneDimensional, channel: $0, at: input[$0]) }
                    }
                    let output = threeDimensional.map {
                        sample($0, size: size3D, at: input, minimum: minimum, maximum: maximum)
                    } ?? input
                    let index = (red + green * size + blue * size * size) * 4
                    bytes[index] = byte(output[0])
                    bytes[index + 1] = byte(output[1])
                    bytes[index + 2] = byte(output[2])
                    bytes[index + 3] = 255
                }
            }
        }
        return ColorLookupTable(name: name, dimension: size, pixels: Data(bytes))
    }

    /// One channel of a 1D table at `value` (0–1), straight-line between its entries.
    private static func sample(_ entries: [(Double, Double, Double)], channel: Int, at value: Double) -> Double {
        let last = entries.count - 1
        let position = min(Double(last), max(0, value * Double(last)))
        let low = Int(position), high = min(last, low + 1), weight = position - Double(low)
        func component(_ entry: (Double, Double, Double)) -> Double {
            channel == 0 ? entry.0 : channel == 1 ? entry.1 : entry.2
        }
        return component(entries[low]) * (1 - weight) + component(entries[high]) * weight
    }

    /// A point of a 3D table at `value` (0–1), three-linearly between its eight neighbors.
    private static func sample(_ entries: [(Double, Double, Double)], size: Int, at value: [Double],
                               minimum: [Double], maximum: [Double]) -> [Double] {
        let position = (0..<3).map { axis -> Double in
            let span = maximum[axis] - minimum[axis]
            let fraction = span > 0 ? (value[axis] - minimum[axis]) / span : 0
            return min(Double(size - 1), max(0, fraction * Double(size - 1)))
        }
        let low = position.map { Int($0) }
        let high = low.map { min(size - 1, $0 + 1) }
        let weight = (0..<3).map { position[$0] - Double(low[$0]) }
        func entry(_ red: Int, _ green: Int, _ blue: Int) -> (Double, Double, Double) {
            entries[red + green * size + blue * size * size]
        }
        var output = [Double](repeating: 0, count: 3)
        for blue in 0..<2 {
            for green in 0..<2 {
                for red in 0..<2 {
                    let share = (red == 0 ? 1 - weight[0] : weight[0])
                        * (green == 0 ? 1 - weight[1] : weight[1])
                        * (blue == 0 ? 1 - weight[2] : weight[2])
                    let sample = entry(red == 0 ? low[0] : high[0], green == 0 ? low[1] : high[1], blue == 0 ? low[2] : high[2])
                    output[0] += sample.0 * share
                    output[1] += sample.1 * share
                    output[2] += sample.2 * share
                }
            }
        }
        return output
    }
}

nonisolated enum ColorLookupError: LocalizedError {
    case unsupported, unreadable, tooLarge, incomplete
    var errorDescription: String? {
        switch self {
        case .unsupported: return "Choose a .cube or .3dl color lookup table.".localized
        case .unreadable: return "The color lookup table couldn’t be read.".localized
        case .tooLarge: return "The color lookup table is too large.".localized
        case .incomplete: return "The file doesn’t hold a complete color lookup table.".localized
        }
    }
}

@MainActor
extension EditorSession {
    /// Loads `table` into the open Color Lookup edit and previews it, as the panel's other controls do.
    func setColorLookup(_ table: ColorLookupTable) {
        guard let edit = filterEdit, edit.kind == .colorLookup, !edit.committing else { return }
        var settings = edit.settings
        settings.colorLookup = table
        updateFilter(settings, preview: edit.preview)
    }
}
