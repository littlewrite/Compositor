import AppKit
import Testing
@testable import Compositor

/// Color Lookup reads .cube and .3dl tables and maps a layer's colors through them.
@MainActor
struct ColorLookupTests {
    private func table(_ text: String, extension fileExtension: String) throws -> ColorLookupTable {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Lookup-\(UUID()).\(fileExtension)")
        try text.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        return try ColorLookupReader.read(url)
    }

    private func solid(_ color: CGColor, size: Int = 4) throws -> CGImage {
        let context = try BrushRaster.context(width: size, height: size, mask: false)
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))
        return try #require(context.makeImage())
    }

    private func pixels(_ image: CGImage) throws -> [UInt8] {
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Array(UnsafeBufferPointer(start: try #require(context.data).assumingMemoryBound(to: UInt8.self),
                                         count: image.width * image.height * 4))
    }

    private func sample(_ table: ColorLookupTable, _ red: Int, _ green: Int, _ blue: Int) -> [UInt8] {
        let size = table.dimension
        let index = (red + green * size + blue * size * size) * 4
        return Array(table.pixels[index..<index + 3])
    }

    /// A .cube whose eight entries swap red and blue arrives on the fixed grid with its corners in the right places.
    @Test func cubeSwapArrivesOnTheGrid() throws {
        let table = try table("""
        # Swap red and blue
        TITLE "Swap"
        LUT_3D_SIZE 2
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """, extension: "cube")
        #expect(table.dimension == ColorLookupTable.size)
        #expect(table.isValid)
        let last = ColorLookupTable.size - 1
        #expect(sample(table, last, 0, 0) == [0, 0, 255], "red becomes blue")
        #expect(sample(table, 0, 0, last) == [255, 0, 0], "blue becomes red")
        #expect(sample(table, 0, last, 0) == [0, 255, 0], "green stays")
    }

    /// A 1D .cube, shaping each channel on its own, is resampled straight across the grid.
    @Test func aOneDimensionalCubeShapesEachChannel() throws {
        let table = try table("""
        LUT_1D_SIZE 2
        0 0 0
        1 1 1
        """, extension: "cube")
        #expect(table.isValid)
        let middle = ColorLookupTable.size / 2
        let values = sample(table, middle, middle, middle)
        #expect(values[0] >= 126 && values[0] <= 130, "the middle stays in the middle: \(values)")
    }

    /// A 3D .3dl mesh reads as a table, with its integer values taken to the 8- or 12-bit scale they use.
    @Test func aThreeDimensionalMeshReads() throws {
        let table = try table("""
        3DMESH
        Mesh 0 2
        0 0 0
        255 0 0
        0 255 0
        255 255 0
        0 0 255
        255 0 255
        0 255 255
        255 255 255
        """, extension: "3dl")
        #expect(table.isValid)
        let last = ColorLookupTable.size - 1
        #expect(sample(table, last, 0, 0) == [255, 0, 0])
        #expect(sample(table, 0, 0, 0) == [0, 0, 0])
        #expect(sample(table, 0, 0, last) == [0, 0, 255])
    }

    @Test func aMalformedFileIsRejected() throws {
        #expect(throws: ColorLookupError.self) { try table("not a lookup table", extension: "cube") }
    }

    /// The adjustment maps a red picture to blue through the table.
    @Test func theAdjustmentMapsThePicture() throws {
        let lookup = try table("""
        LUT_3D_SIZE 2
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """, extension: "cube")
        var adjustment = LayerAdjustment(kind: .colorLookup)
        adjustment.filterLayer.colorLookup = lookup
        #expect(adjustment.isValid)
        let image = try solid(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        let output = try adjustment.apply(image)
        let values = try pixels(output)
        let middle = (output.width / 2 + output.height / 2 * output.width) * 4
        #expect(values[middle] < 15, "red is gone: \(values[middle])")
        #expect(values[middle + 2] > 240, "blue took its place: \(values[middle + 2])")
    }

    /// The same table through the Filter menu's filter job.
    @Test func theFilterAppliesTheTable() throws {
        let lookup = try table("""
        LUT_3D_SIZE 2
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """, extension: "cube")
        var settings = FilterSettings()
        settings.colorLookup = lookup
        #expect(FilterKind.colorLookup.runsAtSixteenBits)
        let job = FilterJob(kind: .colorLookup, image: try solid(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)),
                            settings: settings, scale: 1, selection: nil, mapping: .identity)
        let output = try PixelFilter.run(job)
        let values = try pixels(output)
        let middle = (output.width / 2 + output.height / 2 * output.width) * 4
        #expect(values[middle] < 15)
        #expect(values[middle + 2] > 240)
    }

    @Test func aTableSurvivesAProject() async throws {
        let session = EditorSession()
        session.createDocument(width: 20, height: 20)
        let image = try solid(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), size: 20)
        session.insert(ImportedImage(image: image, thumbnail: image, name: "Layer"))
        session.addAdjustment(.colorLookup)
        let id = try #require(session.activeLayerID)
        let lookup = try table("""
        LUT_3D_SIZE 2
        0 0 0
        0 0 1
        0 1 0
        0 1 1
        1 0 0
        1 0 1
        1 1 0
        1 1 1
        """, extension: "cube")
        guard let index = session.document?.layers.firstIndex(where: { $0.id == id }) else { return }
        session.document?.layers[index].adjustment?.filterLayer.colorLookup = lookup
        let snapshot = try #require(session.projectSnapshot())
        #expect(snapshot.manifest.version == ProjectManifest.current)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ColorLookup-\(UUID()).comp")
        defer { try? FileManager.default.removeItem(at: url) }
        try await ProjectStore.shared.save(snapshot, to: url)
        let loaded = try await ProjectStore.shared.load(from: url)
        let record = try #require(loaded.manifest.layers.first { $0.id == id })
        #expect(record.adjustment?.filterLayerSettings?.colorLookup == lookup)
    }
}
