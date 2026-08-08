//
//  ResultProfileCollectionViewCell.swift
//  AAINA
//
//  Created by GEU on 26/03/26.
//

import UIKit

final class ResultProfileCollectionViewCell: UICollectionViewCell {
    
    static let identifier = "ResultProfileCollectionViewCell"
    
    @IBOutlet weak var Image: UIImageView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var ageCardView: UIView!
    @IBOutlet weak var AgeLabel: UILabel!
    
    @IBOutlet weak var tZoneCardView: UIView!
    @IBOutlet weak var tZoneTitleLabel: UILabel!
    @IBOutlet weak var tZoneValueLabel: UILabel!
    
    @IBOutlet weak var uZoneCardView: UIView!
    @IBOutlet weak var uZoneTitleLabel: UILabel!
    @IBOutlet weak var uZoneValueLabel: UILabel!
    
    @IBOutlet weak var cZoneCardView: UIView!
    @IBOutlet weak var cZoneTitleLabel: UILabel!
    @IBOutlet weak var cZoneValueLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        cardView.layer.shadowPath = UIBezierPath(
            roundedRect: cardView.bounds,
            cornerRadius: cardView.layer.cornerRadius
        ).cgPath
        Image.layer.cornerRadius = Image.bounds.height / 2
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        
        cardView.backgroundColor = .ainaGlassElevated
        cardView.layer.cornerRadius = 36
        cardView.layer.cornerCurve = .continuous
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        cardView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        cardView.layer.shadowOpacity = 0.12
        cardView.layer.shadowRadius = 18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 6)
        cardView.layer.masksToBounds = false
        
        Image.image = UIImage(named: "background")
        Image.contentMode = .scaleAspectFill
        Image.clipsToBounds = true
        Image.layer.borderWidth = 8
        Image.layer.borderColor = UIColor.white.withAlphaComponent(0.55).cgColor
        Image.backgroundColor = .ainaTintedGlassLight
        
        nameLabel.font = .systemFont(ofSize: 31, weight: .semibold)
        nameLabel.textColor = .ainaTextPrimary
        nameLabel.numberOfLines = 1
        nameLabel.adjustsFontSizeToFitWidth = true
        nameLabel.minimumScaleFactor = 0.72
        
        ageCardView.subviews
            .filter { $0.tag == 9201 }
            .forEach { $0.removeFromSuperview() }
        ageCardView.backgroundColor = .clear
        ageCardView.layer.borderWidth = 0
        ageCardView.layer.shadowOpacity = 0
        ageCardView.clipsToBounds = false
        AgeLabel.font = .systemFont(ofSize: 23, weight: .regular)
        AgeLabel.textColor = .ainaTextSecondary
        AgeLabel.numberOfLines = 1
        AgeLabel.textAlignment = .left
        AgeLabel.adjustsFontSizeToFitWidth = true
        AgeLabel.minimumScaleFactor = 0.8
        
        tZoneTitleLabel.text = "T-zone:"
        uZoneTitleLabel.text = "U-zone:"
        cZoneTitleLabel.text = "C-zone:"
        
        [tZoneCardView, uZoneCardView, cZoneCardView].forEach {
            guard let view = $0 else { return }
            applyGlass(to: view, cornerRadius: 16)
        }
        
        [tZoneTitleLabel, uZoneTitleLabel, cZoneTitleLabel].forEach {
            $0?.font = .systemFont(ofSize: 15, weight: .regular)
            $0?.textColor = .ainaTextPrimary
            $0?.textAlignment = .center
        }
        
        [tZoneValueLabel, uZoneValueLabel, cZoneValueLabel].forEach {
            $0?.font = .systemFont(ofSize: 17, weight: .regular)
            $0?.textColor = .ainaTextPrimary
            $0?.textAlignment = .center
            $0?.adjustsFontSizeToFitWidth = true
            $0?.minimumScaleFactor = 0.75
        }
    }
    
    func configure(with onboardingData: OnboardingData, name: String = "Priya") {
        nameLabel.text = name
        
        if let age = calculateAge(from: onboardingData.birthYear) {
            AgeLabel.text = "\(age) years"
        } else {
            AgeLabel.text = ""
        }
        
        tZoneValueLabel.text = displayText(for: onboardingData.tZone)
        uZoneValueLabel.text = displayText(for: onboardingData.uZone)
        cZoneValueLabel.text = displayText(for: onboardingData.cZone)
    }
    
    private func calculateAge(from birthYear: Int?) -> Int? {
        guard let birthYear = birthYear else { return nil }
        let currentYear = Calendar.current.component(.year, from: Date())
        return currentYear - birthYear
    }
    
    private func displayText(for type: SkinType?) -> String {
        guard let type = type else { return "Normal" }
        
        let raw = type.rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Normal" }
        
        return raw.prefix(1).uppercased() + raw.dropFirst().lowercased()
    }
    
    private func applyGlass(to view: UIView, cornerRadius: CGFloat) {
        view.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        view.layer.cornerRadius = cornerRadius
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = false
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.white.withAlphaComponent(0.95).cgColor
        view.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        view.layer.shadowOpacity = 0.12
        view.layer.shadowRadius = 10
        view.layer.shadowOffset = CGSize(width: 0, height: 4)
        
        guard view.viewWithTag(9201) == nil else { return }
        
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
        blurView.tag = 9201
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.isUserInteractionEnabled = false
        blurView.alpha = 0.72
        blurView.clipsToBounds = true
        blurView.layer.cornerRadius = cornerRadius
        blurView.layer.cornerCurve = .continuous
        view.insertSubview(blurView, at: 0)
        
        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: view.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            blurView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
}
