//
//  JournalViewController.swift
//  JournalUI
//

import UIKit
import EventKit
import UserNotifications

class JournalViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var buttonStack: UIStackView!
    @IBOutlet weak var skinLogButton: UIButton!
    @IBOutlet weak var reminderButton: UIButton!
    @IBOutlet weak var myNotesButton: UIButton!

    // MARK: - Reminder store
    let eventStore = EKEventStore()
    private var allReminders: [EKEvent] = []
    var reminders: [EKEvent] = []

    // MARK: - Timeline data
    private var timelineStartDate: Date = Date()
    private var dates: [String] = []
    private var days: [String] = []
    var selectedIndex: Int = 0
    var todayIndex: Int = 0

    // MARK: - Journal entries
    private var allJournalEntries: [JournalEntry] = []
    var journalEntries: [JournalEntry] = []

    // MARK: - Skin report entries
    private var allSkinLogEntries: [SkinLogEntry] = []
    var skinLogEntries: [SkinLogEntry] = []

    // MARK: - See More / See Less state
    private let maxVisibleRows = 2
    private var remindersExpanded = false
    private var entriesExpanded = false
    private var skinLogExpanded = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        loadPersistedData()

        view.applyAINABackground()
        setupNavigationBar()
        setupButtons()
        setupCollectionView()
        setupLayout()
        generateTimelineDates()
        collectionView.reloadData()
        setupTableView()
        refreshRemoteEntries()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        title = "Journal"
        navigationController?.setNavigationBarHidden(false, animated: animated)
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always
        filterRemindersForSelectedDate()
        filterEntriesForSelectedDate()
        filterSkinLogForSelectedDate()
        tableView.reloadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
        scrollTimelineToSelected(animated: false)
        sizeTableHeaderView()
    }

    private func refreshRemoteEntries() {
        Task {
            guard FirestoreSyncService.shared.currentUserID != nil else { return }
            guard let state = try? await FirestoreSyncService.shared.loadUserState() else { return }
            await MainActor.run {
                self.allJournalEntries = state.journalEntries
                self.saveEntries()
                self.allSkinLogEntries = state.skinLogEntries
                self.saveSkinLogEntries()
                self.filterEntriesForSelectedDate()
                self.filterSkinLogForSelectedDate()
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Buttons
    private func setupButtons() {
        applyGlassConfig(to: skinLogButton, title: " Skin Report", icon: "waveform.path.ecg.text.clipboard")
        applyGlassConfig(to: reminderButton, title: " Reminder", icon: "bell")
        applyGlassConfig(to: myNotesButton, title: " My Notes", icon: "note.text")
    }

    private func applyGlassConfig(to button: UIButton, title: String, icon: String) {
        var config = UIButton.Configuration.glass()
        config.title = title
        config.image = UIImage(systemName: icon)
        config.imagePadding = 8
        config.cornerStyle = .capsule
        button.configuration = config
    }

    // MARK: - Navigation bar
    private func setupNavigationBar() {
        title = "Journal"
        navigationController?.navigationBar.prefersLargeTitles = true
        navigationItem.largeTitleDisplayMode = .always

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: UIColor.ainaTextPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.ainaTextPrimary]
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance

        let calendarButton = UIBarButtonItem(
            image: UIImage(systemName: "calendar"),
            style: .plain,
            target: self,
            action: #selector(calendarTapped)
        )
        calendarButton.tintColor = .label
        navigationItem.rightBarButtonItem = calendarButton
    }

    @objc private func calendarTapped() {
        // Guard: only present if this VC is currently visible
        guard viewIfLoaded?.window != nil else { return }
        
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .inline
        picker.tintColor = .ainaCoralPink

        guard let selectedDate = Calendar.current.date(byAdding: .day, value: selectedIndex, to: timelineStartDate)
        else { return }
        picker.date = selectedDate

        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.view.addSubview(picker)
        picker.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: sheet.view.topAnchor, constant: 8),
            picker.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor),
        ])
        let height: CGFloat = 360
        sheet.view.heightAnchor.constraint(equalToConstant: height + 80).isActive = true

        sheet.addAction(UIAlertAction(title: "Done", style: .cancel) { [weak self] _ in
            self?.jumpToDate(picker.date)
        })
        present(sheet, animated: true)
    }

    private func jumpToDate(_ date: Date) {
        let calendar = Calendar.current
        let startOfSelected = calendar.startOfDay(for: date)
        let diff = calendar.dateComponents([.day], from: timelineStartDate, to: startOfSelected).day ?? 0
        guard diff >= 0, diff < dates.count else { return }

        let previous = selectedIndex
        selectedIndex = diff
        var toReload = [IndexPath(item: selectedIndex, section: 0)]
        if previous != selectedIndex { toReload.append(IndexPath(item: previous, section: 0)) }
        collectionView.reloadItems(at: toReload)
        scrollTimelineToSelected(animated: true)
        filterRemindersForSelectedDate()
        filterEntriesForSelectedDate()
        filterSkinLogForSelectedDate()
        tableView.reloadData()
    }

    // MARK: - Actions

    @IBAction func addSkinLogTapped(_ sender: Any) {
        let vc = SkinLogViewController()
        vc.onSave = { [weak self] entry in
            guard let self else { return }
            self.allSkinLogEntries.insert(entry, at: 0)
            self.saveSkinLogEntries()
            FirestoreSyncService.shared.saveSkinLogEntry(entry)
            self.filterSkinLogForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func addMyNotesTapped(_ sender: Any) {
        let vc = JournalEntryViewController()
        vc.onSave = { [weak self] entry in
            guard let self else { return }
            self.allJournalEntries.insert(entry, at: 0)
            self.saveEntries()
            FirestoreSyncService.shared.saveJournalEntry(entry)
            self.filterEntriesForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @IBAction func addReminderTapped(_ sender: UIButton) {
        let addVC = AddReminderViewController()
        addVC.onSave = { [weak self] title, date in
            guard let self else { return }

            let startOfToday = Calendar.current.startOfDay(for: Date())
            guard date >= startOfToday else {
                let alert = UIAlertController(
                    title: "Invalid Date",
                    message: "Reminders can only be set for today or a future date.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title     = title
            event.startDate = date
            event.endDate   = date.addingTimeInterval(3600)

            self.scheduleNotification(for: event)
            self.allReminders.append(event)
            self.saveReminders()
            self.filterRemindersForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
        }

        let nav = UINavigationController(rootViewController: addVC)
        nav.modalPresentationStyle = .formSheet
        present(nav, animated: true)
    }

    // MARK: - Date filtering

    private func date(forIndex index: Int) -> Date? {
        Calendar.current.date(byAdding: .day, value: index, to: timelineStartDate)
    }

    private func filterEntriesForSelectedDate() {
        guard let selectedDate = date(forIndex: selectedIndex) else {
            journalEntries = allJournalEntries
            return
        }
        let calendar = Calendar.current
        journalEntries = allJournalEntries.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        entriesExpanded = false
    }

    private func filterSkinLogForSelectedDate() {
        guard let selectedDate = date(forIndex: selectedIndex) else {
            skinLogEntries = allSkinLogEntries
            return
        }
        let calendar = Calendar.current
        skinLogEntries = allSkinLogEntries.filter {
            calendar.isDate($0.date, inSameDayAs: selectedDate)
        }
        skinLogExpanded = false
    }

    private func filterRemindersForSelectedDate() {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)

        let sorted = allReminders
            .filter { $0.startDate != nil }
            .sorted { $0.startDate! < $1.startDate! }

        guard let selectedDate = date(forIndex: selectedIndex) else {
            reminders = sorted.filter { $0.startDate! >= startOfToday }
            remindersExpanded = false
            return
        }

        if calendar.isDateInToday(selectedDate) {
            // Show all upcoming (today + future), sorted
            reminders = sorted.filter { $0.startDate! >= startOfToday }
        } else {
            // Show only reminders on that specific day
            reminders = sorted.filter { calendar.isDate($0.startDate!, inSameDayAs: selectedDate) }
        }
        remindersExpanded = false
    }

    // MARK: - Timeline generation
    private func generateTimelineDates() {
        dates.removeAll()
        days.removeAll()

        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1

        guard let thisSunday = calendar.date(
            byAdding: .day, value: -daysFromSunday, to: calendar.startOfDay(for: today)
        ) else { return }

        let weeksBack = 104   // 2 years of history
        let weeksForward = 12 // 3 months ahead

        guard let start = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: thisSunday)
        else { return }
        timelineStartDate = start

        let formatterDate = DateFormatter()
        formatterDate.dateFormat = "dd"
        let formatterDay = DateFormatter()
        formatterDay.dateFormat = "EEEEE"

        let totalDays = 7 * (weeksBack + weeksForward)
        for offset in 0..<totalDays {
            if let d = calendar.date(byAdding: .day, value: offset, to: start) {
                dates.append(formatterDate.string(from: d))
                days.append(formatterDay.string(from: d))
            }
        }

        todayIndex = weeksBack * 7 + daysFromSunday
        selectedIndex = todayIndex
    }

    // MARK: - Scroll helper
    private func scrollTimelineToSelected(animated: Bool) {
        let idx = IndexPath(item: selectedIndex, section: 0)
        guard selectedIndex < dates.count else { return }
        collectionView.scrollToItem(at: idx, at: .centeredHorizontally, animated: animated)
    }

    // MARK: - Collection setup
    private func setupCollectionView() {
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = false
        collectionView.backgroundColor = .clear

        collectionView.register(
            UINib(nibName: "TimelineCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier
        )
    }

    // MARK: - Table setup
    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.backgroundColor = .clear
        tableView.alwaysBounceVertical = true
        tableView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 24, right: 0)

        tableView.register(UINib(nibName: "ReminderTableViewCell", bundle: nil), forCellReuseIdentifier: "ReminderTableViewCell")
        tableView.register(UINib(nibName: "EntryCollectionViewCell", bundle: nil), forCellReuseIdentifier: "EntryCollectionViewCell")
        tableView.register(EmptyStateInfoCell.self, forCellReuseIdentifier: EmptyStateInfoCell.reuseIdentifier)

        installButtonStackAsTableHeader()
    }

    // Move the storyboard button stack into the table's header so it scrolls
    // with the journal content instead of staying pinned below the timeline.
    private func installButtonStackAsTableHeader() {
        buttonStack.removeFromSuperview()

        let header = UIView()
        header.backgroundColor = .clear
        header.addSubview(buttonStack)
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            buttonStack.topAnchor.constraint(equalTo: header.topAnchor, constant: 12),
            buttonStack.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: -16),
            buttonStack.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 16),
            buttonStack.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -16)
        ])

        tableView.tableHeaderView = header
        sizeTableHeaderView()
    }

    private func sizeTableHeaderView() {
        guard let header = tableView.tableHeaderView else { return }
        let width = tableView.bounds.width > 0 ? tableView.bounds.width : view.bounds.width
        header.frame = CGRect(x: 0, y: 0, width: width, height: 0)
        let size = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel
        )
        if abs(header.frame.height - size.height) > 0.5 {
            header.frame = CGRect(x: 0, y: 0, width: width, height: size.height)
            tableView.tableHeaderView = header
        }
    }

    // MARK: - Empty state helpers
    private func isSectionEmpty(_ section: Int) -> Bool {
        switch section {
        case 0:  return skinLogEntries.isEmpty
        case 1:  return reminders.isEmpty
        default: return journalEntries.isEmpty
        }
    }

    // MARK: - Layout
    private func setupLayout() {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            return self.generateTimelineSection()
        }
        collectionView.collectionViewLayout = layout
    }

    // MARK: - See More / See Less helpers
    // Section mapping: 0 = Skin Report, 1 = Reminders, 2 = My Notes
    private func visibleCount(for section: Int) -> Int {
        switch section {
        case 0:  return skinLogExpanded    ? skinLogEntries.count  : min(skinLogEntries.count, maxVisibleRows)
        case 1:  return remindersExpanded  ? reminders.count       : min(reminders.count, maxVisibleRows)
        default: return entriesExpanded    ? journalEntries.count  : min(journalEntries.count, maxVisibleRows)
        }
    }

    private func needsToggleButton(for section: Int) -> Bool {
        switch section {
        case 0:  return skinLogEntries.count > maxVisibleRows
        case 1:  return reminders.count > maxVisibleRows
        default: return journalEntries.count > maxVisibleRows
        }
    }

    @objc private func seeMoreTapped(_ sender: UIButton) {
        remindersExpanded.toggle()
        tableView.reloadSections(IndexSet(integer: 1), with: .automatic)
    }

    @objc private func seeAllSkinLogTapped() {
        let vc = SkinLogListViewController()
        vc.allEntries = allSkinLogEntries
        vc.onEntryUpdated = { [weak self] updated in
            guard let self else { return }
            if let idx = self.allSkinLogEntries.firstIndex(where: { $0.id == updated.id }) {
                self.allSkinLogEntries[idx] = updated
                self.saveSkinLogEntries()
                FirestoreSyncService.shared.saveSkinLogEntry(updated)
            }
            self.filterSkinLogForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
        vc.onEntryDeleted = { [weak self] id in
            guard let self else { return }
            self.allSkinLogEntries.removeAll { $0.id == id }
            self.saveSkinLogEntries()
            FirestoreSyncService.shared.deleteSkinLogEntry(id: id)
            self.filterSkinLogForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    @objc private func seeAllNotesTapped() {
        let vc = NotesListViewController()
        vc.allEntries = allJournalEntries
        vc.onEntryUpdated = { [weak self] updated in
            guard let self else { return }
            if let idx = self.allJournalEntries.firstIndex(where: { $0.id == updated.id }) {
                self.allJournalEntries[idx] = updated
                self.saveEntries()
                FirestoreSyncService.shared.saveJournalEntry(updated)
            }
            self.filterEntriesForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }
        vc.onEntryDeleted = { [weak self] id in
            guard let self else { return }
            self.allJournalEntries.removeAll { $0.id == id }
            self.saveEntries()
            FirestoreSyncService.shared.deleteJournalEntry(id: id)
            self.filterEntriesForSelectedDate()
            self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
        }
        navigationController?.pushViewController(vc, animated: true)
    }

    private func makeFooter(title: String, chevron: Bool, action: Selector, tag: Int = 0) -> UIView {
        let footer = UIView()
        footer.backgroundColor = .clear

        var cfg = UIButton.Configuration.plain()
        cfg.baseForegroundColor = .ainaDustyRose
        cfg.background.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.10)
        cfg.background.cornerRadius = 14
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 7, leading: 16, bottom: 7, trailing: chevron ? 12 : 16)
        cfg.attributedTitle = AttributedString(title, attributes: AttributeContainer([
            .font: UIFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: UIColor.ainaDustyRose
        ]))
        if chevron {
            cfg.image = UIImage(systemName: "chevron.right",
                                withConfiguration: UIImage.SymbolConfiguration(scale: .small))
            cfg.imagePlacement = .trailing
            cfg.imagePadding   = 5
        }
        let button = UIButton(configuration: cfg)
        button.tag = tag
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(button)
        NSLayoutConstraint.activate([
            button.trailingAnchor.constraint(equalTo: footer.trailingAnchor, constant: -20),
            button.centerYAnchor.constraint(equalTo: footer.centerYAnchor)
        ])
        return footer
    }
}

