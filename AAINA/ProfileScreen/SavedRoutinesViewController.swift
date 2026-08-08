import UIKit

final class SavedRoutinesViewController: UIViewController {

    private enum Section: Int, CaseIterable {
        case bookmarks
        case history

        var title: String {
            switch self {
            case .bookmarks: return "Bookmarks"
            case .history: return "Routine History"
            }
        }

        var iconName: String {
            switch self {
            case .bookmarks: return "bookmark.fill"
            case .history: return "clock.arrow.circlepath"
            }
        }

        var emptyTitle: String {
            switch self {
            case .bookmarks: return "No bookmarks yet"
            case .history: return "No routine changes yet"
            }
        }

        var emptySubtitle: String {
            switch self {
            case .bookmarks: return "Save your current routine here so you can revisit it later."
            case .history: return "New routine generations and weekly change requests will be tracked here."
            }
        }
    }

    private var routines: [SavedRoutine] = []
    private var routineHistory: [RoutineHistoryEntry] = []

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Saved Routines"
        view.applyAINABackground()
        configureNavigationBar()
        setupTableView()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadData()
    }

    private func configureNavigationBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.ainaTextPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.ainaTextPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 108
        tableView.sectionHeaderTopPadding = 12
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)

        tableView.register(SavedRoutineCell.self, forCellReuseIdentifier: SavedRoutineCell.reuseIdentifier)
        tableView.register(RoutineHistoryCell.self, forCellReuseIdentifier: RoutineHistoryCell.reuseIdentifier)
        tableView.register(EmptyStateCell.self, forCellReuseIdentifier: EmptyStateCell.reuseIdentifier)

        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func reloadData() {
        routines = AppDataModel.shared.savedRoutines.sorted { $0.createdAt > $1.createdAt }
        routineHistory = AppDataModel.shared.routineHistory.sorted { $0.changedAt > $1.changedAt }
        tableView.reloadData()
    }

    private func isSectionEmpty(_ section: Section) -> Bool {
        switch section {
        case .bookmarks: return routines.isEmpty
        case .history: return routineHistory.isEmpty
        }
    }
}

extension SavedRoutinesViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }

        switch section {
        case .bookmarks:
            return max(routines.count, 1)
        case .history:
            return max(routineHistory.count, 1)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let section = Section(rawValue: indexPath.section) else {
            return UITableViewCell()
        }

        if isSectionEmpty(section) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EmptyStateCell.reuseIdentifier,
                for: indexPath
            ) as! EmptyStateCell
            cell.configure(
                title: section.emptyTitle,
                subtitle: section.emptySubtitle,
                buttonTitle: section == .bookmarks && AppDataModel.shared.aiRoutine != nil
                    ? "Save Current Routine"
                    : nil
            )
            cell.onButtonTapped = { [weak self] in
                self?.saveCurrentRoutine()
            }
            return cell
        }

        switch section {
        case .bookmarks:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: SavedRoutineCell.reuseIdentifier,
                for: indexPath
            ) as! SavedRoutineCell
            cell.configure(with: routines[indexPath.row])
            return cell

        case .history:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: RoutineHistoryCell.reuseIdentifier,
                for: indexPath
            ) as! RoutineHistoryCell
            cell.configure(with: routineHistory[indexPath.row])
            return cell
        }
    }
}

