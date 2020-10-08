import Foundation
import UIKit
import SimplenoteFoundation


// MARK: - OptionsViewController
//
class OptionsViewController: UIViewController {

    /// Options TableView
    ///
    @IBOutlet private var tableView: UITableView!

    /// Note for which we'll render the current Options
    ///
    private let note: Note

    /// EntityObserver: Allows us to listen to changes applied to the associated entity
    ///
    private lazy var entityObserver = EntityObserver(context: SPAppDelegate.shared().managedObjectContext, object: note)

    /// Sections onScreen
    ///
    private var sections = [Section]()


    /// Designated Initializer
    ///
    init(note: Note) {
        self.note = note
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported!")
    }

    // MARK: - Overridden Methods

    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationTitle()
        setupNavigationItem()
        setupTableView()
        setupEntityObserver()
        refreshStyle()
        refreshSections()
        refreshPreferredSize()
    }
}


// MARK: - Initialization
//
private extension OptionsViewController {

    func setupNavigationTitle() {
        title = NSLocalizedString("Options", comment: "Note Options Title")
    }

    func setupNavigationItem() {
        let doneTitle = NSLocalizedString("Done", comment: "Dismisses the Note Options UI")
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: doneTitle,
                                                            style: .done,
                                                            target: self,
                                                            action: #selector(doneWasPressed))
    }

    func setupTableView() {
        tableView.register(SwitchTableViewCell.self, forCellReuseIdentifier: SwitchTableViewCell.reuseIdentifier)
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: Value1TableViewCell.reuseIdentifier)
    }

    func setupEntityObserver() {
        entityObserver.delegate = self
    }

    func refreshPreferredSize() {
        preferredContentSize = tableView.contentSize
    }

    func refreshStyle() {
        view.backgroundColor = .simplenoteTableViewBackgroundColor
        tableView.applySimplenoteGroupedStyle()
    }
}


// MARK: - EntityObserverDelegate
//
extension OptionsViewController: EntityObserverDelegate {

    func entityObserver(_ observer: EntityObserver, didObserveChanges identifiers: Set<NSManagedObjectID>) {
        refreshSections()
    }
}


// MARK: - Action Handlers
//
private extension OptionsViewController {

    @IBAction
    func doneWasPressed() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction
    func pinnedWasPressed(_ sender: UISwitch) {
        SPObjectManager.shared().updatePinnedState(note, pinned: sender.isOn)
        SPTracker.trackEditorNotePinEnabled(sender.isOn)
    }

    @IBAction
    func markdownWasPressed(_ sender: UISwitch) {
        Options.shared.markdown = sender.isOn
        SPObjectManager.shared().updateMarkdownState(note, markdown: sender.isOn)
        SPTracker.trackEditorNoteMarkdownEnabled(sender.isOn)
    }

    @IBAction
    func copyInterlinkWasPressed() {
        UIPasteboard.general.copyInterlink(to: note)
        SPTracker.trackEditorCopiedInternalLink()
    }

    @IBAction
    func shareWasPressed() {
        NSLog("Share!")
    }

    @IBAction
    func historyWasPressed() {
        NSLog("History!")
    }

    @IBAction
    func publishWasPressed(_ sender: UISwitch) {
        SPObjectManager.shared().updatePublishedState(note, published: sender.isOn)
        SPTracker.trackEditorNotePublishEnabled(sender.isOn)
    }

    @IBAction
    func copyLinkWasPressed() {
        NSLog("Copy!")
    }

    @IBAction
    func collaborateWasPressed() {
        NSLog("Collab!")
    }

    @IBAction
    func trashWasPressed() {
        NSLog("Trash!")
    }
}


// MARK: - UITableViewDelegate
//
extension OptionsViewController: UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int {
        sections.count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        perform(rowAtIndexPath(indexPath).handler)
    }
}


// MARK: - UITableViewDataSource
//
extension OptionsViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        sections[section].rows.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let row = rowAtIndexPath(indexPath)
        let cell = tableView.dequeueReusableCell(withIdentifier: row.reuseIdentifier, for: indexPath)

        configureCell(cell, with: row)

        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sections[section].header
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sections[section].footer
    }
}


// MARK: - Helper API(s)
//
private extension OptionsViewController {

    func rowAtIndexPath(_ indexPath: IndexPath) -> Row {
        sections[indexPath.section].rows[indexPath.row]
    }

    func configureCell(_ cell: UITableViewCell, with row: Row) {
        switch cell {
        case let cell as SwitchTableViewCell:
            configureSwitchCell(cell, for: row)
        case let cell as Value1TableViewCell:
            configureValue1Cell(cell, for: row)
        default:
            fatalError()
        }
    }