// MARK: - Collection View (timeline only)
extension JournalViewController: UICollectionViewDataSource, UICollectionViewDelegate {

    func numberOfSections(in collectionView: UICollectionView) -> Int { 1 }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return dates.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! TimelineCollectionViewCell

        cell.configure(
            day: days[indexPath.item],
            date: dates[indexPath.item],
            isToday: indexPath.item == todayIndex,
            isSelected: indexPath.item == selectedIndex
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let previous = selectedIndex
        selectedIndex = indexPath.item

        var toReload = [IndexPath(item: selectedIndex, section: 0)]
        if previous != selectedIndex {
            toReload.append(IndexPath(item: previous, section: 0))
        }
        collectionView.reloadItems(at: toReload)
        scrollTimelineToSelected(animated: true)
        filterRemindersForSelectedDate()
        filterEntriesForSelectedDate()
        filterSkinLogForSelectedDate()
        tableView.reloadData()
    }
}

// MARK: - Table View (reminders + entries)
extension JournalViewController: UITableViewDataSource, UITableViewDelegate {

    func numberOfSections(in tableView: UITableView) -> Int { 3 }

    func tableView(_ tableView: UITableView,
                   numberOfRowsInSection section: Int) -> Int {
        let count = visibleCount(for: section)
        return count == 0 ? 1 : count
    }

