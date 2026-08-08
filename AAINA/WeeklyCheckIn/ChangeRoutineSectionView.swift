//
//  ChangeRoutineSectionView.swift
//  AAINA
//

import UIKit

final class ChangeRoutineSectionView: UIView {

    // MARK: - Public API
    var routineStartDate: Date = Date()
    var skinContext: (condition: String, concerns: [String]) = ("", [])
    var onChangeDecision: ((Bool, String) -> Void)?

    private(set) var wantsChange:    Bool         = false
    private(set) var routineTarget:  String       = "morning"   // "morning" | "evening" | "both"
    private(set) var selectedSteps:  Set<String>  = []
    private(set) var routineAction:  String       = "change"    // "change" | "remove"
    var reason: String { reasonTextView.text.trimmingCharacters(in: .whitespacesAndNewlines) }

    // MARK: - Step lists
    private let morningSteps = ["Cleanser", "Toner", "Vitamin C", "Serum", "Moisturiser", "SPF", "Eye Cream", "Other"]
    private let eveningSteps = ["Cleanser", "Toner", "Serum", "Moisturiser", "Retinol", "Eye Cream", "Exfoliant", "Other"]
    private var currentSteps: [String] {
        switch routineTarget {
        case "morning": return morningSteps
        case "evening": return eveningSteps
        default:
            var all = Set(morningSteps + eveningSteps)
            all.remove("Other")
            var sorted = all.sorted()
            sorted.append("Other")
            return sorted
        }
    }

    // MARK: - State
    private var isLoadingAI = false
    private let minimumWeeks = 4

    // MARK: - Views
    private let card              = UIView()
    private let yesButton         = UIButton(type: .custom)
    private let noButton          = UIButton(type: .custom)
    private let warningCard       = UIView()
    private let detailStack       = UIStackView()
    private let reasonTextView    = UITextView()
    private let reasonPlaceholder = UILabel()
    private let aiButton          = UIButton(type: .custom)
    private let aiCard            = UIView()
    private let aiLabel           = UILabel()
    private let aiSpinner         = UIActivityIndicatorView(style: .medium)

    private var routineTargetButtons = [UIButton]()
    private var actionButtons        = [UIButton]()
    private var stepButtons          = [UIButton]()
    private let stepRow              = UIStackView()

    private var aiGradient: CAGradientLayer?

    // MARK: - Factory

    static func create() -> ChangeRoutineSectionView {
        let v = ChangeRoutineSectionView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.setup()
        return v
    }

    // MARK: - Setup

    private func setup() {
        card.translatesAutoresizingMaskIntoConstraints = false
        card.applyGlass(cornerRadius: 20)
        addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: topAnchor),
            card.leadingAnchor.constraint(equalTo: leadingAnchor),
            card.trailingAnchor.constraint(equalTo: trailingAnchor),
            card.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        let badge       = makeIconBadge(systemName: "arrow.triangle.2.circlepath")
        let titleLbl    = makeSectionLabel("CHANGE ROUTINE")
        let subtitleLbl = UILabel()
        subtitleLbl.text          = "Want to adjust your skincare routine?"
        subtitleLbl.font          = .systemFont(ofSize: 13)
        subtitleLbl.textColor     = .secondaryLabel
        subtitleLbl.numberOfLines = 0
        subtitleLbl.translatesAutoresizingMaskIntoConstraints = false

        let sep = makeSep()

