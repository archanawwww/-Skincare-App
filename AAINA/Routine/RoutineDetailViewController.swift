import UIKit
import AVKit

class RoutineDetailViewController: UIViewController {

    var step: RoutineStep?
    var aiStep: AIRoutineStep?
    var dataModel: DataModel!
    private var videoPlayer: AVPlayer?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()


    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = .clear
        view.applyAINABackground()
        let appearance = UINavigationBarAppearance()

        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance

        navigationController?.setNavigationBarHidden(false, animated: false)

        title = "Routine"

        setupLayout()
        buildUI()
    }
}
extension RoutineDetailViewController {

    @objc func openIngredient(_ sender: UITapGestureRecognizer) {

        guard let pill = sender.view as? PaddingLabel,
              let id = pill.accessibilityIdentifier else { return }

        print("Tapped ingredient ID:", id)
        guard let ingredient = dataModel.ingredient(for: id)
        else {

            let alert = UIAlertController(
                title: "Ingredient not found",
                message: id,
                preferredStyle: .alert
            )

            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)

            return
        }


        print(" Opening ingredient:", ingredient.name)

        let vc = IngredientDetailViewController(ingredient: ingredient)
        vc.modalPresentationStyle = .pageSheet

        if let sheet = vc.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(vc, animated: true)
    }
}
// Sets up the scroll view and vertical stack that holds all page sections

extension RoutineDetailViewController {

    private func setupLayout() {

        contentStack.axis = .vertical
        contentStack.spacing = 28

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),

            contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }
}

extension RoutineDetailViewController {

    private func makeVideoCard() -> UIView {

        let card = makeCard()
        card.backgroundColor = .ainaRoseLight
        card.clipsToBounds = true
        card.layer.cornerRadius = 24

        if let videoName = routineVideoResourceName(),
           let url = Bundle.main.url(forResource: videoName, withExtension: "mp4") {
            let player = AVPlayer(url: url)
            videoPlayer = player
            let playerVC = AVPlayerViewController()
            playerVC.player = player
            playerVC.showsPlaybackControls = true
            playerVC.videoGravity = .resizeAspectFill

            addChild(playerVC)
            playerVC.view.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(playerVC.view)
            playerVC.didMove(toParent: self)

            NSLayoutConstraint.activate([
                card.heightAnchor.constraint(equalToConstant: 220),
                playerVC.view.topAnchor.constraint(equalTo: card.topAnchor),
                playerVC.view.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                playerVC.view.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                playerVC.view.trailingAnchor.constraint(equalTo: card.trailingAnchor)
            ])

            player.play()
        } else {
            // No video found — show a placeholder icon and label instead
            let icon = UIImageView(image: UIImage(systemName: "drop.fill")?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 36, weight: .light)))
            icon.tintColor = UIColor.ainaDustyRose.withAlphaComponent(0.45)
            icon.contentMode = .scaleAspectFit
            icon.translatesAutoresizingMaskIntoConstraints = false

            let label = UILabel()
            label.text = "Product Image"
            label.font = .systemFont(ofSize: 13, weight: .medium)
            label.textColor = UIColor.ainaDustyRose.withAlphaComponent(0.55)

            let center = UIStackView(arrangedSubviews: [icon, label])
            center.axis = .vertical
            center.spacing = 8
            center.alignment = .center
            center.translatesAutoresizingMaskIntoConstraints = false

            // Small pill in the corner showing the first key ingredient
            var firstIngredient = ""
            if let ai = aiStep { firstIngredient = ai.keyIngredients.first ?? "" }
            else if let s = step { firstIngredient = dataModel.ingredientNames(for: s).first ?? "" }

            let pill = PaddingLabel()
            pill.text = firstIngredient.isEmpty ? "" : "\(firstIngredient)-rich"
            pill.font = .systemFont(ofSize: 12, weight: .semibold)
            pill.textColor = UIColor.ainaDustyRose
            pill.backgroundColor = UIColor.white.withAlphaComponent(0.75)
            pill.layer.cornerRadius = 14
            pill.layer.masksToBounds = true
            pill.padding = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
            pill.isHidden = firstIngredient.isEmpty
            pill.translatesAutoresizingMaskIntoConstraints = false

