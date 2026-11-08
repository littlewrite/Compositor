import Foundation

/// The rules a window's tab strip follows whatever draws it: what a new tab is called, when one can close, and which
/// tab comes forward as one goes.
nonisolated enum TabWorkspace {
    /// A new tab's name: "Untitled" if no tab shows it, otherwise the lowest "Untitled N" free, as Finder and Safari
    /// number them. Counting up for ever, closing the last tab made Untitled 2, then 3, and on.
    static func freeUntitledName(taken: Set<String>) -> String {
        let untitled = "Untitled".localized
        guard taken.contains(untitled) else { return untitled }
        return (2...).lazy.map { String(format: "%@ %d", untitled, $0) }.first { !taken.contains($0) }!
    }

    /// Whether a tab can close: not the only one while it's empty, the blank start it would only be replaced with.
    static func canClose(tabCount: Int, isEmpty: Bool) -> Bool {
        tabCount > 1 || !isEmpty
    }

    /// The tab that takes a closed one's place: the next one, or the last once that was the end.
    static func indexAfterClosing(_ index: Int, remaining: Int) -> Int {
        min(index, max(0, remaining - 1))
    }
}
