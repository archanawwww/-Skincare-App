//
//  StartJourneyButtonCollectionViewCell.swift
//  AAINA
//
//  Created by GEU on 27/03/26.
//

import UIKit

class StartJourneyButtonCollectionViewCell: UICollectionViewCell {

    var onTap: (() -> Void)?
    
    @IBOutlet weak var button: UIButton!
    private let gradientLayer = CAGradientLayer()

    override func awakeFromNib() {
        super.awakeFromNib()
        setupUI()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        button.layer.cornerRadius = 16
        gradientLayer.frame = button.bounds
        gradientLayer.cornerRadius = button.layer.cornerRadius
    }

    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        button.setTitle("Begin your AAINA Journey", for: .normal)
        button.backgroundColor = .clear
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 19, weight: .semibold)
        button.layer.cornerCurve = .continuous
        button.clipsToBounds = true
        button.layer.masksToBounds = true

        gradientLayer.colors = [
            UIColor.ainaCoralPink.cgColor,
            UIColor.ainaDustyRose.cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.cornerCurve = .continuous
        gradientLayer.name = "startJourneyGradient"
        button.layer.insertSublayer(gradientLayer, at: 0)

        button.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        button.layer.shadowOpacity = 0
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.layer.shadowRadius = 10
    }

    @IBAction func didTapButton(_ sender: UIButton) {
        onTap?()
    }
}
