import UIKit

final class InsightViewController: UIViewController {
    enum Mode {
        case face
        case weekly
    }

    private let store = InsightStore.shared
    private var entries: [InsightEntry] = []
    private var timelineDates: [Date] = []
    private var selectedDate = Date()
    private var selectedMode: Mode = .face
    var initialSelectedDate: Date?

    private let topBar = UIView()
    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let calendarButton = UIButton(type: .system)
    private let timelineCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private let segmentedStack = UIStackView()
    private let faceButton = UIButton(type: .system)
    private let weeklyButton = UIButton(type: .system)
    private let contentCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationController?.setNavigationBarHidden(true, animated: false)
        view.backgroundColor = .white
        view.applyAINABackground()
        entries = store.allEntries()
        let today = Calendar.current.startOfDay(for: Date())
        let initialDate = Calendar.current.startOfDay(for: initialSelectedDate ?? Date())
        selectedDate = min(initialDate, today)
        buildTimeline()
        setupTopBar()
        setupTimeline()
        setupSegmentedButtons()
        setupContentCollection()
        updateSegmentedButtons()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
        timelineCollectionView.collectionViewLayout.invalidateLayout()
        contentCollectionView.collectionViewLayout.invalidateLayout()
    }

    private func setupTopBar() {
        [topBar, backButton, titleLabel, calendarButton].forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        view.addSubview(topBar)
        topBar.addSubview(backButton)
        topBar.addSubview(titleLabel)
        topBar.addSubview(calendarButton)

        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        backButton.layer.cornerRadius = 22
        backButton.layer.cornerCurve = .continuous
        backButton.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        backButton.tintColor = .ainaTextPrimary
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)

        titleLabel.text = "Skin Insights"
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.textAlignment = .center

        calendarButton.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        calendarButton.layer.cornerRadius = 22
        calendarButton.layer.cornerCurve = .continuous
        calendarButton.setImage(UIImage(systemName: "calendar"), for: .normal)
        calendarButton.tintColor = .ainaDustyRose
        calendarButton.addTarget(self, action: #selector(calendarTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 74),
            backButton.leadingAnchor.constraint(equalTo: topBar.leadingAnchor, constant: 28),
            backButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            calendarButton.trailingAnchor.constraint(equalTo: topBar.trailingAnchor, constant: -28),
            calendarButton.centerYAnchor.constraint(equalTo: topBar.centerYAnchor),
            calendarButton.widthAnchor.constraint(equalToConstant: 44),
            calendarButton.heightAnchor.constraint(equalToConstant: 44),
            titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: calendarButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: topBar.centerYAnchor)
        ])
    }

    private func setupTimeline() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 2
        layout.sectionInset = .zero
        timelineCollectionView.setCollectionViewLayout(layout, animated: false)
        timelineCollectionView.translatesAutoresizingMaskIntoConstraints = false
        timelineCollectionView.backgroundColor = .clear
        timelineCollectionView.showsHorizontalScrollIndicator = false
        timelineCollectionView.dataSource = self
        timelineCollectionView.delegate = self
        timelineCollectionView.register(UINib(nibName: "TimelineCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier)
        view.addSubview(timelineCollectionView)

        NSLayoutConstraint.activate([
            timelineCollectionView.topAnchor.constraint(equalTo: topBar.bottomAnchor, constant: 4),
            timelineCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            timelineCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            timelineCollectionView.heightAnchor.constraint(equalToConstant: 92)
        ])

        DispatchQueue.main.async { self.scrollSelectedDateToCenter(animated: false) }
    }

    private func setupSegmentedButtons() {
        segmentedStack.translatesAutoresizingMaskIntoConstraints = false
        segmentedStack.axis = .horizontal
        segmentedStack.distribution = .fillEqually
        segmentedStack.spacing = 12
        view.addSubview(segmentedStack)
        configureSegmentButton(faceButton, title: "Face scan", action: #selector(faceTapped))
        configureSegmentButton(weeklyButton, title: "Weekly input", action: #selector(weeklyTapped))
        segmentedStack.addArrangedSubview(faceButton)
        segmentedStack.addArrangedSubview(weeklyButton)

        NSLayoutConstraint.activate([
            segmentedStack.topAnchor.constraint(equalTo: timelineCollectionView.bottomAnchor, constant: 8),
            segmentedStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedStack.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    private func setupContentCollection() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 18
        contentCollectionView.setCollectionViewLayout(layout, animated: false)
        contentCollectionView.translatesAutoresizingMaskIntoConstraints = false
        contentCollectionView.backgroundColor = .clear
        contentCollectionView.showsVerticalScrollIndicator = false
        contentCollectionView.alwaysBounceVertical = true
        contentCollectionView.dataSource = self
        contentCollectionView.delegate = self
        contentCollectionView.register(UINib(nibName: InsightFaceScanCollectionViewCell.identifier, bundle: nil), forCellWithReuseIdentifier: InsightFaceScanCollectionViewCell.identifier)
        contentCollectionView.register(UINib(nibName: InsightWeeklyInputCollectionViewCell.identifier, bundle: nil), forCellWithReuseIdentifier: InsightWeeklyInputCollectionViewCell.identifier)
        contentCollectionView.register(UINib(nibName: InsightEmptyCollectionViewCell.identifier, bundle: nil), forCellWithReuseIdentifier: InsightEmptyCollectionViewCell.identifier)
        view.addSubview(contentCollectionView)

        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        leftSwipe.direction = .left
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        rightSwipe.direction = .right
        contentCollectionView.addGestureRecognizer(leftSwipe)
        contentCollectionView.addGestureRecognizer(rightSwipe)

        NSLayoutConstraint.activate([
            contentCollectionView.topAnchor.constraint(equalTo: segmentedStack.bottomAnchor, constant: 20),
            contentCollectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentCollectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentCollectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func buildTimeline() {
        timelineDates.removeAll()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .month, value: -1, to: today) ?? today
        let weekday = calendar.component(.weekday, from: today)
        let startOfCurrentWeek = calendar.date(byAdding: .day, value: 1 - weekday, to: today) ?? today
        let endOfCurrentWeek = calendar.date(byAdding: .day, value: 6, to: startOfCurrentWeek) ?? today

        var current = calendar.startOfDay(for: startDate)
        while current <= endOfCurrentWeek {
            timelineDates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }
    }

    private func configureSegmentButton(_ button: UIButton, title: String, action: Selector) {
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.layer.cornerRadius = 22
        button.layer.cornerCurve = .continuous
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func updateSegmentedButtons() {
        styleSegmentButton(faceButton, isActive: selectedMode == .face)
        styleSegmentButton(weeklyButton, isActive: selectedMode == .weekly)
    }

    private func styleSegmentButton(_ button: UIButton, isActive: Bool) {
        button.backgroundColor = isActive ? UIColor.ainaDustyRose : UIColor.ainaLightBlush.withAlphaComponent(0.25)
        button.setTitleColor(isActive ? .white : .ainaDustyRose, for: .normal)
    }

    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }

    @objc private func faceTapped() {
        selectedMode = .face
        updateForCurrentSelection()
    }

    @objc private func weeklyTapped() {
        selectedMode = .weekly
        updateForCurrentSelection()
    }

    @objc private func calendarTapped() {
        let vc = CalendarPopupViewController()
        vc.modalPresentationStyle = .overFullScreen
        vc.selectedDate = selectedDate
        vc.onDateSelected = { [weak self] date in
            self?.selectDate(date)
        }
        present(vc, animated: false)
    }

    @objc private func handleSwipe(_ recognizer: UISwipeGestureRecognizer) {
        moveToAdjacentResult(older: recognizer.direction == .left)
    }

    private func selectDate(_ date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let day = min(calendar.startOfDay(for: date), today)
        selectedDate = day
        selectedMode = store.hasWeeklyInput(on: day) ? .weekly : .face
        updateForCurrentSelection()
        scrollSelectedDateToCenter(animated: true)
    }

    private func updateForCurrentSelection() {
        updateSegmentedButtons()
        timelineCollectionView.reloadData()
        contentCollectionView.reloadData()
        contentCollectionView.setContentOffset(.zero, animated: false)
    }

    private func scrollSelectedDateToCenter(animated: Bool) {
        guard let index = timelineDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: selectedDate) }) else { return }
        timelineCollectionView.scrollToItem(at: IndexPath(item: index, section: 0), at: .centeredHorizontally, animated: animated)
    }

    private func currentEntry() -> InsightEntry? {
        let dayEntries = store.entries(on: selectedDate)
        switch selectedMode {
        case .face:
            return dayEntries.first { $0.hasFaceScan }
        case .weekly:
            return dayEntries.first { $0.hasWeeklyInput }
        }
    }

    private func moveToAdjacentResult(older: Bool) {
        let calendar = Calendar.current
        let validDates = timelineDates.filter { date in
            switch selectedMode {
            case .face: return store.hasFaceScan(on: date)
            case .weekly: return store.hasWeeklyInput(on: date)
            }
        }
        guard let currentIndex = validDates.firstIndex(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) else {
            if let nearest = validDates.last(where: { $0 <= selectedDate }) ?? validDates.last {
                selectDate(nearest)
            }
            return
        }
        let nextIndex = older ? currentIndex - 1 : currentIndex + 1
        guard validDates.indices.contains(nextIndex) else { return }
        selectDate(validDates[nextIndex])
    }
}

extension InsightViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        collectionView == timelineCollectionView ? timelineDates.count : 1
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if collectionView == timelineCollectionView {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier, for: indexPath) as! TimelineCollectionViewCell
            let date = timelineDates[indexPath.item]
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            let day = String(formatter.string(from: date).prefix(1))
            let dateText = String(format: "%02d", Calendar.current.component(.day, from: date))
            cell.configureForInsight(
                day: day,
                date: dateText,
                isToday: Calendar.current.isDateInToday(date),
                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                hasFaceScan: store.hasFaceScan(on: date),
                hasWeeklyInput: store.hasWeeklyInput(on: date),
                isFuture: date > Calendar.current.startOfDay(for: Date())
            )
            return cell
        }

        guard let entry = currentEntry() else {
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InsightEmptyCollectionViewCell.identifier, for: indexPath) as! InsightEmptyCollectionViewCell
            cell.configure(mode: selectedMode)
            return cell
        }

        switch selectedMode {
        case .face:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InsightFaceScanCollectionViewCell.identifier, for: indexPath) as! InsightFaceScanCollectionViewCell
            cell.configure(entry: entry, image: store.image(for: entry))
            return cell
        case .weekly:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: InsightWeeklyInputCollectionViewCell.identifier, for: indexPath) as! InsightWeeklyInputCollectionViewCell
            cell.configure(entry: entry)
            return cell
        }
    }
}