    func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Section 0 = Skin Report, 1 = Reminders, 2 = My Notes
        if isSectionEmpty(indexPath.section) {
            let cell = tableView.dequeueReusableCell(
                withIdentifier: EmptyStateInfoCell.reuseIdentifier, for: indexPath
            ) as! EmptyStateInfoCell
            switch indexPath.section {
            case 0:
                cell.configure(
                    icon: "waveform.path.ecg.text.clipboard",
                    title: "No skin report for today",
                    subtitle: "Save entry to make a consultation skin report for dermatologist."
                )
            case 1:
                cell.configure(
                    icon: "bell.fill",
                    title: "No reminders set",
                    subtitle: "Add a reminder to stay on top of your routine and check-ins."
                )
            default:
                cell.configure(
                    icon: "note.text",
                    title: "No notes for today",
                    subtitle: "Jot down thoughts on products, triggers, or how your skin feels."
                )
            }
            return cell
        }

        switch indexPath.section {
        case 0:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "EntryCollectionViewCell", for: indexPath
            ) as! EntryCollectionViewCell
            cell.configure(skinLog: skinLogEntries[indexPath.row])
            return cell
        case 1:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "ReminderTableViewCell", for: indexPath
            ) as! ReminderTableViewCell
            cell.configure(with: reminders[indexPath.row])
            return cell
        default:
            let cell = tableView.dequeueReusableCell(
                withIdentifier: "EntryCollectionViewCell", for: indexPath
            ) as! EntryCollectionViewCell
            cell.configure(entry: journalEntries[indexPath.row])
            return cell
        }
    }

    func tableView(_ tableView: UITableView,
                   viewForHeaderInSection section: Int) -> UIView? {
        let header = Bundle.main.loadNibNamed("SectionHeaderView", owner: nil)?.first as! SectionHeaderView
        switch section {
        case 0: header.configure(title: "Skin Report", subtitle: selectedDateLabel())
        case 1: header.configure(title: "Reminders", subtitle: remindersHeaderSubtitle())
        default: header.configure(title: "My Notes", subtitle: selectedDateLabel())
        }
        return header
    }

    private func remindersHeaderSubtitle() -> String {
        guard let selectedDate = date(forIndex: selectedIndex) else {
            return reminders.isEmpty ? "No upcoming reminders" : "All upcoming"
        }
        if Calendar.current.isDateInToday(selectedDate) {
            return reminders.isEmpty ? "No upcoming reminders" : "All upcoming"
        }
        // Specific date selected
        if reminders.isEmpty { return "No reminders on this day" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, d MMM"
        return fmt.string(from: selectedDate)
    }

    private func selectedDateLabel() -> String {
        guard let date = date(forIndex: selectedIndex) else { return "" }
        if Calendar.current.isDateInToday(date) { return "Today" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, d MMM"
        return fmt.string(from: date)
    }

    func tableView(_ tableView: UITableView,
                   heightForHeaderInSection section: Int) -> CGFloat { 60 }

    // MARK: - Footer
    func tableView(_ tableView: UITableView,
                   viewForFooterInSection section: Int) -> UIView? {
        switch section {
        case 0:
            return makeFooter(title: "See all reports", chevron: true,
                              action: #selector(seeAllSkinLogTapped))
        case 1:
            guard needsToggleButton(for: section) else { return nil }
            let title = remindersExpanded ? "Show less" : "See more"
            return makeFooter(title: title, chevron: false,
                              action: #selector(seeMoreTapped(_:)), tag: section)
        default:
            return makeFooter(title: "See all notes", chevron: true,
                              action: #selector(seeAllNotesTapped))
        }
    }

    func tableView(_ tableView: UITableView,
                   heightForFooterInSection section: Int) -> CGFloat {
        switch section {
        case 0:  return 44
        case 1:  return needsToggleButton(for: section) ? 44 : 0
        default: return 44
        }
    }

    func tableView(_ tableView: UITableView,
                   heightForRowAt indexPath: IndexPath) -> CGFloat {
        if isSectionEmpty(indexPath.section) { return 96 }
        return indexPath.section == 1 ? 88 : 100  // Reminders are shorter
    }

    // Swipe left → Delete
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        if isSectionEmpty(indexPath.section) { return nil }
        let action = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, done in
            guard let self else { return done(false) }
            // Section 0 = Skin Report, 1 = Reminders, 2 = My Notes
            switch indexPath.section {
            case 0:
                let removed = self.skinLogEntries.remove(at: indexPath.row)
                self.allSkinLogEntries.removeAll { $0.id == removed.id }
                self.saveSkinLogEntries()
                FirestoreSyncService.shared.deleteSkinLogEntry(id: removed.id)
                if self.skinLogEntries.count <= self.maxVisibleRows { self.skinLogExpanded = false }
            case 1:
                let removed = self.reminders.remove(at: indexPath.row)
                self.cancelNotification(for: removed)
                self.allReminders.removeAll { $0 === removed }
                self.saveReminders()
                if self.reminders.count <= self.maxVisibleRows { self.remindersExpanded = false }
            default:
                let removed = self.journalEntries.remove(at: indexPath.row)
                self.allJournalEntries.removeAll { $0.id == removed.id }
                self.saveEntries()
                FirestoreSyncService.shared.deleteJournalEntry(id: removed.id)
                if self.journalEntries.count <= self.maxVisibleRows { self.entriesExpanded = false }
            }
            tableView.performBatchUpdates({
                tableView.deleteRows(at: [indexPath], with: .automatic)
            }, completion: { _ in
                tableView.reloadSections(IndexSet(integer: indexPath.section), with: .none)
            })
            done(true)
        }
        action.image = UIImage(systemName: "trash")
        action.backgroundColor = .ainaSoftRed
        return UISwipeActionsConfiguration(actions: [action])
    }

    // Tap entry -> show notes / edit skin report
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isSectionEmpty(indexPath.section) { return }
        if indexPath.section == 0 {
            let entry = skinLogEntries[indexPath.row]
            let vc = SkinLogViewController()
            vc.existingEntry = entry
            vc.onUpdate = { [weak self] updated in
                guard let self else { return }
                if let idx = self.allSkinLogEntries.firstIndex(where: { $0.id == updated.id }) {
                    self.allSkinLogEntries[idx] = updated
                    self.saveSkinLogEntries()
                    FirestoreSyncService.shared.saveSkinLogEntry(updated)
                    self.filterSkinLogForSelectedDate()
                    self.tableView.reloadSections(IndexSet(integer: 0), with: .automatic)
                }
            }
            navigationController?.pushViewController(vc, animated: true)
        } else if indexPath.section == 2 {
            let entry = journalEntries[indexPath.row]
            let vc = NotesEditorViewController()
            vc.entry = entry
            vc.onUpdate = { [weak self] updated in
                guard let self else { return }
                if let idx = self.allJournalEntries.firstIndex(where: { $0.id == updated.id }) {
                    self.allJournalEntries[idx] = updated
                    self.saveEntries()
                    FirestoreSyncService.shared.saveJournalEntry(updated)
                    self.filterEntriesForSelectedDate()
                    self.tableView.reloadSections(IndexSet(integer: 2), with: .automatic)
                }
            }
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func exportSkinLogAsPDF(_ entry: SkinLogEntry) {
        let sheet = UIAlertController(title: "Skin Report", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Export as PDF", style: .default) { [weak self] _ in
            guard let self else { return }
            let pdf = SkinLogPDFExporter.generate(from: entry)
            let av  = UIActivityViewController(activityItems: [pdf], applicationActivities: nil)
            self.present(av, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

}

// MARK: - Timeline layout section
extension JournalViewController {

    func generateTimelineSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / 7.0),
            heightDimension: .fractionalHeight(1.0)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 4)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(88)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .groupPaging
        section.contentInsets = .zero
        return section
    }
}


// MARK: - Notifications
extension JournalViewController {

    private func notificationID(for event: EKEvent) -> String {
        let ts = event.startDate.map { String($0.timeIntervalSince1970) } ?? "0"
        return "reminder_\(event.title ?? "")_\(ts)"
    }

    func scheduleNotification(for event: EKEvent) {
        guard let startDate = event.startDate, startDate > Date().addingTimeInterval(-60) else { return }

        let content = UNMutableNotificationContent()
        content.title = event.title ?? "Reminder"
        content.body = "You have a reminder scheduled."
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: startDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: notificationID(for: event),
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for event: EKEvent) {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [notificationID(for: event)])
    }
}

// MARK: - Persistence
extension JournalViewController {

    // Lightweight codable mirror of EKEvent (only fields we need)
    private struct PersistedReminder: Codable {
        let title: String
        let startDate: Date
    }

    // In DEBUG the files are written directly into the project's Model folder
    // so they appear in Xcode alongside data.json.
    // In Release they live in the app's sandboxed Documents directory.
    private static var modelDirectory: URL {
        #if DEBUG
        return URL(fileURLWithPath: #file)   // …/Journal/JournalViewController.swift
            .deletingLastPathComponent()      // …/Journal/
            .deletingLastPathComponent()      // …/skinCare/
            .appendingPathComponent("Model")  // …/Model/
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        #endif
    }

    private static var entriesFileURL: URL {
        modelDirectory.appendingPathComponent("journal_entries.json")
    }

    private static var remindersFileURL: URL {
        modelDirectory.appendingPathComponent("journal_reminders.json")
    }

    private static var skinLogFileURL: URL {
        modelDirectory.appendingPathComponent("skin_log_entries.json")
    }

    func saveEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(allJournalEntries) {
            try? data.write(to: Self.entriesFileURL)
        }
    }

    func saveSkinLogEntries() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(allSkinLogEntries) {
            try? data.write(to: Self.skinLogFileURL)
        }
    }

    func saveReminders() {
        let persisted = allReminders.compactMap { event -> PersistedReminder? in
            guard let date = event.startDate else { return nil }
            return PersistedReminder(title: event.title ?? "", startDate: date)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(persisted) {
            try? data.write(to: Self.remindersFileURL)
        }
    }

    private func loadPersistedData() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // Load entries
        if let data = try? Data(contentsOf: Self.entriesFileURL),
           let entries = try? decoder.decode([JournalEntry].self, from: data) {
            allJournalEntries = entries
        }

        // Load skin report entries
        if let data = try? Data(contentsOf: Self.skinLogFileURL),
           let entries = try? decoder.decode([SkinLogEntry].self, from: data) {
            allSkinLogEntries = entries
        }

        // Load reminders — reconstruct EKEvent objects from stored data
        if let data = try? Data(contentsOf: Self.remindersFileURL),
           let persisted = try? decoder.decode([PersistedReminder].self, from: data) {
            allReminders = persisted.map { p in
                let event = EKEvent(eventStore: eventStore)
                event.title = p.title
                event.startDate = p.startDate
                event.endDate = p.startDate.addingTimeInterval(3600)
                return event
            }
        }
    }
}
