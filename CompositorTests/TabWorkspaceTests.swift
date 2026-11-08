import Testing
@testable import Compositor

/// The tab strip's rules: the Mac's window and the iOS app's window both ask here.
struct TabWorkspaceTests {
    @Test func untitledNamesTakeTheLowestFreeNumber() {
        #expect(TabWorkspace.freeUntitledName(taken: []) == "Untitled")
        #expect(TabWorkspace.freeUntitledName(taken: ["Untitled"]) == "Untitled 2")
        #expect(TabWorkspace.freeUntitledName(taken: ["Untitled", "Untitled 3"]) == "Untitled 2")
        #expect(TabWorkspace.freeUntitledName(taken: ["Harbor"]) == "Untitled")
    }

    @Test func onlyTheEmptyOnlyTabCannotClose() {
        #expect(!TabWorkspace.canClose(tabCount: 1, isEmpty: true))
        #expect(TabWorkspace.canClose(tabCount: 1, isEmpty: false))
        #expect(TabWorkspace.canClose(tabCount: 2, isEmpty: true))
    }

    @Test func theNextTabComesForwardOrTheLast() {
        #expect(TabWorkspace.indexAfterClosing(0, remaining: 3) == 0)
        #expect(TabWorkspace.indexAfterClosing(2, remaining: 3) == 2)
        #expect(TabWorkspace.indexAfterClosing(1, remaining: 1) == 0)
    }
}
