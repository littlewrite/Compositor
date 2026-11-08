import UIKit

/// A sheet of named choices, grouped as the Mac's menus group them: the adjustments and filters the mode bar offers on a
/// window whose menus are out of reach. Choosing one puts the sheet away and runs it.
final class ListPickerController: MobileViewController, UITableViewDataSource, UITableViewDelegate {
    struct Row {
        let title: String
        var enabled = true
        let run: () -> Void
    }

    struct Section {
        var title: String?
        let rows: [Row]
    }

    private let sections: [Section]
    private let table = UITableView(frame: .zero, style: .insetGrouped)

    init(title: String, sections: [Section]) {
        self.sections = sections
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Palette.window
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Cancel".localized, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        table.dataSource = self
        table.delegate = self
        table.backgroundColor = .clear
        view.addSubview(table)
        table.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            table.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    func numberOfSections(in tableView: UITableView) -> Int { sections.count }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? { sections[section].title }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { sections[section].rows.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = sections[indexPath.section].rows[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "row") ?? UITableViewCell(style: .default, reuseIdentifier: "row")
        var content = cell.defaultContentConfiguration()
        content.text = row.title
        content.textProperties.color = row.enabled ? .label : .tertiaryLabel
        cell.contentConfiguration = content
        cell.backgroundColor = Palette.well
        cell.selectionStyle = row.enabled ? .default : .none
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let row = sections[indexPath.section].rows[indexPath.row]
        guard row.enabled else { return }
        dismiss(animated: true) { row.run() }
    }
}
