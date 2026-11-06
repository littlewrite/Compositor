import XCTest

final class CompositorPadUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEditorSmoke() throws {
        let app = XCUIApplication()
        app.launch()

        func drag(from: CGVector, to: CGVector) {
            let start = app.coordinate(withNormalizedOffset: from)
            let end = app.coordinate(withNormalizedOffset: to)
            start.press(forDuration: 0.15, thenDragTo: end)
        }

        // The tools sheet animates away; a drag started during that animation is swallowed.
        func selectTool(_ tool: String) {
            app.buttons["ModeTools"].tap()
            XCTAssertTrue(app.buttons[tool].waitForExistence(timeout: 3))
            app.buttons[tool].tap()
            XCTAssertTrue(app.buttons["SheetDone"].waitForNonExistence(timeout: 5))
            sleep(1)
        }

        XCTAssertTrue(app.buttons["ModeTools"].waitForExistence(timeout: 10))
        attach("01-editor")

        // Text layer
        app.buttons["ModeTools"].tap()
        XCTAssertTrue(app.buttons["Type"].waitForExistence(timeout: 3))
        app.buttons["Type"].tap()
        XCTAssertTrue(app.buttons["AddTextButton"].waitForExistence(timeout: 3))
        app.buttons["AddTextButton"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.tap()
        field.typeText("Hello")
        app.buttons["AddText"].tap()
        attach("02-text")

        // Layer operations
        app.buttons["ModeLayers"].tap()
        XCTAssertTrue(app.buttons["AddLayer"].waitForExistence(timeout: 3))
        app.buttons["AddLayer"].tap()
        app.buttons["DuplicateLayer"].tap()
        app.buttons["DeleteLayer"].tap()
        app.staticTexts["Lights"].tap()
        XCTAssertTrue(app.buttons["BlendModePicker"].waitForExistence(timeout: 3))
        app.buttons["BlendModePicker"].tap()
        XCTAssertTrue(app.buttons["Multiply"].waitForExistence(timeout: 3))
        app.buttons["Multiply"].tap()
        attach("03b-blend")
        app.buttons["SheetDone"].tap()
        attach("03c-blend-canvas")
        app.buttons["ModeLayers"].tap()
        XCTAssertTrue(app.buttons["BlendModePicker"].waitForExistence(timeout: 3))
        app.buttons["BlendModePicker"].tap()
        XCTAssertTrue(app.buttons["Normal"].waitForExistence(timeout: 3))
        app.buttons["Normal"].tap()
        attach("03-layers")
        app.buttons["SheetDone"].tap()

        // Filter preset
        app.buttons["ModeFilters"].tap()
        XCTAssertTrue(app.buttons["Filtervivid"].waitForExistence(timeout: 3))
        app.buttons["Filtervivid"].tap()
        attach("04-filters")
        app.buttons["SheetDone"].tap()

        // Adjustment slider
        app.buttons["ModeAdjust"].tap()
        let adjustment = app.sliders.firstMatch
        XCTAssertTrue(adjustment.waitForExistence(timeout: 3))
        adjustment.adjust(toNormalizedSliderPosition: 0.7)
        let blackAndWhite = app.switches["Black & White"]
        XCTAssertTrue(blackAndWhite.waitForExistence(timeout: 3))
        blackAndWhite.tap()
        attach("05-adjust")
        blackAndWhite.tap()
        app.buttons["SheetDone"].tap()

        // Levels
        app.buttons["ModeMore"].tap()
        XCTAssertTrue(app.buttons["Levels"].waitForExistence(timeout: 3))
        app.buttons["Levels"].tap()
        let levels = app.sliders.firstMatch
        XCTAssertTrue(levels.waitForExistence(timeout: 3))
        levels.adjust(toNormalizedSliderPosition: 0.2)
        app.buttons["LevelsDone"].tap()

        // Brush stroke (coordinates are inside the fitted document, not the canvas margin)
        selectTool("Toolbrush")
        drag(from: CGVector(dx: 0.30, dy: 0.36), to: CGVector(dx: 0.60, dy: 0.45))
        attach("06-brush")

        // Move the active layer
        selectTool("Toolmove")
        drag(from: CGVector(dx: 0.50, dy: 0.38), to: CGVector(dx: 0.56, dy: 0.44))
        attach("07-move")

        // Gradient layer
        selectTool("Toolgradient")
        drag(from: CGVector(dx: 0.15, dy: 0.36), to: CGVector(dx: 0.50, dy: 0.50))
        attach("08-gradient")
        app.buttons["ModeLayers"].tap()
        XCTAssertTrue(app.staticTexts["Gradient"].waitForExistence(timeout: 3))
        attach("08b-gradient-layer-row")
        app.buttons["SheetDone"].tap()

        // Eyedropper samples the canvas
        selectTool("Tooleyedropper")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
        attach("09-eyedropper")

        // Undo and redo
        XCTAssertTrue(app.buttons["UndoButton"].isEnabled)
        app.buttons["UndoButton"].tap()
        XCTAssertTrue(app.buttons["RedoButton"].isEnabled)
        app.buttons["RedoButton"].tap()
        attach("10-undo")

        // Crop: the document shrinks to the dragged rectangle
        selectTool("Toolcrop")
        drag(from: CGVector(dx: 0.25, dy: 0.40), to: CGVector(dx: 0.72, dy: 0.60))
        XCTAssertTrue(app.buttons["CropApply"].isEnabled)
        attach("10-crop")
        app.buttons["CropApply"].tap()

        // Undo restores the full document, redo brings the crop back
        app.buttons["UndoButton"].tap()
        app.buttons["TopExport"].tap()
        XCTAssertTrue(app.buttons["ConfirmExport"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["ExportSize"].label, "1,600 × 1,200")
        app.buttons["SheetDone"].tap()
        app.buttons["RedoButton"].tap()

        // Export sheet and render
        app.buttons["TopExport"].tap()
        XCTAssertTrue(app.buttons["ConfirmExport"].waitForExistence(timeout: 3))
        let exportSize = app.staticTexts["ExportSize"]
        XCTAssertTrue(exportSize.exists)
        XCTAssertNotEqual(exportSize.label, "1,600 × 1,200")
        app.buttons["ConfirmExport"].tap()
        sleep(3)
        XCTAssertEqual(app.state, .runningForeground)
        attach("11-export")
    }

    func testPhotosPickerPresents() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["ModeMore"].waitForExistence(timeout: 10))
        app.buttons["ModeMore"].tap()
        let importRow = app.buttons["Import from Photos"]
        XCTAssertTrue(importRow.waitForExistence(timeout: 3))
        importRow.tap()
        sleep(2)
        attach("12a-photos-after-tap")

        // The picker runs out of process; its Cancel button is the reliable sign it appeared.
        let cancel = app.buttons.matching(
            NSPredicate(format: "label == 'Cancel' OR label == '取消'")).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10))
        attach("12-photos-picker")

        // Pick the first photo in the grid; a selection limit of one closes the picker.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.16, dy: 0.48)).tap()
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 10))

        app.buttons["ModeLayers"].tap()
        XCTAssertTrue(app.staticTexts["Photo"].waitForExistence(timeout: 15))
        attach("13-photos-imported")
    }

    private func attach(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
