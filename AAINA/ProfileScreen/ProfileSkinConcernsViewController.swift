//
//  ConcernsViewController.swift
//  Profile_Screen
//
//  Created by GEU on 12/02/26.
//

import UIKit
class ProfileSkinConcernsViewController: UIViewController,
    UICollectionViewDelegate,
    UICollectionViewDataSource,
    UICollectionViewDelegateFlowLayout {

    // MARK: - Data
    private let allConcerns = SkinConcern.allCases
    private var selectedConcerns: Set<SkinConcern> = []

    // MARK: - UI
    private var collectionView: UICollectionView!
    private let saveButton = UIButton()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        navigationItem.title = "Skin Concerns"
        loadSavedConcerns()
        setupUI()
    }

    // MARK: - Load saved concerns
    private func loadSavedConcerns() {
        if let profile = AppDataModel.shared.userProfile, !profile.concerns.isEmpty {
            selectedConcerns = Set(profile.concerns)
        } else if let saved = UserDefaults.standard.array(forKey: "saved_concerns") as? [String] {
            selectedConcerns = Set(saved.compactMap { SkinConcern(rawValue: $0) })
        }
    }

    // MARK: - UI Setup
    private func setupUI() {

        // Title
        titleLabel.text = "What are your skin concerns?"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Subtitle
        subtitleLabel.text = "Select all that apply"
        subtitleLabel.font = UIFont.systemFont(ofSize: 14)
        subtitleLabel.textColor = .systemGray
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(subtitleLabel)

        // Save button
        saveButton.setTitle("Save", for: .normal)
        saveButton.backgroundColor = .ainaCoralPink
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 20
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)
        view.addSubview(saveButton)

        // Collection view
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 12
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.register(
            ConcernChipCell.self,
            forCellWithReuseIdentifier: "ConcernChip"
        )
        view.addSubview(collectionView)

        // Constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(
                equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.centerXAnchor.constraint(
                equalTo: view.centerXAnchor),

            saveButton.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            saveButton.leadingAnchor.constraint(
                equalTo: view.leadingAnchor, constant: 24),
            saveButton.trailingAnchor.constraint(
                equalTo: view.trailingAnchor, constant: -24),
            saveButton.heightAnchor.constraint(equalToConstant: 56),

            collectionView.topAnchor.constraint(
                equalTo: subtitleLabel.bottomAnchor, constant: 16),
            collectionView.leadingAnchor.constraint(
                equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(
                equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(
                equalTo: saveButton.topAnchor, constant: -16)
        ])
    }

    // MARK: - CollectionView DataSource
    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return allConcerns.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: "ConcernChip",
            for: indexPath
        ) as! ConcernChipCell
        let concern = allConcerns[indexPath.item]
        cell.configure(
            with: concern,
            isSelected: selectedConcerns.contains(concern)
        )
        return cell
    }

    // MARK: - CollectionView Layout
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = (collectionView.bounds.width - 44) / 2
        return CGSize(width: width, height: 56)
    }

    // MARK: - CollectionView Delegate
    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        let concern = allConcerns[indexPath.item]
        if selectedConcerns.contains(concern) {
            selectedConcerns.remove(concern)
        } else {
            selectedConcerns.insert(concern)
        }
        collectionView.reloadItems(at: [indexPath])
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Save
    @objc private func saveTapped() {
        let concernsArray = Array(selectedConcerns)
        
        // Try AppDataModel first
        if AppDataModel.shared.userProfile != nil {
            AppDataModel.shared.updateConcerns(concernsArray)
        }
        
        // Save concerns count to UserDefaults directly
        UserDefaults.standard.set(concernsArray.map { $0.rawValue }, forKey: "saved_concerns")
        UserDefaults.standard.synchronize()
        
        navigationController?.popViewController(animated: true)
    }
}

// MARK: - Chip Cell
class ConcernChipCell: UICollectionViewCell {

    private let label = UILabel()
    private let iconView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        layer.cornerRadius = 16
        layer.borderWidth = 1.5

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        contentView.addSubview(iconView)

        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        label.numberOfLines = 1
        contentView.addSubview(label)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),

            label.leadingAnchor.constraint(
                equalTo: iconView.trailingAnchor, constant: 8),
            label.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor, constant: -8),
            label.centerYAnchor.constraint(
                equalTo: contentView.centerYAnchor)
        ])
    }

    func configure(with concern: SkinConcern, isSelected: Bool) {
        label.text = concern.displayName
        iconView.image = UIImage(systemName: iconName(for: concern))

        if isSelected {
            backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
            layer.borderColor = UIColor.ainaCoralPink.cgColor
            label.textColor = .ainaCoralPink
            iconView.tintColor = .ainaCoralPink
        } else {
            backgroundColor = UIColor.white.withAlphaComponent(0.3)
            layer.borderColor = UIColor.ainaTextTertiary
                .withAlphaComponent(0.3).cgColor
            label.textColor = .ainaTextPrimary
            iconView.tintColor = .systemGray
        }
    }

    private func iconName(for concern: SkinConcern) -> String {
        switch concern {
        case .acne:          return "staroflife.fill"
        case .darkSpots:     return "circle.lefthalf.filled"
        case .darkCircles:   return "eye.fill"
        case .foreheadBumps: return "waveform.path"
        case .blackheads:    return "circle.fill"
        case .whiteheads:    return "circle"
        case .redness:       return "flame.fill"
        case .fineLines:     return "line.3.horizontal.decrease"
        case .pigmentation:  return "paintpalette.fill"
        }
    }
}