            card.addSubview(center)
            card.addSubview(pill)

            NSLayoutConstraint.activate([
                card.heightAnchor.constraint(equalToConstant: 220),
                center.centerXAnchor.constraint(equalTo: card.centerXAnchor),
                center.centerYAnchor.constraint(equalTo: card.centerYAnchor),
                pill.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
                pill.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
            ])
        }

        return card
    }

    private func routineVideoResourceName() -> String? {
        let type = aiStep?.productType ?? step?.type

        switch type {
        case .cleanser:
            return "cleanser"
        case .toner:
            return "Toner"
        case .serum:
            return "Serum"
        case .moisturizer:
            return "moisturiser"
        case .sunscreen:
            return "Sunscreen"
        case .treatment:
            return "Treatment"
        case .repair:
            return "Repair"
        case .none:
            return routineVideoResourceName(from: aiStep?.productName ?? step?.stepTitle ?? "")
        }
    }

    private func routineVideoResourceName(from text: String) -> String? {
        let normalized = text.lowercased()

        if normalized.contains("cleanser") { return "cleanser" }
        if normalized.contains("toner") { return "Toner" }
        if normalized.contains("serum") { return "Serum" }
        if normalized.contains("moisturizer") || normalized.contains("moisturiser") { return "moisturiser" }
        if normalized.contains("sunscreen") || normalized.contains("spf") { return "Sunscreen" }
        if normalized.contains("treatment") || normalized.contains("retinol") { return "Treatment" }
        if normalized.contains("repair") { return "Repair" }

        return nil
    }
}

// Short description of why this product was included in the routine

extension RoutineDetailViewController {

    private func makeDescriptionSection() -> UIView {

        let container = UIView()

        let text = UILabel()
        text.numberOfLines = 0
        text.font = .systemFont(ofSize: 15)
        text.textColor = .ainaTextSecondary
        let descParagraph = NSMutableParagraphStyle()
        descParagraph.lineHeightMultiple = 1.5
        text.attributedText = NSAttributedString(
            string: aiStep?.reason ?? step?.productDescription ?? "",
            attributes: [.paragraphStyle: descParagraph, .font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.ainaTextSecondary]
        )

        let separator = UIView()
        separator.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.5)
        separator.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [text, separator])
        stack.axis = .vertical
        stack.spacing = 24

        container.addSubview(stack)
        stack.pinEdges(to: container, padding: 0)

        NSLayoutConstraint.activate([
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])

        return container
    }
}

// Step-by-step instructions on how to use the product

extension RoutineDetailViewController {

    private func makeInstructionSection() -> UIView {

        let container = UIView()

        let header = makeSectionHeader("Instruction", systemImage: "plus")

        let text = UILabel()
        text.numberOfLines = 0
        text.font = .systemFont(ofSize: 15)
        text.textColor = .secondaryLabel
        let instrParagraph = NSMutableParagraphStyle()
        instrParagraph.lineHeightMultiple = 1.5
        text.attributedText = NSAttributedString(
            string: aiStep?.usage ?? step?.instructionText ?? "",
            attributes: [.paragraphStyle: instrParagraph, .font: UIFont.systemFont(ofSize: 14), .foregroundColor: UIColor.secondaryLabel]
        )

        let separator = UIView()
        separator.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([separator.heightAnchor.constraint(equalToConstant: 0.5)])

        let stack = UIStackView(arrangedSubviews: [header, text, separator])
        stack.axis = .vertical
        stack.spacing = 12
        stack.setCustomSpacing(16, after: header)
        stack.setCustomSpacing(24, after: text)

        container.addSubview(stack)
        stack.pinEdges(to: container, padding: 0)

        return container
    }
}

// Explains why each ingredient was picked based on the user's skin profile

extension RoutineDetailViewController {

