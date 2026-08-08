//
//  SkinLogListViewController.swift
//  AAINA
//

import UIKit

class SkinLogListViewController: UIViewController {

    // MARK: - Data
    var allEntries: [SkinLogEntry] = []
    var onEntryUpdated: ((SkinLogEntry) -> Void)?
    var onEntryDeleted: ((String) -> Void)?

    private var displayed: [SkinLogEntry] = []
    private var searchQuery = ""

    // MARK: - Views
    private let searchController = UISearchController(searchResultsController: nil)
    private let tableView        = UITableView(frame: .zero, style: .plain)
    private let emptyView        = UIView()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        setupNav()
        setupSearch()
        setupTable()
        setupEmptyView()
        refilter()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
    }

    // MARK: - Nav

    private func setupNav() {
        title = "Skin Reports"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let shareBtn = UIBarButtonItem(
            image: UIImage(systemName: "square.and.arrow.up"),
            style: .plain,
            target: self,
            action: #selector(exportTapped))
        shareBtn.tintColor = .ainaDustyRose
        navigationItem.rightBarButtonItem = shareBtn
    }

    @objc private func exportTapped() {
        let vc  = SkinLogReportPickerViewController()
        vc.allEntries = allEntries
        let nav = UINavigationController(rootViewController: vc)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    // MARK: - Search

    private func setupSearch() {
        searchController.searchResultsUpdater              = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder             = "Search entries, tags…"
        searchController.searchBar.tintColor               = .ainaCoralPink
        navigationItem.searchController                    = searchController
        navigationItem.hidesSearchBarWhenScrolling         = false
        definesPresentationContext = true
    }

    // MARK: - Table

    private func setupTable() {
        tableView.dataSource      = self
        tableView.delegate        = self
        tableView.separatorStyle  = .none
        tableView.backgroundColor = .clear
        tableView.contentInset    = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        tableView.register(
            UINib(nibName: "EntryCollectionViewCell", bundle: nil),
            forCellReuseIdentifier: "EntryCollectionViewCell"
        )

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - Empty state

    private func setupEmptyView() {
        emptyView.isHidden = true
        emptyView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyView)

        let icon = UIImageView(image: UIImage(systemName: "sparkles"))
        icon.tintColor   = UIColor.ainaDustyRose.withAlphaComponent(0.5)
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text          = "Your skin story begins here."
        titleLbl.font          = .systemFont(ofSize: 17, weight: .semibold)
        titleLbl.textColor     = .ainaTextPrimary
        titleLbl.textAlignment = .center

        let subtitleLbl = UILabel()
        subtitleLbl.text          = "Tap + Skin Report on your journal\nto add your first entry."
        subtitleLbl.font          = .systemFont(ofSize: 14)
        subtitleLbl.textColor     = .secondaryLabel
        subtitleLbl.textAlignment = .center
        subtitleLbl.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [icon, titleLbl, subtitleLbl])
        stack.axis      = .vertical
        stack.spacing   = 10
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        emptyView.addSubview(stack)

        NSLayoutConstraint.activate([
            emptyView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            emptyView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            emptyView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),

            stack.topAnchor.constraint(equalTo: emptyView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: emptyView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: emptyView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: emptyView.bottomAnchor)
        ])
    }

    // MARK: - Filter

    private func refilter() {
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            displayed = allEntries.sorted { $0.date > $1.date }
        } else {
            displayed = allEntries
                .filter { entry in
                    entry.title.lowercased().contains(q) ||
                    entry.note.lowercased().contains(q) ||
                    entry.flareUps.contains { $0.lowercased().contains(q) }
                }
                .sorted { $0.date > $1.date }
        }

        let isEmpty = displayed.isEmpty
        emptyView.isHidden  = !isEmpty
        tableView.isHidden  = isEmpty
        if !isEmpty { tableView.reloadData() }
    }
}

// MARK: - Search

extension SkinLogListViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        searchQuery = searchController.searchBar.text ?? ""
        refilter()
    }
}

// MARK: - UITableViewDataSource / Delegate

extension SkinLogListViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        displayed.count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(
            withIdentifier: "EntryCollectionViewCell", for: indexPath
        ) as! EntryCollectionViewCell
        cell.configure(skinLog: displayed[indexPath.row], showFullDate: true)
        return cell
    }

    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat { 100 }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = displayed[indexPath.row]
        let vc    = SkinLogViewController()
        vc.existingEntry = entry
        vc.onUpdate = { [weak self] updated in
            guard let self else { return }
            if let idx = self.allEntries.firstIndex(where: { $0.id == updated.id }) {
                self.allEntries[idx] = updated
            }
            self.onEntryUpdated?(updated)
            self.refilter()
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath)
    -> UISwipeActionsConfiguration? {
        let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            guard let self else { return done(false) }
            let entry = self.displayed[indexPath.row]
            self.allEntries.removeAll { $0.id == entry.id }
            self.onEntryDeleted?(entry.id)
            self.refilter()
            done(true)
        }
        action.image           = UIImage(systemName: "trash")
        action.backgroundColor = .ainaSoftRed
        return UISwipeActionsConfiguration(actions: [action])
    }
}