extension SavedRoutinesViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let section = Section(rawValue: section) else { return nil }

        let count: Int
        switch section {
        case .bookmarks: count = routines.count
        case .history: count = routineHistory.count
        }

        let header = RoutineSectionHeaderView()
        header.configure(title: section.title, iconName: section.iconName, count: count)
        return header
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        52
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        10
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let section = Section(rawValue: indexPath.section), !isSectionEmpty(section) else { return }

        switch section {
        case .bookmarks:
            let routine = routines[indexPath.row]
            navigationController?.pushViewController(
                RoutineSnapshotDetailViewController(savedRoutine: routine),
                animated: true
            )

        case .history:
            let entry = routineHistory[indexPath.row]
            navigationController?.pushViewController(
                RoutineSnapshotDetailViewController(historyEntry: entry),
                animated: true
            )
        }
    }

    func tableView(
        _ tableView: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard
            Section(rawValue: indexPath.section) == .bookmarks,
            !routines.isEmpty
        else { return nil }

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            guard let self else {
                done(false)
                return
            }

            let id = self.routines[indexPath.row].id
            AppDataModel.shared.deleteSavedRoutine(id: id)
            self.reloadData()
            done(true)
        }
        delete.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [delete])
    }

    private func saveCurrentRoutine() {
        guard let currentRoutine = AppDataModel.shared.aiRoutine else { return }

        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        let name = "Routine \(formatter.string(from: Date()))"

        AppDataModel.shared.saveRoutine(named: name, from: currentRoutine)
        AppDataModel.shared.recordRoutineHistory(
            title: "Routine Bookmarked",
            summary: "Saved \(name) to bookmarks",
            detail: "\(currentRoutine.morning.count) morning steps / \(currentRoutine.evening.count) evening steps",
            previousRoutine: nil,
            newRoutine: currentRoutine
        )
        reloadData()
    }
}

private final class RoutineSectionHeaderView: UIView {

    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let countLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.16)
        iconContainer.layer.cornerRadius = 13

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.tintColor = .ainaDustyRose
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .ainaTextPrimary

        countLabel.translatesAutoresizingMaskIntoConstraints = false
        countLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        countLabel.textColor = .ainaDustyRose
        countLabel.textAlignment = .center
        countLabel.backgroundColor = UIColor.white.withAlphaComponent(0.58)
        countLabel.layer.cornerRadius = 10
        countLabel.layer.masksToBounds = true

        iconContainer.addSubview(iconView)
        addSubview(iconContainer)
        addSubview(titleLabel)
        addSubview(countLabel)

        NSLayoutConstraint.activate([
            iconContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            iconContainer.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 26),
            iconContainer.heightAnchor.constraint(equalToConstant: 26),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 14),
            iconView.heightAnchor.constraint(equalToConstant: 14),

            titleLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            countLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            countLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            countLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            countLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            countLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }

    func configure(title: String, iconName: String, count: Int) {
        titleLabel.text = title
        iconView.image = UIImage(systemName: iconName)
        countLabel.text = "\(count)"
    }
}

private final class SavedRoutineCell: UITableViewCell {

    static let reuseIdentifier = "SavedRoutineCell"

    private let cardView = UIView()
    private let iconContainer = UIView()
    private let iconView = UIImageView()
    private let nameLabel = UILabel()
    private let dateLabel = UILabel()
    private let metaLabel = UILabel()
    private let routineContentLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = .ainaGlassElevated
        cardView.layer.cornerRadius = 18
        cardView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        cardView.layer.shadowOpacity = 0.08
        cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardView.layer.shadowRadius = 14

        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.14)
        iconContainer.layer.cornerRadius = 18

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "bookmark.fill")
        iconView.tintColor = .ainaDustyRose
        iconView.contentMode = .scaleAspectFit

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .ainaTextPrimary
        nameLabel.numberOfLines = 2

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 13)
        dateLabel.textColor = .ainaTextSecondary

        metaLabel.translatesAutoresizingMaskIntoConstraints = false
        metaLabel.font = .systemFont(ofSize: 12, weight: .medium)
        metaLabel.textColor = .ainaDustyRose
        metaLabel.numberOfLines = 1

        routineContentLabel.translatesAutoresizingMaskIntoConstraints = false
        routineContentLabel.font = .systemFont(ofSize: 12)
        routineContentLabel.textColor = .ainaTextSecondary
        routineContentLabel.numberOfLines = 0

        iconContainer.addSubview(iconView)
        cardView.addSubview(iconContainer)
        cardView.addSubview(nameLabel)
        cardView.addSubview(dateLabel)
        cardView.addSubview(metaLabel)
        cardView.addSubview(routineContentLabel)
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),

            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 17),
            iconView.heightAnchor.constraint(equalToConstant: 17),

            nameLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            nameLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 5),
            dateLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            metaLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 7),
            metaLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            metaLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),

            routineContentLabel.topAnchor.constraint(equalTo: metaLabel.bottomAnchor, constant: 10),
            routineContentLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            routineContentLabel.trailingAnchor.constraint(equalTo: nameLabel.trailingAnchor),
            routineContentLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    func configure(with routine: SavedRoutine) {
        nameLabel.text = routine.name
        dateLabel.text = "Saved \(DateFormatter.routineDate.string(from: routine.createdAt))"
        metaLabel.text = "\(routine.morning.count) morning steps / \(routine.evening.count) evening steps"
        routineContentLabel.text = "Tap to view saved routine details"
        routineContentLabel.textColor = .ainaTextTertiary
    }
}