    private func makeWhySuggestedSection() -> UIView? {

        // Get ingredient names from either an AI step or a regular routine step
        var names: [String] = []
        if let ai = aiStep { names = ai.keyIngredients }
        else if let s = step { names = dataModel.ingredientNames(for: s) }
        guard !names.isEmpty else { return nil }

        // Load the user's skin profile to generate personalised reasons
        let userID = dataModel.currentUser().id
        guard let profile = dataModel.profile(for: userID) else { return nil }

        // Only show ingredients that have a personalised reason to display
        let rows: [(name: String, reason: String)] = names.compactMap { name in
            guard let r = IngredientPersonalizationEngine.shared.reason(for: name, profile: profile)
            else { return nil }
            return (name, r)
        }
        guard !rows.isEmpty else { return nil }

        // Section title shown above the card
        let headerRow = makeSectionHeader("Why We Suggested This", systemImage: "person.crop.circle.badge.checkmark")

        // Table column headers
        let colIngredient = UILabel()
        colIngredient.text = "Ingredient"
        colIngredient.font = .systemFont(ofSize: 12, weight: .semibold)
        colIngredient.textColor = UIColor.darkGray

        let colBenefit = UILabel()
        colBenefit.text = "Benefit for you"
        colBenefit.font = .systemFont(ofSize: 12, weight: .semibold)
        colBenefit.textColor = UIColor.darkGray

        let colRow = makeTableRow(left: colIngredient, right: colBenefit, isHeader: true, showSeparator: false)

        // One row per ingredient with its personalised benefit
        let tableStack = UIStackView(arrangedSubviews: [colRow])
        tableStack.axis = .vertical
        tableStack.spacing = 0

        for (index, (name, reason)) in rows.enumerated() {
            let nameLabel = UILabel()
            nameLabel.text = name
            nameLabel.font = .systemFont(ofSize: 14, weight: .semibold)
            nameLabel.textColor = UIColor.ainaDustyRose
            nameLabel.numberOfLines = 1

            let reasonLabel = UILabel()
            reasonLabel.text = reason
            reasonLabel.font = .systemFont(ofSize: 13, weight: .regular)
            reasonLabel.textColor = UIColor.ainaTextPrimary
            reasonLabel.numberOfLines = 0

            let isLast = index == rows.count - 1
            tableStack.addArrangedSubview(makeTableRow(left: nameLabel, right: reasonLabel, isHeader: false, showSeparator: !isLast))
        }

        // White card that wraps the ingredient-benefit table
        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.82)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.18).cgColor
        card.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.09
        card.layer.shadowRadius = 14
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.layer.masksToBounds = false

        tableStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(tableStack)
        NSLayoutConstraint.activate([
            tableStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 8),
            tableStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            tableStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            tableStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12)
        ])

        // Combine the section title and the card into one vertical block
        let section = UIStackView(arrangedSubviews: [headerRow, card])
        section.axis = .vertical
        section.spacing = 12
        return section
    }

    private func makeTableRow(left: UILabel, right: UILabel, isHeader: Bool, showSeparator: Bool = true) -> UIView {

        let hInset: CGFloat = isHeader ? 12 : 0
        let vInset: CGFloat = isHeader ? 11 : 10

        // Outer container lets the header highlight stretch full width
        let outer = UIView()

        let highlight = UIView()
        highlight.backgroundColor = isHeader
            ? UIColor.ainaDustyRose.withAlphaComponent(0.13)
            : .clear
        highlight.layer.cornerRadius = isHeader ? 12 : 0
        highlight.layer.cornerCurve  = .continuous
        highlight.layer.masksToBounds = true
        highlight.translatesAutoresizingMaskIntoConstraints = false
        outer.addSubview(highlight)

        left.translatesAutoresizingMaskIntoConstraints  = false
        right.translatesAutoresizingMaskIntoConstraints = false
        highlight.addSubview(left)
        highlight.addSubview(right)

        NSLayoutConstraint.activate([
            highlight.topAnchor.constraint(equalTo: outer.topAnchor, constant: isHeader ? 0 : 0),
            highlight.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
            highlight.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
            highlight.bottomAnchor.constraint(equalTo: outer.bottomAnchor),

            left.leadingAnchor.constraint(equalTo: highlight.leadingAnchor, constant: hInset),
            left.topAnchor.constraint(equalTo: highlight.topAnchor, constant: vInset),
            left.bottomAnchor.constraint(lessThanOrEqualTo: highlight.bottomAnchor, constant: -vInset),
            left.widthAnchor.constraint(equalTo: highlight.widthAnchor, multiplier: 0.36),

            right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 10),
            right.trailingAnchor.constraint(equalTo: highlight.trailingAnchor, constant: -hInset),
            right.topAnchor.constraint(equalTo: highlight.topAnchor, constant: vInset),
            right.bottomAnchor.constraint(equalTo: highlight.bottomAnchor, constant: -vInset)
        ])

        if !isHeader && showSeparator {
            let sep = UIView()
            sep.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
            sep.translatesAutoresizingMaskIntoConstraints = false
            outer.addSubview(sep)
            NSLayoutConstraint.activate([
                sep.leadingAnchor.constraint(equalTo: outer.leadingAnchor),
                sep.trailingAnchor.constraint(equalTo: outer.trailingAnchor),
                sep.bottomAnchor.constraint(equalTo: outer.bottomAnchor),
                sep.heightAnchor.constraint(equalToConstant: 0.5)
            ])
        }

        return outer
    }
}

