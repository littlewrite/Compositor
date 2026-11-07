import UIKit

/// Every command the app's menus hold, kept as they're built, for Search Commands to find and run.
@MainActor final class CommandRegistry {
    static let shared = CommandRegistry()

    struct Entry {
        let title: String
        /// The menus it sits in, as "File › Export", for a second line and for matching.
        let path: String
        let command: UICommand
    }

    private(set) var entries: [Entry] = []

    /// Starts a build: the menu bar is built afresh, so the commands of the build before are gone.
    func beginBuild() { entries = [] }

    func register(_ elements: [UIMenuElement], path: String) {
        for element in elements {
            if let menu = element as? UIMenu {
                // An inline group has no title of its own: its commands sit in the menu it's in.
                let childPath = menu.title.isEmpty ? path : (path.isEmpty ? menu.title : path + " › " + menu.title)
                register(menu.children, path: childPath)
            } else if let command = element as? UICommand {
                entries.append(Entry(title: command.title, path: path, command: command))
            }
        }
    }
}

/// View › Search Commands…, as the Mac's palette: every command the window can run now, found by typing part of its name
/// or the menus it's in, and run by choosing it. Return runs the first, and Escape puts the palette away.
final class CommandPaletteController: PadViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {
    var onChoose: (UICommand) -> Void = { _ in }

    private let search = UITextField()
    private let table = UITableView(frame: .zero, style: .plain)
    private var commands: [CommandRegistry.Entry] = []
    private var shown: [CommandRegistry.Entry] = []

    override func loadView() {
        view = UIView()
        view.backgroundColor = Palette.window
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.accessibilityIdentifier = "commandPalette"
        title = "Search Commands".localized
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel".localized, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })

        search.placeholder = "Search Commands".localized
        search.font = .preferredFont(forTextStyle: .body)
        search.borderStyle = .none
        search.backgroundColor = Palette.well
        search.layer.cornerRadius = 10
        search.layer.cornerCurve = .continuous
        search.leftView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        search.leftView?.tintColor = .secondaryLabel
        search.leftViewMode = .always
        search.clearButtonMode = .whileEditing
        search.returnKeyType = .go
        search.autocorrectionType = .no
        search.autocapitalizationType = .words
        search.delegate = self
        search.accessibilityLabel = "Search commands".localized
        search.addAction(UIAction { [weak self] _ in self?.filter() }, for: .editingChanged)
        for view in [search, table] as [UIView] {
            self.view.addSubview(view)
            view.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            search.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            search.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            search.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            search.heightAnchor.constraint(equalToConstant: 44),
            table.topAnchor.constraint(equalTo: search.bottomAnchor, constant: 12),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        table.backgroundColor = .clear
        table.separatorColor = Palette.separator
        table.rowHeight = 56
        table.dataSource = self
        table.delegate = self
        table.keyboardDismissMode = .onDrag
        table.register(UITableViewCell.self, forCellReuseIdentifier: "command")

        commands = EditorWindowController.frontmost.map { window in
            CommandRegistry.shared.entries.filter { window.canPerformAction($0.command.action, withSender: $0.command) }
        } ?? CommandRegistry.shared.entries
        filter()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        search.becomeFirstResponder()
    }

    /// What the field's text narrows the commands to: the name first, then the menus it's in.
    private func filter() {
        let query = (search.text ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else {
            shown = Array(commands.prefix(40))
            table.reloadData()
            return
        }
        let ranked = commands.compactMap { entry -> (Int, String, CommandRegistry.Entry)? in
            let title = entry.title.lowercased()
            if title.hasPrefix(query) { return (0, title, entry) }
            if title.contains(query) { return (1, title, entry) }
            if entry.path.lowercased().contains(query) { return (2, title, entry) }
            return nil
        }
        shown = ranked.sorted { ($0.0, $0.1) < ($1.0, $1.1) }.prefix(40).map(\.2)
        table.reloadData()
    }

    private func choose(_ entry: CommandRegistry.Entry) {
        guard let window = EditorWindowController.frontmost,
              window.canPerformAction(entry.command.action, withSender: entry.command) else { return }
        onChoose(entry.command)
    }

    // MARK: The list

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { shown.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "command", for: indexPath)
        var configuration = cell.defaultContentConfiguration()
        let entry = shown[indexPath.row]
        configuration.text = entry.title
        configuration.secondaryText = Self.shortcut(entry.command).map { "\(entry.path)   \($0)" } ?? entry.path
        configuration.textProperties.color = .label
        configuration.secondaryTextProperties.color = .secondaryLabel
        configuration.textProperties.font = .preferredFont(forTextStyle: .body)
        configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .caption1)
        cell.contentConfiguration = configuration
        cell.backgroundColor = .clear
        cell.accessoryType = .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        choose(shown[indexPath.row])
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let first = shown.first else { return false }
        choose(first)
        return true
    }

    /// A command's keys, as the menus show them, or none for one without.
    private static func shortcut(_ command: UICommand) -> String? {
        guard let key = command as? UIKeyCommand, let input = key.input, !input.isEmpty else { return nil }
        let flags = key.modifierFlags
        let name: String
        switch input {
        case UIKeyCommand.inputUpArrow: name = "↑"
        case UIKeyCommand.inputDownArrow: name = "↓"
        case UIKeyCommand.inputLeftArrow: name = "←"
        case UIKeyCommand.inputRightArrow: name = "→"
        case UIKeyCommand.inputEscape: name = "Esc"
        case UIKeyCommand.inputDelete: name = "⌫"
        case "\t": name = "⇥"
        case " ": name = "Space"
        default: name = input.uppercased()
        }
        return (flags.contains(.control) ? "⌃" : "") + (flags.contains(.alternate) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "") + name
    }
}