        styleToggle(yesButton, title: "Yes, let's explore", selected: false)
        styleToggle(noButton,  title: "No, I'm good",       selected: false)
        yesButton.addTarget(self, action: #selector(yesTapped), for: .touchUpInside)
        noButton.addTarget(self,  action: #selector(noTapped),  for: .touchUpInside)

        let toggleRow = UIStackView(arrangedSubviews: [yesButton, noButton])
        toggleRow.axis         = .horizontal
        toggleRow.spacing      = 10
        toggleRow.distribution = .fillEqually
        toggleRow.translatesAutoresizingMaskIntoConstraints = false

        buildWarningCard()

        detailStack.axis    = .vertical
        detailStack.spacing = 16
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailStack.isHidden = true
        buildDetailContent()

        [badge, titleLbl, subtitleLbl, sep, toggleRow, warningCard, detailStack]
            .forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            badge.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            badge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLbl.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            titleLbl.leadingAnchor.constraint(equalTo: badge.trailingAnchor, constant: 10),

            subtitleLbl.topAnchor.constraint(equalTo: badge.bottomAnchor, constant: 4),
            subtitleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            subtitleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            sep.topAnchor.constraint(equalTo: subtitleLbl.bottomAnchor, constant: 14),
            sep.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            sep.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            toggleRow.topAnchor.constraint(equalTo: sep.bottomAnchor, constant: 14),
            toggleRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            toggleRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            toggleRow.heightAnchor.constraint(equalToConstant: 44),

            warningCard.topAnchor.constraint(equalTo: toggleRow.bottomAnchor, constant: 12),
            warningCard.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            warningCard.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            detailStack.topAnchor.constraint(equalTo: warningCard.bottomAnchor, constant: 4),
            detailStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            detailStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            detailStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -20)
        ])
    }

    // MARK: - Warning card

    private func buildWarningCard() {
        warningCard.backgroundColor    = UIColor.ainaSoftRed.withAlphaComponent(0.08)
        warningCard.layer.cornerRadius = 12
        warningCard.translatesAutoresizingMaskIntoConstraints = false
        warningCard.isHidden = true

        let icon = UIImageView(image: UIImage(systemName: "exclamationmark.triangle.fill"))
        icon.tintColor   = .ainaSoftRed
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let lbl = UILabel()
        lbl.text          = "Most routines need at least 4 weeks to show results. Consider giving yours a little more time."
        lbl.font          = .systemFont(ofSize: 13)
        lbl.textColor     = .ainaSoftRed
        lbl.numberOfLines = 0
        lbl.translatesAutoresizingMaskIntoConstraints = false

        warningCard.addSubview(icon); warningCard.addSubview(lbl)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: warningCard.topAnchor, constant: 12),
            icon.leadingAnchor.constraint(equalTo: warningCard.leadingAnchor, constant: 12),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            lbl.topAnchor.constraint(equalTo: warningCard.topAnchor, constant: 10),
            lbl.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            lbl.trailingAnchor.constraint(equalTo: warningCard.trailingAnchor, constant: -12),
            lbl.bottomAnchor.constraint(equalTo: warningCard.bottomAnchor, constant: -10)
        ])
    }

    // MARK: - Detail content

    private func buildDetailContent() {
        // ── 1. Which routine? ──────────────────────────────────────────────
        let routineHeader = makeSubheader("Which routine would you like to adjust?")
        let routineRow    = buildRoutineTargetRow()

        // ── 2. Which steps? (multi-select) ────────────────────────────────
        let stepHeader = makeSubheader("Which steps?  ·  Select all that apply")

        let stepScroll = UIScrollView()
        stepScroll.showsHorizontalScrollIndicator = false
        stepScroll.translatesAutoresizingMaskIntoConstraints = false
        stepScroll.heightAnchor.constraint(equalToConstant: 36).isActive = true

        stepRow.axis      = .horizontal
        stepRow.spacing   = 8
        stepRow.alignment = .center
        stepRow.translatesAutoresizingMaskIntoConstraints = false
        stepScroll.addSubview(stepRow)
        NSLayoutConstraint.activate([
            stepRow.topAnchor.constraint(equalTo: stepScroll.topAnchor),
            stepRow.bottomAnchor.constraint(equalTo: stepScroll.bottomAnchor),
            stepRow.leadingAnchor.constraint(equalTo: stepScroll.leadingAnchor),
            stepRow.trailingAnchor.constraint(equalTo: stepScroll.trailingAnchor),
            stepRow.heightAnchor.constraint(equalTo: stepScroll.heightAnchor)
        ])
        populateStepPills()

        // ── 3. Action: Change vs Remove ───────────────────────────────────
        let actionHeader = makeSubheader("What would you like to do with these steps?")
        let actionRow    = buildActionRow()

        // ── 4. Reason ─────────────────────────────────────────────────────
        let reasonHeader = makeSubheader("Describe the issue")

        let textBox = UIView()
        textBox.backgroundColor    = UIColor.ainaCoralPink.withAlphaComponent(0.05)
        textBox.layer.cornerRadius = 14
        textBox.layer.borderWidth  = 1
        textBox.layer.borderColor  = UIColor.ainaCoralPink.withAlphaComponent(0.15).cgColor
        textBox.translatesAutoresizingMaskIntoConstraints = false

        reasonTextView.backgroundColor    = .clear
        reasonTextView.font               = .systemFont(ofSize: 14)
        reasonTextView.textColor          = .ainaTextPrimary
        reasonTextView.tintColor          = .ainaCoralPink
        reasonTextView.isScrollEnabled    = false
        reasonTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        reasonTextView.delegate           = self
        reasonTextView.translatesAutoresizingMaskIntoConstraints = false
        textBox.addSubview(reasonTextView)

        reasonPlaceholder.text          = "e.g. My SPF feels greasy and causes breakouts…"
        reasonPlaceholder.font          = .systemFont(ofSize: 14)
        reasonPlaceholder.textColor     = .tertiaryLabel
        reasonPlaceholder.numberOfLines = 0
        reasonPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        textBox.addSubview(reasonPlaceholder)

        NSLayoutConstraint.activate([
            textBox.heightAnchor.constraint(greaterThanOrEqualToConstant: 90),
            reasonTextView.topAnchor.constraint(equalTo: textBox.topAnchor),
            reasonTextView.leadingAnchor.constraint(equalTo: textBox.leadingAnchor),
            reasonTextView.trailingAnchor.constraint(equalTo: textBox.trailingAnchor),
            reasonTextView.bottomAnchor.constraint(equalTo: textBox.bottomAnchor),
            reasonPlaceholder.topAnchor.constraint(equalTo: textBox.topAnchor, constant: 12),
            reasonPlaceholder.leadingAnchor.constraint(equalTo: textBox.leadingAnchor, constant: 14),
            reasonPlaceholder.trailingAnchor.constraint(equalTo: textBox.trailingAnchor, constant: -12)
        ])

        // ── 5. AI button ──────────────────────────────────────────────────
        aiButton.setTitle("  ✦  Get Personalised Suggestion", for: .normal)
        aiButton.setTitleColor(.white, for: .normal)
        aiButton.titleLabel?.font    = .systemFont(ofSize: 15, weight: .semibold)
        aiButton.layer.cornerRadius  = 14
        aiButton.layer.masksToBounds = false
        aiButton.translatesAutoresizingMaskIntoConstraints = false
        aiButton.heightAnchor.constraint(equalToConstant: 48).isActive = true
        aiButton.addTarget(self, action: #selector(aiTapped), for: .touchUpInside)

        buildAICard()

        for v in [routineHeader, routineRow, stepHeader, stepScroll,
                  actionHeader, actionRow, reasonHeader, textBox, aiButton, aiCard] {
            detailStack.addArrangedSubview(v)
        }
    }

    // MARK: - Routine target row (Morning / Evening / Both)

    private func buildRoutineTargetRow() -> UIStackView {
        let targets: [(title: String, value: String)] = [
            ("☀️  Morning", "morning"),
            ("🌙  Evening", "evening"),
            ("✨  Both",    "both")
        ]
        let row = UIStackView()
        row.axis         = .horizontal
        row.spacing      = 8
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        for (title, value) in targets {
            let btn = UIButton(type: .custom)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font    = .systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius  = 12
            btn.accessibilityValue  = value
            styleSegment(btn, selected: value == routineTarget)
            btn.addTarget(self, action: #selector(routineTargetTapped(_:)), for: .touchUpInside)
            routineTargetButtons.append(btn)
            row.addArrangedSubview(btn)
        }
        return row
    }

    // MARK: - Action row (Change / Remove)

    private func buildActionRow() -> UIStackView {
        let actions: [(title: String, value: String)] = [
            ("↔  Change step",  "change"),
            ("✕  Remove step",  "remove")
        ]
        let row = UIStackView()
        row.axis         = .horizontal
        row.spacing      = 10
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        row.heightAnchor.constraint(equalToConstant: 40).isActive = true

        for (title, value) in actions {
            let btn = UIButton(type: .custom)
            btn.setTitle(title, for: .normal)
            btn.titleLabel?.font   = .systemFont(ofSize: 13, weight: .medium)
            btn.layer.cornerRadius = 12
            btn.accessibilityValue = value
            styleSegment(btn, selected: value == routineAction)
            btn.addTarget(self, action: #selector(actionTapped(_:)), for: .touchUpInside)
            actionButtons.append(btn)
            row.addArrangedSubview(btn)
        }
        return row
    }

    // MARK: - Step pills (populated / repopulated when routine target changes)

    private func populateStepPills() {
        stepButtons.forEach { $0.removeFromSuperview() }
        stepButtons.removeAll()

        for step in currentSteps {
            let pill = makeStepPill(step)
            stepRow.addArrangedSubview(pill)
            stepButtons.append(pill)
        }
        updateStepPillVisuals()
    }

    private func updateStepPillVisuals() {
        for btn in stepButtons {
            let step = btn.title(for: .normal) ?? ""
            let sel  = selectedSteps.contains(step)
            btn.backgroundColor = sel
                ? UIColor.ainaDustyRose.withAlphaComponent(0.80)
                : UIColor.ainaGlassElevated
            btn.setTitleColor(sel ? .white : .ainaTextPrimary, for: .normal)
            btn.layer.borderColor = sel
                ? UIColor.ainaDustyRose.cgColor
                : UIColor.ainaTextTertiary.withAlphaComponent(0.3).cgColor
        }
    }

    // MARK: - AI response card

    private func buildAICard() {
        aiCard.backgroundColor    = UIColor.ainaDustyRose.withAlphaComponent(0.06)
        aiCard.layer.cornerRadius = 16
        aiCard.layer.borderWidth  = 1
        aiCard.layer.borderColor  = UIColor.ainaDustyRose.withAlphaComponent(0.20).cgColor
        aiCard.isHidden           = true
        aiCard.translatesAutoresizingMaskIntoConstraints = false

        let sparkle   = UILabel()
        sparkle.text  = "✦"
        sparkle.font  = .systemFont(ofSize: 16)
        sparkle.textColor = .ainaDustyRose
        sparkle.translatesAutoresizingMaskIntoConstraints = false

        let headerLbl      = UILabel()
        headerLbl.text     = "Personalised for You"
        headerLbl.font     = .systemFont(ofSize: 13, weight: .semibold)
        headerLbl.textColor = .ainaDustyRose
        headerLbl.translatesAutoresizingMaskIntoConstraints = false

        aiSpinner.color           = .ainaDustyRose
        aiSpinner.hidesWhenStopped = true
        aiSpinner.translatesAutoresizingMaskIntoConstraints = false

        aiLabel.text          = ""
        aiLabel.font          = .systemFont(ofSize: 14)
        aiLabel.textColor     = .ainaTextPrimary
        aiLabel.numberOfLines = 0
        aiLabel.translatesAutoresizingMaskIntoConstraints = false

        let disclaimer      = UILabel()
        disclaimer.text     = "Powered by Gemini AI  ·  Always patch test new products"
        disclaimer.font     = .systemFont(ofSize: 10)
        disclaimer.textColor = .tertiaryLabel
        disclaimer.translatesAutoresizingMaskIntoConstraints = false

        [sparkle, headerLbl, aiSpinner, aiLabel, disclaimer].forEach { aiCard.addSubview($0) }
        NSLayoutConstraint.activate([
            sparkle.topAnchor.constraint(equalTo: aiCard.topAnchor, constant: 14),
            sparkle.leadingAnchor.constraint(equalTo: aiCard.leadingAnchor, constant: 14),
            headerLbl.centerYAnchor.constraint(equalTo: sparkle.centerYAnchor),
            headerLbl.leadingAnchor.constraint(equalTo: sparkle.trailingAnchor, constant: 6),
            aiSpinner.centerYAnchor.constraint(equalTo: sparkle.centerYAnchor),
            aiSpinner.trailingAnchor.constraint(equalTo: aiCard.trailingAnchor, constant: -14),
            aiLabel.topAnchor.constraint(equalTo: sparkle.bottomAnchor, constant: 10),
            aiLabel.leadingAnchor.constraint(equalTo: aiCard.leadingAnchor, constant: 14),
            aiLabel.trailingAnchor.constraint(equalTo: aiCard.trailingAnchor, constant: -14),
            disclaimer.topAnchor.constraint(equalTo: aiLabel.bottomAnchor, constant: 10),
            disclaimer.leadingAnchor.constraint(equalTo: aiCard.leadingAnchor, constant: 14),
            disclaimer.bottomAnchor.constraint(equalTo: aiCard.bottomAnchor, constant: -12)
        ])
    }

    // MARK: - Gradient (AI button)

    override func layoutSubviews() {
        super.layoutSubviews()
        guard aiButton.bounds.width > 0 else { return }
        if aiGradient == nil {
            let g = CAGradientLayer()
            g.colors     = [UIColor.ainaDustyRose.cgColor, UIColor.ainaCoralPink.cgColor]
            g.startPoint = CGPoint(x: 0, y: 0.5)
            g.endPoint   = CGPoint(x: 1, y: 0.5)
            g.cornerRadius = 14
            aiButton.layer.insertSublayer(g, at: 0)
            aiButton.layer.shadowColor   = UIColor.ainaDustyRose.cgColor
            aiButton.layer.shadowOpacity = 0.3
            aiButton.layer.shadowOffset  = CGSize(width: 0, height: 4)
            aiButton.layer.shadowRadius  = 8
            aiGradient = g
        }
        aiGradient?.frame = aiButton.bounds
    }

    // MARK: - Actions

    @objc private func yesTapped() {
        wantsChange = true
        styleToggle(yesButton, title: "Yes, let's explore", selected: true)
        styleToggle(noButton,  title: "No, I'm good",       selected: false)
        warningCard.isHidden = weeksSince(routineStartDate) >= minimumWeeks
        UIView.animate(withDuration: 0.28, delay: 0,
                       usingSpringWithDamping: 0.9, initialSpringVelocity: 0,
                       options: .allowUserInteraction) {
            self.detailStack.isHidden = false
            self.superview?.layoutIfNeeded()
        }
        onChangeDecision?(true, reason)
    }

    @objc private func noTapped() {
        wantsChange = false
        styleToggle(yesButton, title: "Yes, let's explore", selected: false)
        styleToggle(noButton,  title: "No, I'm good",       selected: true)
        warningCard.isHidden = true
        UIView.animate(withDuration: 0.22) {
            self.detailStack.isHidden = true
            self.aiCard.isHidden      = true
            self.superview?.layoutIfNeeded()
        }
        onChangeDecision?(false, "")
    }

    @objc private func routineTargetTapped(_ sender: UIButton) {
        guard let value = sender.accessibilityValue else { return }
        routineTarget = value
        for btn in routineTargetButtons {
            styleSegment(btn, selected: btn.accessibilityValue == value)
        }
        // Reset steps that don't apply to the new target
        selectedSteps = selectedSteps.filter { currentSteps.contains($0) }
        populateStepPills()
    }

    @objc private func actionTapped(_ sender: UIButton) {
        guard let value = sender.accessibilityValue else { return }
        routineAction = value
        for btn in actionButtons {
            styleSegment(btn, selected: btn.accessibilityValue == value)
        }
        // Update reason placeholder to match chosen action
        reasonPlaceholder.text = routineAction == "remove"
            ? "e.g. SPF makes my skin break out and feel heavy…"
            : "e.g. My moisturiser feels too heavy, causing congestion…"
    }

    @objc private func stepPillTapped(_ sender: UIButton) {
        let step = sender.title(for: .normal) ?? ""
        if selectedSteps.contains(step) { selectedSteps.remove(step) }
        else { selectedSteps.insert(step) }
        updateStepPillVisuals()
    }

    @objc private func aiTapped() {
        guard !isLoadingAI else { return }
        guard !selectedSteps.isEmpty else { shakeHint(); return }
        let reasonText = reason
        guard !reasonText.isEmpty else { shakeHint(); return }

        isLoadingAI     = true
        aiCard.isHidden = false
        aiLabel.text    = ""
        aiLabel.textColor = .ainaTextPrimary
        aiSpinner.startAnimating()
        setNeedsLayout()

        let ctx = GeminiService.RoutineContext(
            skinCondition:          skinContext.condition,
            concerns:               skinContext.concerns,
            stepsToChange:          Array(selectedSteps).sorted(),
            routineTarget:          routineTarget,
            action:                 routineAction,
            reason:                 reasonText,
            weeksSinceRoutineStart: weeksSince(routineStartDate)
        )

        GeminiService.getRoutineSuggestion(context: ctx) { [weak self] result in
            guard let self else { return }
            self.isLoadingAI = false
            self.aiSpinner.stopAnimating()
            switch result {
            case .success(let text):
                self.aiLabel.text = text
            case .failure(let err):
                self.aiLabel.text      = err.localizedDescription
                self.aiLabel.textColor = .ainaSoftRed
            }
            UIView.animate(withDuration: 0.2) { self.superview?.layoutIfNeeded() }
            self.onChangeDecision?(true, reasonText)
        }
    }

    // MARK: - Helpers

    private func weeksSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.weekOfYear], from: date, to: Date()).weekOfYear ?? 0
    }

    private func shakeHint() {
        let anim = CAKeyframeAnimation(keyPath: "transform.translation.x")
        anim.timingFunction = CAMediaTimingFunction(name: .linear)
        anim.duration = 0.4
        anim.values   = [-6, 6, -4, 4, -2, 2, 0]
        aiButton.layer.add(anim, forKey: "shake")
    }

    // MARK: - View factories

    private func makeStepPill(_ title: String) -> UIButton {
        let btn = UIButton(type: .system)
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = .systemFont(ofSize: 13, weight: .medium)
        btn.setTitleColor(.ainaTextPrimary, for: .normal)
        btn.backgroundColor    = .ainaGlassElevated
        btn.layer.cornerRadius = 14
        btn.layer.borderWidth  = 1
        btn.layer.borderColor  = UIColor.ainaTextTertiary.withAlphaComponent(0.3).cgColor
        btn.setValue(NSValue(uiEdgeInsets: UIEdgeInsets(top: 6, left: 14, bottom: 6, right: 14)), forKey: "contentEdgeInsets")
        btn.heightAnchor.constraint(equalToConstant: 32).isActive = true
        btn.addTarget(self, action: #selector(stepPillTapped(_:)), for: .touchUpInside)
        return btn
    }

    private func styleSegment(_ btn: UIButton, selected: Bool) {
        btn.setTitleColor(selected ? .white : .ainaTextSecondary, for: .normal)
        btn.backgroundColor   = selected
            ? UIColor.ainaCoralPink.withAlphaComponent(0.75)
            : UIColor.ainaTextTertiary.withAlphaComponent(0.12)
        btn.layer.borderWidth = selected ? 0 : 1
        btn.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.2).cgColor
    }

    private func styleToggle(_ btn: UIButton, title: String, selected: Bool) {
        btn.setTitle(title, for: .normal)
        btn.titleLabel?.font   = .systemFont(ofSize: 14, weight: .medium)
        btn.layer.cornerRadius = 12
        btn.backgroundColor    = selected
            ? UIColor.ainaCoralPink.withAlphaComponent(0.75)
            : UIColor.ainaTextTertiary.withAlphaComponent(0.15)
        btn.setTitleColor(selected ? .white : .ainaTextSecondary, for: .normal)
        btn.layer.borderWidth  = selected ? 0 : 1
        btn.layer.borderColor  = UIColor.ainaTextTertiary.withAlphaComponent(0.2).cgColor
    }

    private func makeSubheader(_ text: String) -> UILabel {
        let l = UILabel()
        l.text          = text
        l.font          = .systemFont(ofSize: 14, weight: .semibold)
        l.textColor     = .ainaTextPrimary
        l.numberOfLines = 0
        return l
    }

    private func makeIconBadge(systemName: String) -> UIView {
        let v = UIView()
        v.backgroundColor    = .ainaTintedGlassMedium
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: systemName))
        icon.tintColor   = .ainaDustyRose
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(icon)
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 36),
            v.heightAnchor.constraint(equalToConstant: 36),
            icon.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: v.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16)
        ])
        return v
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.secondaryLabel,
            .kern: 1.4
        ])
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    private func makeSep() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.12)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }
}

// MARK: - UITextViewDelegate

extension ChangeRoutineSectionView: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        reasonPlaceholder.isHidden = !textView.text.isEmpty
    }
}