// Shows safe concentration ranges for each key ingredient

extension RoutineDetailViewController {

    private func makeConcentrationSection() -> UIView? {

        var names: [String] = []
        if let ai = aiStep {
            names = ai.keyIngredients
        } else if let step = step {
            names = dataModel.ingredientNames(for: step)
        }

        // Skip ingredients that don't have concentration data
        let rows: [(name: String, conc: IngredientConcentration)] = names.compactMap { name in
            guard let c = IngredientConcentrationDatabase.shared.concentration(for: name) else { return nil }
            return (name, c)
        }
        guard !rows.isEmpty else { return nil }

        // Section title shown above the card
        let headerStack = makeSectionHeader("Concentration Guide", systemImage: "arrow.up.right")

        // One row per ingredient showing its safe usage range
        let rowsStack = UIStackView()
        rowsStack.axis = .vertical
        rowsStack.spacing = 10

        for (name, conc) in rows {
            let row = makeConcentrationRow(name: name, conc: conc)
            rowsStack.addArrangedSubview(row)
        }

        // Small disclaimer at the bottom of the card
        let disclaimer = UILabel()
        disclaimer.text = "Suggested ranges for leave-on products. Consult a dermatologist for personalised advice."
        disclaimer.font = .systemFont(ofSize: 11)
        disclaimer.textColor = .ainaTextTertiary
        disclaimer.numberOfLines = 0

        // White card wrapping the rows and disclaimer
        let cardContent = UIStackView(arrangedSubviews: [rowsStack, disclaimer])
        cardContent.axis = .vertical
        cardContent.spacing = 10

        let card = UIView()
        card.backgroundColor = UIColor.white.withAlphaComponent(0.82)
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.18).cgColor
        card.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.09
        card.layer.shadowRadius = 14
        card.layer.shadowOffset = CGSize(width: 0, height: 5)
        card.layer.masksToBounds = false

        cardContent.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(cardContent)
        NSLayoutConstraint.activate([
            cardContent.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            cardContent.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            cardContent.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            cardContent.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
        ])

        // Combine the section title and the card into one vertical block
        let section = UIStackView(arrangedSubviews: [headerStack, card])
        section.axis = .vertical
        section.spacing = 12
        return section
    }

    private func makeConcentrationRow(name: String, conc: IngredientConcentration) -> UIView {
        let nameLabel = UILabel()
        nameLabel.text = name
        nameLabel.font = .systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .ainaTextPrimary
        nameLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let rangePill = PaddingLabel()
        rangePill.text = conc.range
        rangePill.font = .systemFont(ofSize: 12, weight: .semibold)
        rangePill.textColor = UIColor.ainaDustyRose
        rangePill.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.13)
        rangePill.layer.cornerRadius = 10
        rangePill.layer.masksToBounds = true
        rangePill.layer.borderWidth = 0.5
        rangePill.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.35).cgColor
        rangePill.padding = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        rangePill.setContentHuggingPriority(.required, for: .horizontal)
        rangePill.setContentCompressionResistancePriority(.required, for: .horizontal)

        let row = UIStackView(arrangedSubviews: [nameLabel, rangePill])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fill
        row.spacing = 8

        let separator = UIView()
        separator.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.12)
        separator.heightAnchor.constraint(equalToConstant: 0.5).isActive = true

        let wrapper = UIStackView(arrangedSubviews: [row, separator])
        wrapper.axis = .vertical
        wrapper.spacing = 10
        return wrapper
    }
}

