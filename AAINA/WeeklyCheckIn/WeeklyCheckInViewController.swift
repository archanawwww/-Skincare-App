//
//  WeeklyCheckInViewController.swift
//  AAINA
//

import UIKit

class WeeklyCheckInViewController: UIViewController {

    // MARK: - Callback
    var onDismiss: (() -> Void)?

    // MARK: - Section views
    private let skinConditionSection = SkinConditionSectionView.create()
    private let lifestyleSection     = LifestyleSectionView.create()
    private let progressPhotoSection = ProgressPhotoSectionView.create()
    private let notesSection         = NotesSectionView.create()
    private let changeRoutineSection = ChangeRoutineSectionView.create()

    // MARK: - Layout
    private let titleLabel    = UILabel()
    private let weekPill      = UILabel()
    private let subtitleLabel = UILabel()
    private let scrollView    = UIScrollView()
    private let contentStack  = UIStackView()
    private let saveButton    = UIButton(type: .custom)
    private var wantsRoutineChange = false
    private var routineChangeReason = ""

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        setupHeader()
        setupScrollView()
        addSections()
        setupKeyboard()
        progressPhotoSection.presentingViewController = self

        // Pass skin context to AI suggestion so it can personalise the response
        skinConditionSection.onConditionSelected = { [weak self] condition in
            guard let self else { return }
            self.changeRoutineSection.skinContext.condition = condition
        }
        skinConditionSection.onConcernsChanged = { [weak self] concerns in
            guard let self else { return }
            self.changeRoutineSection.skinContext.concerns = Array(concerns)
        }
        changeRoutineSection.onChangeDecision = { [weak self] wantsChange, reason in
            self?.wantsRoutineChange = wantsChange
            self?.routineChangeReason = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyButtonGradient()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    // MARK: - Header

    private func setupHeader() {
        let range = WeeklyCheckInManager.weekRange()

        titleLabel.text      = "Weekly Check-In"
        titleLabel.font      = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        // Week pill  e.g. "Apr 21 – Apr 27"
        let fmt = DateFormatter(); fmt.dateFormat = "d MMM"
        weekPill.text            = "\(fmt.string(from: range.start))  –  \(fmt.string(from: range.end))"
        weekPill.font            = .systemFont(ofSize: 12, weight: .medium)
        weekPill.textColor       = .ainaDustyRose
        weekPill.textAlignment   = .center
        weekPill.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.10)
        weekPill.layer.cornerRadius = 12
        weekPill.clipsToBounds   = true
        weekPill.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text          = "How has your skin been this week?"
        subtitleLabel.font          = .systemFont(ofSize: 14)
        subtitleLabel.textColor     = .ainaTextSecondary
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, weekPill, subtitleLabel].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.topAnchor, constant: 28),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),

            weekPill.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            weekPill.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor, constant: 10),
            weekPill.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            weekPill.heightAnchor.constraint(equalToConstant: 26),
            weekPill.widthAnchor.constraint(greaterThanOrEqualToConstant: 100),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // Add insets to weekPill text
        weekPill.layoutMargins = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
    }

    // MARK: - Scroll view

    private func setupScrollView() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis    = .vertical
        contentStack.spacing = 24
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -32),
            contentStack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])
    }

    // MARK: - Sections + Save button

    private func addSections() {
        contentStack.addArrangedSubview(skinConditionSection)
        contentStack.addArrangedSubview(lifestyleSection)
        contentStack.addArrangedSubview(progressPhotoSection)
        contentStack.addArrangedSubview(notesSection)
        contentStack.addArrangedSubview(changeRoutineSection)
        contentStack.addArrangedSubview(makeSaveButton())
    }

    private func makeSaveButton() -> UIView {
        saveButton.setTitle("Save Check-In", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.titleLabel?.font    = .systemFont(ofSize: 17, weight: .semibold)
        saveButton.layer.cornerRadius  = 16
        saveButton.layer.masksToBounds = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.heightAnchor.constraint(equalToConstant: 56).isActive = true
        return saveButton
    }

    private func applyButtonGradient() {
        guard saveButton.bounds.width > 0 else { return }
        let name = "saveGradient"
        if let existing = saveButton.layer.sublayers?.first(where: { $0.name == name }) as? CAGradientLayer {
            existing.frame = saveButton.bounds; return
        }
        let grad          = CAGradientLayer()
        grad.name         = name
        grad.colors       = [UIColor.ainaCoralPink.cgColor, UIColor.ainaDustyRose.cgColor]
        grad.startPoint   = CGPoint(x: 0, y: 0.5)
        grad.endPoint     = CGPoint(x: 1, y: 0.5)
        grad.cornerRadius = 16
        grad.frame        = saveButton.bounds
        saveButton.layer.insertSublayer(grad, at: 0)
        saveButton.layer.shadowColor   = UIColor.ainaDustyRose.cgColor
        saveButton.layer.shadowOpacity = 0.35
        saveButton.layer.shadowOffset  = CGSize(width: 0, height: 8)
        saveButton.layer.shadowRadius  = 12
    }

    // MARK: - Keyboard

    private func setupKeyboard() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardChanged(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }

    @objc private func keyboardChanged(_ note: Notification) {
        guard let info     = note.userInfo,
              let frame    = (info[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let duration = info[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double
        else { return }
        let overlap = max(0, view.bounds.maxY - frame.minY)
        UIView.animate(withDuration: duration) {
            self.scrollView.contentInset.bottom = overlap > 0 ? overlap + 8 : 0
        }
    }

    // MARK: - Save

    @objc private func saveTapped() {
        let range = WeeklyCheckInManager.weekRange()

        let photoFileNames = progressPhotoSection.selectedImages
            .compactMap { JournalPhotoStore.save($0) }

        var data = WeeklyCheckInData()
        data.weekKey               = range.key
        data.weekStart             = range.start
        data.weekEnd               = range.end
        data.createdAt             = Date()
        data.skinCondition         = skinConditionSection.selectedCondition
        data.concerns              = Array(skinConditionSection.selectedConcerns)
        data.sleepQuality          = lifestyleSection.selectedSleep
        data.stressLevel           = lifestyleSection.stressLevel
        data.waterIntake           = lifestyleSection.waterGlasses
        data.progressPhotoFileNames = photoFileNames
        data.additionalNotes       = notesSection.notes
        data.wantsRoutineChange    = changeRoutineSection.wantsChange
        data.routineChangeReason   = changeRoutineSection.reason

        WeeklyCheckInManager.save(data)
        let insightWeeklyInput = InsightWeeklyInput(
            insightTitle: "Weekly Check-In",
            skinFeel: data.skinCondition,
            concerns: data.concerns,
            lifestyleFactors: InsightLifestyleFactors(
                sleepQuality: data.sleepQuality,
                stressLevel: Double(data.stressLevel),
                waterIntakeAvg: data.waterIntake,
                waterGoal: nil
            ),
            productChanges: [],
            correlationLogic: data.additionalNotes,
            notes: data.additionalNotes
        )

        InsightStore.shared.saveWeeklyInput(insightWeeklyInput)
        if wantsRoutineChange {
            let detail = routineChangeReason.isEmpty
                ? "No reason added."
                : routineChangeReason
            AppDataModel.shared.recordRoutineHistory(
                title: "Change Requested",
                summary: "Weekly check-in marked the routine for review",
                detail: detail,
                previousRoutine: AppDataModel.shared.aiRoutine,
                newRoutine: nil
            )
            regenerateRoutineAfterWeeklyCheckIn(reason: detail)
        }
        WeeklyCheckInManager.markCompletedThisWeek()
        onDismiss?()
        dismiss(animated: true)
    }

    private func regenerateRoutineAfterWeeklyCheckIn(reason: String) {
        guard let onboardingData = AppDataModel.shared.onboardingDataFromProfile() else { return }
        Task {
            do {
                let prompt = RoutinePromptBuilder.build(
                    onboardingData: onboardingData,
                    ingredients: AppDataModel.shared.allIngredients(),
                    imageProvided: false
                ) + "\nWeekly check-in reason for routine change: \(reason)"
                let output = try await GeminiFreeService().generateRoutine(prompt: prompt, image: nil)
                AppDataModel.shared.saveAIRoutine(output.routine, reason: "Weekly check-in: \(reason)")
                AppDataModel.shared.saveLastFaceScanResult(output.scanResult)
            } catch {
                print("weekly routine regeneration failed:", error.localizedDescription)
            }
        }
    }
}

// MARK: - WeeklyCheckInManager

enum WeeklyCheckInManager {
    private static let shownKey = "weeklyCheckIn_lastShownWeek"
    private static let loginDateKey = "loginDate"

    // MARK: - Week range

    static func weekRange(for date: Date = Date()) -> (start: Date, end: Date, key: String) {
        let cal     = Calendar.current
        let weekday = cal.component(.weekday, from: date)
        let sunday  = cal.date(byAdding: .day, value: -(weekday - 1),
                               to: cal.startOfDay(for: date))!
        let saturday = cal.date(byAdding: .day, value: 6, to: sunday)!
        let week     = cal.component(.weekOfYear, from: date)
        let year     = cal.component(.year, from: date)
        return (sunday, saturday, "\(year)-W\(String(format: "%02d", week))")
    }

    // MARK: - Persistence

    private static var fileURL: URL {
        #if DEBUG
        return URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Model")
            .appendingPathComponent("weekly_checkins.json")
        #else
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("weekly_checkins.json")
        #endif
    }

    static func save(_ data: WeeklyCheckInData) {
        var all = loadAll()
        all.removeAll { $0.weekKey == data.weekKey }
        all.append(data)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .iso8601
        if let d = try? enc.encode(all) { try? d.write(to: fileURL) }
        FirestoreSyncService.shared.saveWeeklyCheckIn(data)
    }

    static func loadAll() -> [WeeklyCheckInData] {
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .iso8601
        guard let d   = try? Data(contentsOf: fileURL),
              let all = try? dec.decode([WeeklyCheckInData].self, from: d)
        else { return [] }
        return all.sorted { $0.weekStart > $1.weekStart }
    }

    static func load(for weekKey: String) -> WeeklyCheckInData? {
        loadAll().first { $0.weekKey == weekKey }
    }

    // MARK: - Show logic

    static func shouldShow() -> Bool {
        let loginDate: Date
        if let savedLoginDate = UserDefaults.standard.object(forKey: loginDateKey) as? Date {
            loginDate = savedLoginDate
        } else {
            loginDate = Date()
            UserDefaults.standard.set(loginDate, forKey: loginDateKey)
        }

        let daysSinceLogin = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: loginDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0

        guard daysSinceLogin >= 7 else { return false }

        let interval = daysSinceLogin / 7
        return UserDefaults.standard.integer(forKey: shownKey) != interval
    }

    static func markCompletedThisWeek() {
        markShownThisWeek()
    }

    static func markShownThisWeek() {
        let loginDate = (UserDefaults.standard.object(forKey: loginDateKey) as? Date) ?? Date()
        let daysSinceLogin = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: loginDate),
            to: Calendar.current.startOfDay(for: Date())
        ).day ?? 0
        UserDefaults.standard.set(max(daysSinceLogin / 7, 0), forKey: shownKey)
    }
}
