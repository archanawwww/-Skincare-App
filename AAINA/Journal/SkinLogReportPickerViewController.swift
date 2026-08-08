//
//  SkinLogReportPickerViewController.swift
//  AAINA
//

import UIKit

class SkinLogReportPickerViewController: UIViewController {

    var allEntries: [SkinLogEntry] = []

    // MARK: - State
    private var fromDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
    private var toDate   = Date()

    // MARK: - Views
    private let scrollView   = UIScrollView()
    private let contentView  = UIView()
    private let fromValueLbl = UILabel()
    private let toValueLbl   = UILabel()
    private let countLabel   = UILabel()
    private let generateBtn  = UIButton(type: .custom)

    private static let displayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "d MMM yyyy"; return f
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        setupNav()
        setupScrollView()
        setupContent()
        setupGenerateButton()
        refresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.applyAINABackground()
        applyGradient()
    }

    // MARK: - Nav

    private func setupNav() {
        title = "Export Report"
        navigationController?.navigationBar.prefersLargeTitles = false
        let cancel = UIBarButtonItem(title: "Cancel", style: .plain,
                                    target: self, action: #selector(cancelTapped))
        cancel.tintColor = .ainaDustyRose
        navigationItem.leftBarButtonItem = cancel
    }

    // MARK: - Scroll

    private func setupScrollView() {
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    // MARK: - Content

    private func setupContent() {
        // Subtitle
        let subtitleLbl = UILabel()
        subtitleLbl.text          = "Generate a PDF of your skin reports for any date range."
        subtitleLbl.font          = .systemFont(ofSize: 14)
        subtitleLbl.textColor     = .secondaryLabel
        subtitleLbl.numberOfLines = 0
        subtitleLbl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLbl)

        // Date range card
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.applyGlass(cornerRadius: 20)
        contentView.addSubview(card)

        // Header row inside card
        let headerBadge = makeIconBadge()
        let headerLbl   = UILabel()
        headerLbl.attributedText = NSAttributedString(string: "DATE RANGE", attributes: [
            .font: UIFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.secondaryLabel,
            .kern: 1.4
        ])
        headerLbl.translatesAutoresizingMaskIntoConstraints = false

        let sep1 = makeSep()
        let fromRow = makeRow(label: "From", valueLabel: fromValueLbl, action: #selector(fromTapped))
        let sep2    = makeSep()
        let toRow   = makeRow(label: "To",   valueLabel: toValueLbl,   action: #selector(toTapped))

        [headerBadge, headerLbl, sep1, fromRow, sep2, toRow].forEach { card.addSubview($0) }

        NSLayoutConstraint.activate([
            headerBadge.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            headerBadge.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),

            headerLbl.centerYAnchor.constraint(equalTo: headerBadge.centerYAnchor),
            headerLbl.leadingAnchor.constraint(equalTo: headerBadge.trailingAnchor, constant: 10),

            sep1.topAnchor.constraint(equalTo: headerBadge.bottomAnchor, constant: 12),
            sep1.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            sep1.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            fromRow.topAnchor.constraint(equalTo: sep1.bottomAnchor),
            fromRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            fromRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            fromRow.heightAnchor.constraint(equalToConstant: 52),

            sep2.topAnchor.constraint(equalTo: fromRow.bottomAnchor),
            sep2.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            sep2.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            toRow.topAnchor.constraint(equalTo: sep2.bottomAnchor),
            toRow.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            toRow.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            toRow.heightAnchor.constraint(equalToConstant: 52),
            toRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -4)
        ])

        // Count label
        countLabel.font          = .systemFont(ofSize: 13)
        countLabel.textColor     = .secondaryLabel
        countLabel.textAlignment = .center
        countLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(countLabel)

        NSLayoutConstraint.activate([
            subtitleLbl.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            subtitleLbl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLbl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),

            card.topAnchor.constraint(equalTo: subtitleLbl.bottomAnchor, constant: 16),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            countLabel.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 16),
            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20)
        ])
    }

    // MARK: - Row builder

    private func makeRow(label: String, valueLabel: UILabel, action: Selector) -> UIView {
        let row = UIView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let titleLbl = UILabel()
        titleLbl.text      = label
        titleLbl.font      = .systemFont(ofSize: 15, weight: .medium)
        titleLbl.textColor = .label
        titleLbl.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.font          = .systemFont(ofSize: 15)
        valueLabel.textColor     = .ainaCoralPink
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right",
            withConfiguration: UIImage.SymbolConfiguration(scale: .small)))
        chevron.tintColor = UIColor.ainaDustyRose.withAlphaComponent(0.5)
        chevron.translatesAutoresizingMaskIntoConstraints = false

        let tap = UITapGestureRecognizer(target: self, action: action)
        row.addGestureRecognizer(tap)
        row.isUserInteractionEnabled = true

        [titleLbl, valueLabel, chevron].forEach { row.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLbl.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 20),
            titleLbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            chevron.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            chevron.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            valueLabel.trailingAnchor.constraint(equalTo: chevron.leadingAnchor, constant: -6),
            valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valueLabel.leadingAnchor.constraint(greaterThanOrEqualTo: titleLbl.trailingAnchor, constant: 8)
        ])
        return row
    }

    private func makeIconBadge() -> UIView {
        let v = UIView()
        v.backgroundColor    = .ainaTintedGlassMedium
        v.layer.cornerRadius = 18
        v.translatesAutoresizingMaskIntoConstraints = false
        let icon = UIImageView(image: UIImage(systemName: "calendar"))
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

    private func makeSep() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.12)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return v
    }

    // MARK: - Generate button

    private func setupGenerateButton() {
        generateBtn.setTitle("Generate PDF", for: .normal)
        generateBtn.setTitleColor(.white, for: .normal)
        generateBtn.titleLabel?.font   = .systemFont(ofSize: 17, weight: .semibold)
        generateBtn.layer.cornerRadius = 16
        generateBtn.layer.masksToBounds = false
        generateBtn.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        generateBtn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(generateBtn)
        NSLayoutConstraint.activate([
            generateBtn.topAnchor.constraint(equalTo: countLabel.bottomAnchor, constant: 24),
            generateBtn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            generateBtn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            generateBtn.heightAnchor.constraint(equalToConstant: 56),
            generateBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -40)
        ])
    }

    private func applyGradient() {
        guard generateBtn.bounds.width > 0 else { return }
        let name = "genGrad"
        if let ex = generateBtn.layer.sublayers?.first(where: { $0.name == name }) as? CAGradientLayer {
            ex.frame = generateBtn.bounds; return
        }
        let grad        = CAGradientLayer()
        grad.name       = name
        grad.colors     = [UIColor.ainaCoralPink.cgColor, UIColor.ainaDustyRose.cgColor]
        grad.startPoint = CGPoint(x: 0, y: 0.5)
        grad.endPoint   = CGPoint(x: 1, y: 0.5)
        grad.cornerRadius = 16
        grad.frame      = generateBtn.bounds
        generateBtn.layer.insertSublayer(grad, at: 0)
        generateBtn.layer.shadowColor   = UIColor.ainaDustyRose.cgColor
        generateBtn.layer.shadowOpacity = 0.35
        generateBtn.layer.shadowOffset  = CGSize(width: 0, height: 8)
        generateBtn.layer.shadowRadius  = 12
    }

    // MARK: - Refresh

    private func refresh() {
        fromValueLbl.text = Self.displayFmt.string(from: fromDate)
        toValueLbl.text   = Self.displayFmt.string(from: toDate)
        let count = filteredEntries().count
        countLabel.text = count == 0
            ? "No entries in this range"
            : "\(count) \(count == 1 ? "entry" : "entries") will be included"
    }

    private func filteredEntries() -> [SkinLogEntry] {
        let cal  = Calendar.current
        let from = cal.startOfDay(for: fromDate)
        let to   = cal.startOfDay(for: toDate)
        return allEntries.filter {
            let d = cal.startOfDay(for: $0.date)
            return d >= from && d <= to
        }
    }

    // MARK: - Date picker presentation

    private func presentPicker(title: String, current: Date, max: Date? = nil, completion: @escaping (Date) -> Void) {
        let picker = UIDatePicker()
        picker.datePickerMode        = .date
        picker.preferredDatePickerStyle = .wheels
        picker.date                  = current
        picker.maximumDate           = max
        picker.tintColor             = .ainaCoralPink
        picker.translatesAutoresizingMaskIntoConstraints = false

        let sheet = UIAlertController(title: title, message: "\n\n\n\n\n\n\n\n\n\n", preferredStyle: .actionSheet)
        sheet.view.addSubview(picker)

        NSLayoutConstraint.activate([
            picker.leadingAnchor.constraint(equalTo: sheet.view.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: sheet.view.trailingAnchor),
            picker.topAnchor.constraint(equalTo: sheet.view.topAnchor, constant: 44)
        ])

        sheet.addAction(UIAlertAction(title: "Done", style: .default) { _ in
            completion(picker.date)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }

    // MARK: - Actions

    @objc private func cancelTapped() { dismiss(animated: true) }

    @objc private func fromTapped() {
        presentPicker(title: "From Date", current: fromDate, max: toDate) { [weak self] date in
            self?.fromDate = date
            self?.refresh()
        }
    }

    @objc private func toTapped() {
        presentPicker(title: "To Date", current: toDate, max: Date()) { [weak self] picked in
            guard let self else { return }
            if picked < self.fromDate { self.fromDate = picked }
            self.toDate = picked
            self.refresh()
        }
    }

    @objc private func generateTapped() {
        let entries = filteredEntries()
        guard !entries.isEmpty else {
            let alert = UIAlertController(
                title: "No Entries",
                message: "No skin report entries found in the selected range.",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }
        let url = SkinLogPDFExporter.generateReport(entries: entries, from: fromDate, to: toDate)
        let av  = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        present(av, animated: true)
    }
}