// Lists ingredients this product should NOT be mixed with, and why

extension RoutineDetailViewController {

    private func makeConflictsSection() -> UIView? {

        var names: [String] = []
        if let ai = aiStep {
            names = ai.keyIngredients
        } else if let s = step {
            names = dataModel.ingredientNames(for: s)
        }
        guard !names.isEmpty else { return nil }

        struct ConflictRow {
            let avoids: String
            let severity: IngredientConflictEntry.Severity
            let recommendation: String
        }
        struct IngredientGroup {
            let name: String
            let conflicts: [ConflictRow]
        }

        let groups: [IngredientGroup] = names.map { name in
            let avoids = IngredientConflictDatabase.shared.avoids(for: name)
            let rows = avoids.map { ConflictRow(avoids: $0.other, severity: $0.severity, recommendation: $0.recommendation) }
            return IngredientGroup(name: name, conflicts: rows)
        }

        let hasAnyConflict = groups.contains { !$0.conflicts.isEmpty }

        // Use red for the header icon if there are actual conflicts, grey if all clear
        let warnColor = UIColor(red: 200/255, green: 80/255, blue: 80/255, alpha: 1)
        let header = makeSectionHeader("Avoids With",
                                       systemImage: "exclamationmark.triangle.fill",
                                       color: hasAnyConflict ? warnColor : UIColor.ainaTextTertiary)

        // Each ingredient gets its own mini card listing what to avoid
        let groupsStack = UIStackView()
        groupsStack.axis = .vertical
        groupsStack.spacing = 12

        let visibleLimit = 2

        for group in groups {

            // Ingredient name shown at the top of each mini card
            let ingLabel = UILabel()
            ingLabel.text = group.name
            ingLabel.font = .systemFont(ofSize: 14, weight: .bold)
            ingLabel.textColor = UIColor.ainaDustyRose

            // Vertical list of everything this ingredient conflicts with
            let conflictsStack = UIStackView()
            conflictsStack.axis = .vertical
            conflictsStack.spacing = 14

            if group.conflicts.isEmpty {
                let noneLabel = UILabel()
                noneLabel.text = "None – Very stable ingredient"
                noneLabel.font = .systemFont(ofSize: 13)
                noneLabel.textColor = .ainaTextTertiary
                conflictsStack.addArrangedSubview(noneLabel)
            } else {
                // Each conflict item is grouped with its separator so they hide/show together
                for (ci, conflict) in group.conflicts.enumerated() {

                    let badge = PaddingLabel()
                    badge.text = conflict.severity.rawValue.uppercased()
                    badge.font = .systemFont(ofSize: 10, weight: .bold)
                    badge.textColor = .white
                    badge.backgroundColor = conflict.severity.color
                    badge.layer.cornerRadius = 8
                    badge.layer.masksToBounds = true
                    badge.padding = UIEdgeInsets(top: 3, left: 8, bottom: 3, right: 8)
                    badge.setContentHuggingPriority(.required, for: .horizontal)
                    badge.setContentCompressionResistancePriority(.required, for: .horizontal)

                    let avoidLabel = UILabel()
                    avoidLabel.text = "→ \(conflict.avoids)"
                    avoidLabel.font = .systemFont(ofSize: 13, weight: .medium)
                    avoidLabel.textColor = .ainaTextPrimary
                    avoidLabel.numberOfLines = 0
                    avoidLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

                    let topRow = UIStackView(arrangedSubviews: [avoidLabel, badge])
                    topRow.axis = .horizontal
                    topRow.spacing = 8
                    topRow.alignment = .center

                    let rec = UILabel()
                    rec.text = conflict.recommendation
                    rec.font = .systemFont(ofSize: 12)
                    rec.textColor = .ainaTextTertiary
                    rec.numberOfLines = 0

                    // Divider line between conflict items (hidden after the last one)
                    let sep = UIView()
                    sep.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.10)
                    sep.heightAnchor.constraint(equalToConstant: 0.5).isActive = true
                    sep.isHidden = (ci == group.conflicts.count - 1)

                    let conflictItem = UIStackView(arrangedSubviews: [topRow, rec, sep])
                    conflictItem.axis = .vertical
                    conflictItem.spacing = 4

                    // Only show the first 2 conflicts by default — the rest are hidden until "See more" is tapped
                    if ci >= visibleLimit {
                        conflictItem.isHidden = true
                    }

                    conflictsStack.addArrangedSubview(conflictItem)
                }

                // "See more / See less" toggle — appears only when there are more than 2 conflicts
                let overflowCount = group.conflicts.count - visibleLimit
                if overflowCount > 0 {
                    let seeMoreBtn = UIButton(type: .system)
                    seeMoreBtn.setTitle("See \(overflowCount) more →", for: .normal)
                    seeMoreBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
                    seeMoreBtn.setTitleColor(UIColor.ainaDustyRose, for: .normal)
                    seeMoreBtn.contentHorizontalAlignment = .left

                    let seeLessBtn = UIButton(type: .system)
                    seeLessBtn.setTitle("See less ↑", for: .normal)
                    seeLessBtn.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
                    seeLessBtn.setTitleColor(UIColor.ainaDustyRose, for: .normal)
                    seeLessBtn.contentHorizontalAlignment = .left
                    seeLessBtn.isHidden = true

                    let hiddenItems = conflictsStack.arrangedSubviews.filter { $0.isHidden }

                    // Tap "See more" → show hidden conflicts, swap to "See less"
                    seeMoreBtn.addAction(UIAction { [weak seeMoreBtn, weak seeLessBtn, weak conflictsStack] _ in
                        UIView.animate(withDuration: 0.25) {
                            hiddenItems.forEach { $0.isHidden = false }
                            seeMoreBtn?.isHidden = true
                            seeLessBtn?.isHidden = false
                            conflictsStack?.layoutIfNeeded()
                        }
                    }, for: .touchUpInside)

                    // Tap "See less" → hide overflow conflicts again, swap back to "See more"
                    seeLessBtn.addAction(UIAction { [weak seeMoreBtn, weak seeLessBtn, weak conflictsStack] _ in
                        UIView.animate(withDuration: 0.25) {
                            hiddenItems.forEach { $0.isHidden = true }
                            seeLessBtn?.isHidden = true
                            seeMoreBtn?.isHidden = false
                            conflictsStack?.layoutIfNeeded()
                        }
                    }, for: .touchUpInside)

                    conflictsStack.addArrangedSubview(seeMoreBtn)
                    conflictsStack.addArrangedSubview(seeLessBtn)
                }
            }

            // Mini card wrapping the ingredient name and its conflict list
            let innerStack = UIStackView(arrangedSubviews: [ingLabel, conflictsStack])
            innerStack.axis = .vertical
            innerStack.spacing = 12
            innerStack.translatesAutoresizingMaskIntoConstraints = false

            let miniCard = UIView()
            miniCard.backgroundColor = UIColor.white.withAlphaComponent(0.82)
            miniCard.layer.cornerRadius = 16
            miniCard.layer.cornerCurve = .continuous
            miniCard.layer.borderWidth = 1
            miniCard.layer.borderColor = group.conflicts.isEmpty
                ? UIColor.ainaCoralPink.withAlphaComponent(0.15).cgColor
                : UIColor(red: 200/255, green: 80/255, blue: 80/255, alpha: 0.18).cgColor
            miniCard.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
            miniCard.layer.shadowOpacity = 0.07
            miniCard.layer.shadowRadius = 10
            miniCard.layer.shadowOffset = CGSize(width: 0, height: 3)
            miniCard.layer.masksToBounds = false

            miniCard.addSubview(innerStack)
            NSLayoutConstraint.activate([
                innerStack.topAnchor.constraint(equalTo: miniCard.topAnchor, constant: 16),
                innerStack.leadingAnchor.constraint(equalTo: miniCard.leadingAnchor, constant: 16),
                innerStack.trailingAnchor.constraint(equalTo: miniCard.trailingAnchor, constant: -16),
                innerStack.bottomAnchor.constraint(equalTo: miniCard.bottomAnchor, constant: -16)
            ])

            groupsStack.addArrangedSubview(miniCard)
        }