extension InsightViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard collectionView == timelineCollectionView else { return }
        let date = timelineDates[indexPath.item]
        guard date <= Calendar.current.startOfDay(for: Date()) else { return }
        selectDate(date)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        if collectionView == timelineCollectionView {
            let insets: CGFloat = 0
            let spacing: CGFloat = 12
            let width = (collectionView.bounds.width - insets - spacing) / 7
            return CGSize(width: width, height: 90)
        }
        let width = collectionView.bounds.width - 32
        guard let entry = currentEntry() else {
            return CGSize(width: width, height: 260)
        }
        let height = selectedMode == .face
            ? faceScanHeight(for: entry, width: width)
            : weeklyInputHeight(for: entry, width: width)
        return CGSize(width: width, height: height)
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        insetForSectionAt section: Int) -> UIEdgeInsets {
        collectionView == timelineCollectionView
            ? UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            : UIEdgeInsets(top: 0, left: 16, bottom: 36, right: 16)
    }
}

private extension InsightViewController {
    func faceScanHeight(for entry: InsightEntry, width: CGFloat) -> CGFloat {
        let summary = entry.analysisReport?.summary ?? "Face scan comparison"
        let summaryHeight = textHeight(summary, font: .systemFont(ofSize: 15, weight: .semibold), width: width)
        let comparisons = entry.analysisReport?.comparativeInsights ?? []
        let cardTexts: [(String, String)]

        if comparisons.isEmpty {
            let features = entry.aiDetection.detectedFeatures
            cardTexts = features.isEmpty
                ? [("No concerns detected", "No visible changes were detected in this scan.")]
                : features.prefix(3).map { ($0.issue, "\($0.severity.capitalized) signs around \($0.location.lowercased()).") }
        } else {
            cardTexts = comparisons.prefix(3).map { insight in
                let location = insight.location.map { " • \($0)" } ?? ""
                return ("\(insight.attribute)\(location)", insight.message)
            }
        }

        let textWidth = width - 66
        let cardsHeight = cardTexts.reduce(CGFloat(0)) { total, item in
            let titleHeight = textHeight(item.0, font: .systemFont(ofSize: 15, weight: .bold), width: textWidth)
            let messageHeight = textHeight(item.1, font: .systemFont(ofSize: 14, weight: .regular), width: textWidth)
            return total + max(78, 14 + titleHeight + 5 + messageHeight + 14)
        }
        let cardSpacing = CGFloat(max(cardTexts.count - 1, 0)) * 10
        return ceil(260 + 28 + 22 + 8 + summaryHeight + 14 + cardsHeight + cardSpacing + 4)
    }

