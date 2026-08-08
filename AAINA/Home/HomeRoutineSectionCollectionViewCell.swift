//
//  HomeRoutineSectionCollectionViewCell.swift
//  AAINA
//
//  Created by GEU on 28/03/26.
//

import UIKit

protocol HomeRoutineSectionCollectionViewCellDelegate: AnyObject {
    func homeRoutineCell(_ cell: HomeRoutineSectionCollectionViewCell, didChangeSegment index: Int)
    func homeRoutineCell(_ cell: HomeRoutineSectionCollectionViewCell, didToggleStepAt index: Int, isCompleted: Bool)
}

final class HomeRoutineSectionCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "HomeRoutineSectionCollectionViewCell"
    
    weak var delegate: HomeRoutineSectionCollectionViewCellDelegate?
    
    private var steps: [String] = []
    private var completedStates: [Bool] = []
    private var selectedSegment: Int = 0   // 0 = Morning, 1 = Evening
    
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var segmentControl: UISegmentedControl!
    @IBOutlet weak var listStackView: UIStackView!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        containerView.layer.cornerRadius = 24
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        clearStepRows()
    }
    
    private func setupUI() {
        overrideUserInterfaceStyle = .light
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.88)
        containerView.layer.cornerRadius = 24
        containerView.layer.cornerCurve = .continuous
        containerView.layer.masksToBounds = false
        containerView.layer.borderWidth = 0
        containerView.layer.borderColor = UIColor.black.withAlphaComponent(0.06).cgColor
        containerView.layer.shadowColor = UIColor.black.cgColor
        containerView.layer.shadowOpacity = 0.07
        containerView.layer.shadowOffset = CGSize(width: 0, height: 6)
        containerView.layer.shadowRadius = 18
        
        listStackView.axis = .vertical
        listStackView.spacing = 18
        listStackView.alignment = .fill
        listStackView.distribution = .fill
        
        setupSegmentControl()
    }
    
    private func setupSegmentControl() {
        segmentControl.removeAllSegments()
        segmentControl.insertSegment(withTitle: "Morning", at: 0, animated: false)
        segmentControl.insertSegment(withTitle: "Evening", at: 1, animated: false)
        segmentControl.selectedSegmentIndex = selectedSegment
        segmentControl.selectedSegmentTintColor = UIColor.ainaCoralPink
        segmentControl.backgroundColor = UIColor.white.withAlphaComponent(0.45)
        segmentControl.setTitleTextAttributes([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 13, weight: .semibold)
        ], for: .selected)
        segmentControl.setTitleTextAttributes([
            .foregroundColor: UIColor.ainaTextPrimary,
            .font: UIFont.systemFont(ofSize: 13, weight: .medium)
        ], for: .normal)
    }
    
    func configure(
        steps: [String],
        completedStates: [Bool],
        selectedSegment: Int
    ) {
        self.steps = steps
        self.selectedSegment = selectedSegment
        self.completedStates = steps.enumerated().map { index, _ in
            index < completedStates.count ? completedStates[index] : false
        }
        
        segmentControl.selectedSegmentIndex = selectedSegment
        reloadSteps()
    }
    
    private func clearStepRows() {
        listStackView.arrangedSubviews.forEach {
            listStackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
    }
    
    private func reloadSteps() {
        clearStepRows()
        
        for (index, step) in steps.enumerated() {
            let row = makeStepRow(title: step, index: index)
            listStackView.addArrangedSubview(row)
        }
    }
    
    private func makeStepRow(title: String, index: Int) -> UIView {
        let rowView = UIView()
        rowView.translatesAutoresizingMaskIntoConstraints = false
        
        let numberLabel = UILabel()
        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        numberLabel.text = "\(index + 1)"
        numberLabel.textAlignment = .center
        numberLabel.textColor = UIColor.ainaCoralPink.withAlphaComponent(0.9)
        numberLabel.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        numberLabel.layer.cornerRadius = 14
        numberLabel.layer.borderWidth = 1.5
        numberLabel.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.9).cgColor
        numberLabel.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.08)
        numberLabel.clipsToBounds = true
        
        let titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = title
        titleLabel.textColor = UIColor.ainaTextPrimary
        titleLabel.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
        
        let statusButton = UIButton(type: .system)
        statusButton.translatesAutoresizingMaskIntoConstraints = false
        statusButton.tag = index
        statusButton.layer.cornerRadius = 14
        statusButton.clipsToBounds = true
        statusButton.addTarget(self, action: #selector(handleStatusButtonTapped(_:)), for: .touchUpInside)
        
        updateStatusButtonUI(statusButton, isCompleted: completedStates[index])
        
        rowView.addSubview(numberLabel)
        rowView.addSubview(titleLabel)
        rowView.addSubview(statusButton)
        
        NSLayoutConstraint.activate([
            rowView.heightAnchor.constraint(equalToConstant: 42),
            
            numberLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
            numberLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            numberLabel.widthAnchor.constraint(equalToConstant: 28),
            numberLabel.heightAnchor.constraint(equalToConstant: 28),
            
            titleLabel.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 14),
            titleLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            
            statusButton.leadingAnchor.constraint(greaterThanOrEqualTo: titleLabel.trailingAnchor, constant: 12),
            statusButton.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
            statusButton.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            statusButton.widthAnchor.constraint(equalToConstant: 28),
            statusButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        return rowView
    }
    
    private func updateStatusButtonUI(_ button: UIButton, isCompleted: Bool) {
        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)
        
        if isCompleted {
            button.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.9)
            button.layer.borderWidth = 0
            
            button.tintColor = .white
            button.setImage(UIImage(systemName: "checkmark", withConfiguration: symbolConfig), for: .normal)
            
        } else {
            button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            button.layer.borderWidth = 1
            button.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.9).cgColor
            
            button.tintColor = UIColor.white.withAlphaComponent(0.5)
            button.setImage(UIImage(systemName: "", withConfiguration: symbolConfig), for: .normal)
        }
    }
    
    @IBAction func segmentValueChanged(_ sender: UISegmentedControl) {
        selectedSegment = sender.selectedSegmentIndex
        delegate?.homeRoutineCell(self, didChangeSegment: sender.selectedSegmentIndex)
    }
    
    @IBAction func handleStatusButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        
        guard index >= 0, index < completedStates.count else { return }
        
        completedStates[index].toggle()
        updateStatusButtonUI(sender, isCompleted: completedStates[index])
        delegate?.homeRoutineCell(self, didToggleStepAt: index, isCompleted: completedStates[index])
    }
}