        let section = UIStackView(arrangedSubviews: [header, groupsStack])
        section.axis = .vertical
        section.spacing = 12
        return section
    }
}

// Shows tappable ingredient pills — tap one to open its detail sheet

extension RoutineDetailViewController {

    private func makeIngredientsSection() -> UIView {

        let container = UIView()

        let header = makeSectionHeader("Key Ingredients", systemImage: "drop.fill")

        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 12

        var pillData: [(name: String, id: String?)] = []
        if let ai = aiStep {
            pillData = ai.keyIngredients.map { name in
                (name: name, id: dataModel.matchIngredient(name: name)?.id)
            }
        } else if let step = step {
            let names = dataModel.ingredientNames(for: step)
            pillData = zip(names, step.ingredientIDs).map { (name: $0, id: $1) }
        }

        // Pills size to their content, max 3 per row, left-aligned
        var currentRow: UIStackView?
        var itemsInRow = 0
        let maxPerRow = 3

        for (index, item) in pillData.enumerated() {
            if itemsInRow == 0 || itemsInRow >= maxPerRow {
                currentRow = UIStackView()
                currentRow!.axis = .horizontal
                currentRow!.spacing = 10
                currentRow!.alignment = .center
                grid.addArrangedSubview(currentRow!)
                itemsInRow = 0
            }

            let pill = PaddingLabel()
            pill.text = item.name
            pill.textAlignment = .center
            pill.font = .systemFont(ofSize: 14, weight: .semibold)
            pill.layer.cornerRadius = 20
            pill.layer.cornerCurve = .continuous
            pill.layer.masksToBounds = true
            pill.padding = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
            pill.setContentHuggingPriority(.required, for: .horizontal)
            pill.setContentCompressionResistancePriority(.required, for: .horizontal)

            if index == 0 {
                pill.textColor = .white
                pill.backgroundColor = UIColor.ainaDustyRose
            } else {
                pill.textColor = UIColor.ainaDustyRose
                pill.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.13)
                pill.layer.borderWidth = 1
                pill.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.35).cgColor
            }