private final class RoutineHistoryCell: UITableViewCell {

    static let reuseIdentifier = "RoutineHistoryCell"

    private let cardView = UIView()
    private let timelineDot = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let summaryLabel = UILabel()
    private let detailLabel = UILabel()
    private let routineChangeLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.white.withAlphaComponent(0.62)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor

        timelineDot.translatesAutoresizingMaskIntoConstraints = false
        timelineDot.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.18)
        timelineDot.layer.cornerRadius = 16

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "sparkles")
        iconView.tintColor = .ainaDustyRose
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.numberOfLines = 2

        dateLabel.translatesAutoresizingMaskIntoConstraints = false
        dateLabel.font = .systemFont(ofSize: 12)
        dateLabel.textColor = .ainaTextTertiary

        summaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryLabel.font = .systemFont(ofSize: 13, weight: .medium)
        summaryLabel.textColor = .ainaTextSecondary
        summaryLabel.numberOfLines = 2

        detailLabel.translatesAutoresizingMaskIntoConstraints = false
        detailLabel.font = .systemFont(ofSize: 13)
        detailLabel.textColor = .ainaTextSecondary
        detailLabel.numberOfLines = 0

        routineChangeLabel.translatesAutoresizingMaskIntoConstraints = false
        routineChangeLabel.font = .systemFont(ofSize: 12)
        routineChangeLabel.textColor = .ainaTextSecondary
        routineChangeLabel.numberOfLines = 0

        timelineDot.addSubview(iconView)
        cardView.addSubview(timelineDot)
        cardView.addSubview(titleLabel)
        cardView.addSubview(dateLabel)
        cardView.addSubview(summaryLabel)
        cardView.addSubview(detailLabel)
        cardView.addSubview(routineChangeLabel)
        contentView.addSubview(cardView)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            timelineDot.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 16),
            timelineDot.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),
            timelineDot.widthAnchor.constraint(equalToConstant: 32),
            timelineDot.heightAnchor.constraint(equalToConstant: 32),

            iconView.centerXAnchor.constraint(equalTo: timelineDot.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: timelineDot.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 15),
            iconView.heightAnchor.constraint(equalToConstant: 15),

            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 15),
            titleLabel.leadingAnchor.constraint(equalTo: timelineDot.trailingAnchor, constant: 13),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -16),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            dateLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            dateLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            summaryLabel.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 10),
            summaryLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            summaryLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            detailLabel.topAnchor.constraint(equalTo: summaryLabel.bottomAnchor, constant: 5),
            detailLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),

            routineChangeLabel.topAnchor.constraint(equalTo: detailLabel.bottomAnchor, constant: 10),
            routineChangeLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            routineChangeLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            routineChangeLabel.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16)
        ])
    }

    func configure(with entry: RoutineHistoryEntry) {
        titleLabel.text = entry.title
        dateLabel.text = DateFormatter.routineDateTime.string(from: entry.changedAt)
        summaryLabel.text = entry.summary
        detailLabel.text = entry.detail.map { "Why: \($0)" }
        detailLabel.isHidden = (entry.detail ?? "").isEmpty
        routineChangeLabel.text = "Tap to view routine change details"
        routineChangeLabel.textColor = .ainaTextTertiary
        routineChangeLabel.isHidden = false
    }
}

private final class EmptyStateCell: UITableViewCell {

    static let reuseIdentifier = "EmptyStateCell"

