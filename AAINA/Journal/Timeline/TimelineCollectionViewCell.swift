import UIKit

class TimelineCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var dayLabel: UILabel!
    @IBOutlet weak var dateLabel: UILabel!
    
    static let reuseIdentifier = "TimelineCollectionViewCell"

    private let faceScanIndicator = UIView()
    private let weeklyInputIndicator = UIView()
    private let insightSelectionPill = UIView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        dayLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        dayLabel.textColor = .secondaryLabel
        dayLabel.textAlignment = .center
        
        dateLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        dateLabel.backgroundColor = UIColor.ainaLightBlush.withAlphaComponent(0.4)
        dateLabel.clipsToBounds = true
        dateLabel.textAlignment = .center

        insightSelectionPill.backgroundColor = UIColor.ainaLightBlush.withAlphaComponent(0.72)
        insightSelectionPill.layer.borderWidth = 1
        insightSelectionPill.layer.borderColor = UIColor.white.withAlphaComponent(0.9).cgColor
        insightSelectionPill.isHidden = true
        contentView.insertSubview(insightSelectionPill, at: 0)

        setupInsightIndicator(faceScanIndicator, color: .ainaSageGreen)
        setupInsightIndicator(weeklyInputIndicator, color: .ainaDustyRose)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let w = contentView.bounds.width
        dayLabel.frame = CGRect(x: 0, y: 8, width: w, height: 16)
        dateLabel.frame = CGRect(x: (w - 44) / 2, y: 28, width: 44, height: 44)
        dateLabel.layer.cornerRadius = 22
        dateLabel.clipsToBounds = true

        insightSelectionPill.frame = CGRect(x: (w - 54) / 2, y: 24, width: 54, height: 76)
        insightSelectionPill.layer.cornerRadius = 27
        contentView.sendSubviewToBack(insightSelectionPill)

        faceScanIndicator.frame = CGRect(x: (w - 17) / 2, y: 78, width: 6, height: 6)
        weeklyInputIndicator.frame = CGRect(x: (w + 5) / 2, y: 78, width: 6, height: 6)
        faceScanIndicator.layer.cornerRadius = 3
        weeklyInputIndicator.layer.cornerRadius = 3
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        dateLabel.layer.borderWidth = 0
        dateLabel.layer.borderColor = nil
        dayLabel.textColor = .secondaryLabel
        contentView.alpha = 1
        insightSelectionPill.isHidden = true
        faceScanIndicator.isHidden = true
        weeklyInputIndicator.isHidden = true
    }
    
    func configure(day: String, date: String, isToday: Bool, isSelected: Bool) {
        
        dayLabel.text = day
        dateLabel.text = date
        
        // RESET
        dateLabel.layer.borderWidth = 0
        dateLabel.layer.borderColor = nil
        dateLabel.layer.shadowOpacity = 0
        
        // 🎯 SELECTED (like 30)
        if isSelected {
            
            dateLabel.backgroundColor = UIColor.systemPink.withAlphaComponent(0.3)
            dateLabel.textColor = .white
            
            // ✨ SOFT GLOW (inspo effect)
            dateLabel.layer.shadowColor = UIColor.ainaCoralPink.cgColor
            dateLabel.layer.shadowOpacity = 0.4
            dateLabel.layer.shadowRadius = 8
            dateLabel.layer.shadowOffset = .zero
            
        }
        
        // 🌸 TODAY (but not selected)
        else if isToday {
            
            dateLabel.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.18)
            dateLabel.textColor = UIColor.ainaTextPrimary
            
            dateLabel.layer.borderWidth = 1
            dateLabel.layer.borderColor = UIColor.ainaCoralPink.withAlphaComponent(0.25).cgColor
        }
        
        // ⚪ NORMAL (28, 29 — YOUR MAIN FIX)
        else {
            
            // ✨ SOFT WHITE (NOT PINK)
            dateLabel.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            
            // ✨ SUBTLE BORDER (important)
            dateLabel.layer.borderWidth = 1
            dateLabel.layer.borderColor = UIColor.white.withAlphaComponent(1).cgColor
            
            dateLabel.textColor = UIColor.ainaTextPrimary
        }
    }

    func configureForInsight(day: String,
                             date: String,
                             isToday: Bool,
                             isSelected: Bool,
                             hasFaceScan: Bool,
                             hasWeeklyInput: Bool,
                             isFuture: Bool) {
        configure(day: day, date: date, isToday: isToday, isSelected: isSelected)

        insightSelectionPill.isHidden = true
        faceScanIndicator.isHidden = !hasFaceScan
        weeklyInputIndicator.isHidden = !hasWeeklyInput
        contentView.alpha = 1
        dayLabel.textColor = .secondaryLabel
        dateLabel.layer.shadowOpacity = 0

        if isToday {
            dateLabel.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.72)
            dateLabel.textColor = .white
            dateLabel.layer.borderWidth = 0
            dateLabel.layer.borderColor = nil
        } else if isSelected {
            dateLabel.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.72)
            dateLabel.textColor = .white
            dateLabel.layer.borderWidth = 0
            dateLabel.layer.borderColor = nil
        } else {
            dateLabel.backgroundColor = UIColor.white.withAlphaComponent(0.4)
            dateLabel.textColor = UIColor.ainaTextPrimary
            dateLabel.layer.borderWidth = 1
            dateLabel.layer.borderColor = UIColor.white.withAlphaComponent(1).cgColor
        }

        if isFuture {
            faceScanIndicator.isHidden = true
            weeklyInputIndicator.isHidden = true
            dayLabel.textColor = UIColor.ainaTextTertiary.withAlphaComponent(0.55)
            dateLabel.backgroundColor = UIColor.white.withAlphaComponent(0.22)
            dateLabel.textColor = UIColor.ainaTextTertiary.withAlphaComponent(0.55)
            dateLabel.layer.borderWidth = 1
            dateLabel.layer.borderColor = UIColor.white.withAlphaComponent(0.45).cgColor
            contentView.alpha = 0.65
        }
    }

    private func setupInsightIndicator(_ indicator: UIView, color: UIColor) {
        indicator.backgroundColor = color
        indicator.isHidden = true
        indicator.clipsToBounds = true
        contentView.addSubview(indicator)
    }
}