            if let id = item.id {
                pill.isUserInteractionEnabled = true
                pill.accessibilityIdentifier = id
                let tap = UITapGestureRecognizer(target: self, action: #selector(openIngredient(_:)))
                pill.addGestureRecognizer(tap)
            }
            currentRow?.addArrangedSubview(pill)
            itemsInRow += 1
        }

        // Spacer pushes the last row's pills to the left
        if let lastRow = grid.arrangedSubviews.last as? UIStackView {
            let spacer = UIView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            lastRow.addArrangedSubview(spacer)
        }

        let stack = UIStackView(arrangedSubviews: [header, grid])
        stack.axis = .vertical
        stack.spacing = 14

        container.addSubview(stack)
        stack.pinEdges(to: container, padding: 0)

        return container
    }
}

// Top header showing the step number, product type, and product name

extension RoutineDetailViewController {

    private func makeHeader() -> UIView {

        let container = UIView()

        let stepLabel = UILabel()
        stepLabel.font = .systemFont(ofSize: 11, weight: .bold)
        stepLabel.textColor = .ainaDustyRose
        if let s = step {
            stepLabel.text = "STEP \(s.stepOrder) · \(s.timeOfDay.rawValue.uppercased())"
        } else if let ai = aiStep {
            stepLabel.text = "STEP \(ai.stepNumber)"
        }

        let titleLabel = UILabel()
        titleLabel.textColor = .ainaTextPrimary
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 17)
        subtitleLabel.textColor = .ainaTextSecondary
        if let ai = aiStep {
            titleLabel.text = ai.productType.rawValue.capitalized
            subtitleLabel.text = ai.productName
        } else {
            titleLabel.text = step?.type.rawValue.capitalized ?? ""
            subtitleLabel.text = step?.stepTitle ?? ""
        }

        let stack = UIStackView(arrangedSubviews: [stepLabel, titleLabel, subtitleLabel])
        stack.axis = .vertical
        stack.spacing = 2
        stack.setCustomSpacing(6, after: stepLabel)
        stack.setCustomSpacing(4, after: titleLabel)

        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
}
extension RoutineDetailViewController {