    func weeklyInputHeight(for entry: InsightEntry, width: CGFloat) -> CGFloat {
        guard let weekly = entry.weeklyInputData else { return 260 }
        let contentWidth = width - 36

        var routineHeight: CGFloat = 32
        if let summary = entry.analysisReport?.summary {
            routineHeight += textHeight(summary, font: .systemFont(ofSize: 15, weight: .bold), width: contentWidth) + 10
        }

        let comparisons = entry.analysisReport?.comparativeInsights ?? []
        let rows: [(String, String)] = comparisons.isEmpty
            ? [("Weekly check-in saved", "Your weekly input has been added for this week.")]
            : comparisons.prefix(3).map { insight in
                (insight.location.map { "\(insight.attribute) • \($0)" } ?? insight.attribute, insight.message)
            }
        let rowTextWidth = contentWidth - 22
        routineHeight += rows.reduce(CGFloat(0)) { total, row in
            let titleHeight = textHeight(row.0, font: .systemFont(ofSize: 14, weight: .bold), width: rowTextWidth)
            let messageHeight = textHeight(row.1, font: .systemFont(ofSize: 13, weight: .regular), width: rowTextWidth)
            return total + max(58, titleHeight + 4 + messageHeight + 6)
        }
        routineHeight += CGFloat(max(rows.count - 1, 0)) * 10

        let skinText = weekly.correlationLogic ?? weekly.notes ?? "Your weekly check-in adds context from sleep, stress, hydration, and skin feel so scan changes can be compared more accurately."
        let skinHeight = 36 + textHeight(skinText, font: .systemFont(ofSize: 15, weight: .semibold), width: contentWidth)
        var signalCount = 0
        if weekly.lifestyleFactors.sleepQuality != nil { signalCount += 1 }
        if weekly.lifestyleFactors.stressLevel != nil { signalCount += 1 }
        if weekly.lifestyleFactors.waterIntakeAvg != nil { signalCount += 1 }
        signalCount = max(1, signalCount)
        let lifestyleHeight = CGFloat(36 + signalCount * 26 + max(signalCount - 1, 0))
        return ceil(86 + 30 + 22 + 14 + routineHeight + 28 + 22 + 14 + skinHeight + 28 + 22 + 14 + lifestyleHeight)
    }

    func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        guard !text.isEmpty else { return 0 }
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(rect.height)
    }
}