    private let cardView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private var actionButtonTopConstraint: NSLayoutConstraint?
    private var actionButtonHeightConstraint: NSLayoutConstraint?
    var onButtonTapped: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.10)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.image = UIImage(systemName: "tray")
        iconView.tintColor = .ainaDustyRose
        iconView.contentMode = .scaleAspectFit

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = .ainaTextSecondary
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.backgroundColor = .ainaCoralPink
        actionButton.tintColor = .white
        actionButton.layer.cornerRadius = 16
        actionButton.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        actionButton.setValue(NSValue(uiEdgeInsets: UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)), forKey: "contentEdgeInsets")
        actionButton.addTarget(self, action: #selector(buttonTapped), for: .touchUpInside)

        cardView.addSubview(iconView)
        cardView.addSubview(titleLabel)
        cardView.addSubview(subtitleLabel)
        cardView.addSubview(actionButton)
        contentView.addSubview(cardView)

        actionButtonTopConstraint = actionButton.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 14)
        actionButtonHeightConstraint = actionButton.heightAnchor.constraint(equalToConstant: 34)

        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 6),
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -6),

            iconView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 18),
            iconView.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),

            actionButtonTopConstraint!,
            actionButton.centerXAnchor.constraint(equalTo: cardView.centerXAnchor),
            actionButtonHeightConstraint!,
            actionButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -18)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onButtonTapped = nil
    }

    func configure(title: String, subtitle: String, buttonTitle: String?) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        actionButton.setTitle(buttonTitle, for: .normal)
        let hasButton = buttonTitle != nil
        actionButton.isHidden = !hasButton
        actionButtonTopConstraint?.constant = hasButton ? 14 : 0
        actionButtonHeightConstraint?.constant = hasButton ? 34 : 0
    }

    @objc private func buttonTapped() {
        onButtonTapped?()
    }
}

private final class RoutineSnapshotDetailViewController: UIViewController {

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let screenTitle: String
    private let subtitle: String
    private let sections: [(title: String, body: String)]

    init(savedRoutine: SavedRoutine) {
        screenTitle = savedRoutine.name
        subtitle = "Saved \(DateFormatter.routineDateTime.string(from: savedRoutine.createdAt))"
        sections = [
            (
                title: "Morning Routine",
                body: RoutineTextFormatter.routineBlock(title: nil, steps: savedRoutine.morning)
            ),
            (
                title: "Evening Routine",
                body: RoutineTextFormatter.routineBlock(title: nil, steps: savedRoutine.evening)
            )
        ].filter { !$0.body.isEmpty }
        super.init(nibName: nil, bundle: nil)
    }

    init(historyEntry: RoutineHistoryEntry) {
        screenTitle = historyEntry.title
        subtitle = DateFormatter.routineDateTime.string(from: historyEntry.changedAt)

        var builtSections: [(title: String, body: String)] = [
            (title: "Why It Changed", body: historyEntry.detail ?? "No reason added."),
            (title: "Summary", body: historyEntry.summary)
        ]

        if let previous = historyEntry.previousRoutine {
            builtSections.append((
                title: historyEntry.newRoutine == nil ? "Routine At Request" : "Previous Routine",
                body: RoutineTextFormatter.compactRoutine(previous)
            ))
        }

        if let new = historyEntry.newRoutine {
            builtSections.append((
                title: historyEntry.previousRoutine == nil ? "Routine Content" : "Changed Into",
                body: RoutineTextFormatter.compactRoutine(new)
            ))
        } else if historyEntry.previousRoutine != nil {
            builtSections.append((title: "Changed Into", body: "Pending new routine"))
        }

        if let previous = historyEntry.previousRoutine, let new = historyEntry.newRoutine {
            builtSections.append((
                title: "Content Change",
                body: RoutineTextFormatter.changedStepsSummary(previous: previous, new: new)
            ))
        }

        sections = builtSections.filter { !$0.body.isEmpty }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Routine Details"
        view.applyAINABackground()
        configureNavigationBar()
        setupScrollView()
        buildContent()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
    }