    private func buildUI() {

        let header = makeHeader()
        let videoCard = makeVideoCard()
        let description = makeDescriptionSection()
        let instruction = makeInstructionSection()

        contentStack.addArrangedSubview(header)
        contentStack.setCustomSpacing(20, after: header)

        contentStack.addArrangedSubview(videoCard)
        contentStack.setCustomSpacing(24, after: videoCard)

        contentStack.addArrangedSubview(description)
        contentStack.setCustomSpacing(28, after: description)

        contentStack.addArrangedSubview(instruction)
        contentStack.setCustomSpacing(32, after: instruction)

        if let whySection = makeWhySuggestedSection() {
            contentStack.addArrangedSubview(whySection)
            contentStack.setCustomSpacing(28, after: whySection)
        }
        if let concSection = makeConcentrationSection() {
            contentStack.addArrangedSubview(concSection)
            contentStack.setCustomSpacing(28, after: concSection)
        }
        if let conflictsSection = makeConflictsSection() {
            contentStack.addArrangedSubview(conflictsSection)
            contentStack.setCustomSpacing(32, after: conflictsSection)
        }

        contentStack.addArrangedSubview(makeIngredientsSection())

        let infoCard = IngredientInfoCardView()
        contentStack.addArrangedSubview(infoCard)

        // Extra space at the bottom so content doesn't sit right at the edge
        let bottomSpacer = UIView()
        bottomSpacer.heightAnchor.constraint(equalToConstant: 32).isActive = true
        contentStack.addArrangedSubview(bottomSpacer)
    }

}

private func makeIngredientInfoCard() -> UIView {

    let card = UIView()
    card.layer.cornerRadius = 20
    card.layer.borderWidth = 1
    card.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.25).cgColor
    card.backgroundColor = UIColor.ainaTintedGlassMedium

    let label = UILabel()
    label.numberOfLines = 0
    label.font = .systemFont(ofSize: 15)
    label.textAlignment = .center

    // Styled hint text — highlights "Tap any ingredient pill" in pink
    let text = NSMutableAttributedString(
        string: "💡 Curious about an ingredient? ",
        attributes: [.foregroundColor: UIColor.secondaryLabel]
    )

    let highlight = NSAttributedString(
        string: "Tap any ingredient pill ",
        attributes: [
            .foregroundColor: UIColor.ainaCoralPink

        ]
    )

    let end = NSAttributedString(
        string: "to learn what it does for your skin.",
        attributes: [.foregroundColor: UIColor.secondaryLabel]
    )

    text.append(highlight)
    text.append(end)

    label.attributedText = text

    card.addSubview(label)
    label.translatesAutoresizingMaskIntoConstraints = false

    NSLayoutConstraint.activate([
        label.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
        label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
        label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16)
    ])

    return card
}

// Utility: pins all four edges of a view to another view with equal padding

extension UIView {

    func pinEdges(to view: UIView, padding: CGFloat) {

        translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: view.topAnchor, constant: padding),
            leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: padding),
            trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -padding),
            bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -padding)
        ])
    }
}
// Reusable glass-style card used as a visual container throughout the page

extension RoutineDetailViewController {

    private func makeCard() -> UIView {

        let card = UIView()

        card.backgroundColor = .ainaGlassElevated
        card.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.10
        card.layer.shadowRadius = 16
        card.layer.shadowOffset = CGSize(width: 0, height: 8)
        card.layer.cornerRadius = 20
        card.clipsToBounds = true

        return card
    }

    // Reusable section header with a small icon and bold uppercase title
    private func makeSectionHeader(_ text: String, systemImage: String, color: UIColor = .ainaDustyRose) -> UIView {
        let iconContainer = UIView()
        iconContainer.backgroundColor = color.withAlphaComponent(0.15)
        iconContainer.layer.cornerRadius = 10
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconContainer.widthAnchor.constraint(equalToConstant: 28),
            iconContainer.heightAnchor.constraint(equalToConstant: 28)
        ])

        let iconView = UIImageView(image: UIImage(systemName: systemImage)?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
        iconView.tintColor = color
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.addSubview(iconView)
        NSLayoutConstraint.activate([
            iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor)
        ])

        let label = UILabel()
        label.text = text.uppercased()
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .ainaTextPrimary

        let row = UIStackView(arrangedSubviews: [iconContainer, label])
        row.axis = .horizontal
        row.spacing = 8
        row.alignment = .center
        return row
    }
}
