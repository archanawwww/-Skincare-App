//
//  InsightSectionCollectionViewCell.swift
//  AAINA
//

import UIKit

final class InsightSectionCollectionViewCell: UICollectionViewCell {

    static let identifier = "InsightSectionCollectionViewCell"

    var onActionTapped: (() -> Void)?
    private var timelineDates: [Date] = []
    private var highlightedDate: Date = Date()
    private let containerView = UIView()
    private let actionButton = UIButton(type: .system)
    private let timelineCollectionView = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewFlowLayout())
    private var didBuildInsightLayout = false

    // MARK: - Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // Rounded card
        containerView.layer.cornerRadius = 36

        // Pill button
        actionButton.layer.cornerRadius = actionButton.bounds.height / 2
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        onActionTapped = nil
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        buildInsightLayoutIfNeeded()

        // Card styling
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        containerView.layer.cornerRadius = 36
        containerView.layer.cornerCurve = .continuous
        containerView.layer.masksToBounds = false

        // Subtle shadow (matches your UI)
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.06
        containerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        containerView.layer.shadowRadius = 16

        // Button styling
        actionButton.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.25)
        actionButton.setTitleColor(UIColor.ainaTextPrimary, for: .normal)
        actionButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        actionButton.clipsToBounds = true

    }

    // MARK: - Configure

    func configure(description: String, highlightedDate: Date = Date()) {
        self.highlightedDate = Calendar.current.startOfDay(for: Date())
        buildTimelineDates()
        timelineCollectionView.reloadData()
        actionButton.setTitle("View Full Analysis", for: .normal)
    }

    @objc private func actionButtonTapped(_ sender: UIButton) {
        onActionTapped?()
    }

    private func buildInsightLayoutIfNeeded() {
        guard !didBuildInsightLayout else { return }
        didBuildInsightLayout = true

        containerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(containerView)

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
        timelineCollectionView.register(
            UINib(nibName: "TimelineCollectionViewCell", bundle: nil),
            forCellWithReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier
        )

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.layer.cornerCurve = .continuous
        actionButton.addTarget(self, action: #selector(actionButtonTapped(_:)), for: .touchUpInside)

        containerView.addSubview(timelineCollectionView)
        containerView.addSubview(actionButton)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            containerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            containerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            containerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),

            timelineCollectionView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 22),
            timelineCollectionView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            timelineCollectionView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            timelineCollectionView.heightAnchor.constraint(equalToConstant: 92),

            actionButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 34),
            actionButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -34),
            actionButton.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -18),
            actionButton.heightAnchor.constraint(equalToConstant: 48)
        ])

        buildTimelineDates()
    }

    private func buildTimelineDates() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let sunday = calendar.date(byAdding: .day, value: 1 - weekday, to: today) ?? today
        timelineDates = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: sunday) }
    }
}

extension InsightSectionCollectionViewCell: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        timelineDates.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: TimelineCollectionViewCell.reuseIdentifier,
            for: indexPath
        ) as! TimelineCollectionViewCell
        let date = timelineDates[indexPath.item]
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let day = String(formatter.string(from: date).prefix(1))
        let dateText = String(format: "%02d", Calendar.current.component(.day, from: date))
        cell.configureForInsight(
            day: day,
            date: dateText,
            isToday: Calendar.current.isDateInToday(date),
            isSelected: false,
            hasFaceScan: InsightStore.shared.hasFaceScan(on: date),
            hasWeeklyInput: InsightStore.shared.hasWeeklyInput(on: date),
            isFuture: date > Calendar.current.startOfDay(for: Date())
        )
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let insets: CGFloat = 0
        let spacing: CGFloat = 12
        let width = (collectionView.bounds.width - insets - spacing) / 7
        return CGSize(width: width, height: 90)
    }
}