    private func configureNavigationBar() {
        navigationController?.navigationBar.tintColor = .ainaTextPrimary
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.ainaTextPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        view.addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -28),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    private func buildContent() {
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.numberOfLines = 0
        titleLabel.text = screenTitle

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = .ainaTextSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.text = subtitle

        stackView.addArrangedSubview(titleLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(24, after: subtitleLabel)

        sections.forEach { section in
            stackView.addArrangedSubview(makeCard(title: section.title, body: section.body))
        }
    }

    private func makeCard(title: String, body: String) -> UIView {
        let card = UIView()
        card.backgroundColor = .ainaGlassElevated
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        card.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.08
        card.layer.shadowOffset = CGSize(width: 0, height: 6)
        card.layer.shadowRadius = 14

        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.numberOfLines = 0
        titleLabel.text = title

        let bodyLabel = UILabel()
        bodyLabel.font = .systemFont(ofSize: 13)
        bodyLabel.textColor = .ainaTextSecondary
        bodyLabel.numberOfLines = 0
        bodyLabel.text = body

        let innerStack = UIStackView(arrangedSubviews: [titleLabel, bodyLabel])
        innerStack.axis = .vertical
        innerStack.spacing = 10
        innerStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(innerStack)

        NSLayoutConstraint.activate([
            innerStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            innerStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            innerStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            innerStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        return card
    }
}

private enum RoutineTextFormatter {

    static func savedRoutineContent(morning: [AIRoutineStep], evening: [AIRoutineStep]) -> String {
        [
            routineBlock(title: "Morning", steps: morning),
            routineBlock(title: "Evening", steps: evening)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
    }

    static func historyContent(previous: AIRoutineOutput?, new: AIRoutineOutput?) -> String {
        switch (previous, new) {
        case let (previous?, new?):
            return [
                "Previous routine",
                compactRoutine(previous),
                "",
                "Changed into",
                compactRoutine(new),
                "",
                changedStepsSummary(previous: previous, new: new)
            ]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        case let (previous?, nil):
            return [
                "Routine at the time of request",
                compactRoutine(previous),
                "Changed into: pending new routine"
            ].joined(separator: "\n")

        case let (nil, new?):
            return [
                "Saved routine content",
                compactRoutine(new)
            ].joined(separator: "\n")

        default:
            return ""
        }
    }

    static func routineBlock(title: String?, steps: [AIRoutineStep]) -> String {
        guard !steps.isEmpty else { return "" }
        let lines = steps
            .sorted { $0.stepNumber < $1.stepNumber }
            .map { step in
                let ingredients = step.keyIngredients.isEmpty
                    ? ""
                    : " (\(step.keyIngredients.prefix(3).joined(separator: ", ")))"
                return "\(step.stepNumber). \(step.productType.rawValue.capitalized): \(step.productName)\(ingredients)"
            }
        if let title {
            return ([title] + lines).joined(separator: "\n")
        }
        return lines.joined(separator: "\n")
    }

    static func compactRoutine(_ routine: AIRoutineOutput) -> String {
        savedRoutineContent(morning: routine.morning, evening: routine.evening)
    }

    static func changedStepsSummary(previous: AIRoutineOutput, new: AIRoutineOutput) -> String {
        let previousNames = Set((previous.morning + previous.evening).map { normalizedStepName($0) })
        let newNames = Set((new.morning + new.evening).map { normalizedStepName($0) })

        let added = newNames.subtracting(previousNames).sorted()
        let removed = previousNames.subtracting(newNames).sorted()

        guard !added.isEmpty || !removed.isEmpty else {
            return "Content change: steps were regenerated with the same product names."
        }

        var lines: [String] = ["Content change"]
        if !removed.isEmpty {
            lines.append("Removed: \(removed.joined(separator: ", "))")
        }
        if !added.isEmpty {
            lines.append("Added: \(added.joined(separator: ", "))")
        }
        return lines.joined(separator: "\n")
    }

    private static func normalizedStepName(_ step: AIRoutineStep) -> String {
        "\(step.productType.rawValue.capitalized): \(step.productName)"
    }
}

private extension DateFormatter {
    static let routineDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    static let routineDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, h:mm a"
        return formatter
    }()
}
