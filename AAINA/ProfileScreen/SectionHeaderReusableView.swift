//
//  SectionHeaderReusableView.swift
//  Profile_Screen
//
//  Created by GEU on 12/02/26.
//

import UIKit

class SectionHeaderReusableView: UICollectionReusableView {
    
    static let identifier = "SectionHeaderReusableView"
    
    let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),

            titleLabel.bottomAnchor.constraint(
                equalTo: bottomAnchor,
                constant: 2
            )
        ])    }
}