    func configureSwitchCell(_ switchCell: SwitchTableViewCell, for row: Row) {
        guard case let .switch(selected) = row.kind else {
            fatalError()
        }
        
        switchCell.onChange = { [weak self] switchControl in
            self?.perform(row.handler, with: switchControl)
        }

        switchCell.textLabel?.text = row.title
        switchCell.enabledAccessibilityHint = row.enabledHint
        switchCell.disabledAccessibilityHint = row.disabledHint
        switchCell.switchControl.isOn = selected
    }

    func configureValue1Cell(_ valueCell: Value1TableViewCell, for row: Row) {
        valueCell.textLabel?.text = row.title
        valueCell.destructive = row.destructive
        valueCell.selectable = row.selectable
    }
}


// MARK: - Intermediate Representations
//
private extension OptionsViewController {

    func refreshSections() {
        sections = self.sections(for: note)
        tableView.reloadData()
    }

    func sections(for note: Note) -> [Section] {
        let canCopyLink = note.published && note.publishURL.count > .zero
        return [
            Section(rows: [
                        Row(kind:           .switch(selected: note.pinned),
                            title:          NSLocalizedString("Pin to Top", comment: "Toggles the Pinned State"),
                            enabledHint:    NSLocalizedString("Unpin note", comment: "Pin State Accessibility Hint"),
                            disabledHint:   NSLocalizedString("Pin note", comment: "Pin State Accessibility Hint"),
                            handler:        #selector(pinnedWasPressed)),

                        Row(kind:           .switch(selected: note.markdown),
                            title:          NSLocalizedString("Markdown", comment: "Toggles the Markdown State"),
                            enabledHint:    NSLocalizedString("Disable Markdown formatting", comment: "Markdown Accessibility Hint"),
                            disabledHint:   NSLocalizedString("Enable Markdown formatting", comment: "Markdown Accessibility Hint"),
                            handler:        #selector(markdownWasPressed)),

                        Row(kind:           .value1,
                            title:          NSLocalizedString("Copy Internal Link", comment: "Copies the Note's Internal LInk"),
                            handler:        #selector(copyInterlinkWasPressed)),

                        Row(kind:           .value1,
                            title:          NSLocalizedString("Share", comment: "Opens the Share Sheet"),
                            handler:        #selector(shareWasPressed)),

                        Row(kind:           .value1,
                            title:          NSLocalizedString("History", comment: "Opens the Note's History"),
                            handler:        #selector(historyWasPressed))
                    ]),
            Section(header:                 NSLocalizedString("Public Link", comment: "Publish to Web Section Header"),
                    footer:                 NSLocalizedString("Publish your note to the web and generate a sharable URL.", comment: "Publish to Web Section Footer"),
                    rows: [
                        Row(kind:           .switch(selected: note.published),
                            title:          NSLocalizedString("Publish", comment: "Publishes a Note to the Web"),
                            enabledHint:    NSLocalizedString("Unpublish note", comment: "Publish Accessibility Hint"),
                            disabledHint:   NSLocalizedString("Publish note", comment: "Publish Accessibility Hint"),
                            handler:        #selector(publishWasPressed)),

                        Row(kind:           .value1,
                            title:          NSLocalizedString("Copy Link", comment: "Copies a Note's Public URL"),
                            selectable:     canCopyLink,
                            handler:        #selector(copyLinkWasPressed))
                    ]),
            Section(rows: [
                        Row(kind:           .value1,
                            title:          NSLocalizedString("Collaborate", comment: "Opens the Collaborate UI"),
                            handler:        #selector(collaborateWasPressed))

                    ]),
            Section(rows: [
                        Row(kind:           .value1,
                            title:          NSLocalizedString("Move to Trash", comment: "Delete Action"),
                            destructive:    true,
                            handler:        #selector(trashWasPressed))
                    ]),
        ]
    }
}


// MARK: - Section: Defines a TableView Section
//
private struct Section {
    let header: String?
    let footer: String?
    let rows: [Row]

    init(header: String? = nil, footer: String? = nil, rows: [Row]) {
        self.header = header
        self.footer = footer
        self.rows = rows
    }
}


// MARK: - Supported TableView Rows
//
private struct Row {
    let kind: RowKind
    let title: String
    let enabledHint: String
    let disabledHint: String?
    let destructive: Bool
    let selectable: Bool
    let handler: Selector

    init(kind: RowKind, title: String, enabledHint: String? = nil, disabledHint: String? = nil, destructive: Bool = false, selectable: Bool = true, handler: Selector) {
        self.kind = kind
        self.title = title
        self.enabledHint = enabledHint ?? title
        self.disabledHint = disabledHint
        self.destructive = destructive
        self.selectable = selectable
        self.handler = handler
    }
}

private enum RowKind {
    case value1
    case `switch`(selected: Bool)
}

// MARK: - Row API(s)
//
private extension Row {

    var reuseIdentifier: String {
        switch kind {
        case .value1:
            return Value1TableViewCell.reuseIdentifier
        case .switch:
            return SwitchTableViewCell.reuseIdentifier
        }
    }
}
