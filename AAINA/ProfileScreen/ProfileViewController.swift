import UIKit

class ProfileViewController: UIViewController,
UICollectionViewDelegate,
UICollectionViewDataSource {

@IBOutlet weak var ProfileCollectionView: UICollectionView!

private var userProfile: UserProfile? { AppDataModel.shared.userProfile }

override func viewDidLoad() {
super.viewDidLoad()

title = "Profile"

// Background Theme
view.applyAINABackground()
view.backgroundColor = .clear

// Settings Button
navigationItem.rightBarButtonItem = UIBarButtonItem(
    image: UIImage(systemName: "gearshape.fill"),
    style: .plain,
    target: self,
    action: #selector(openSettings)
)
navigationItem.rightBarButtonItem?.tintColor = .primarypink

ProfileCollectionView.delegate = self
ProfileCollectionView.dataSource = self
ProfileCollectionView.backgroundColor = .clear

registerCells()
ProfileCollectionView.collectionViewLayout = createLayout()


}

// MARK: - Navigation

@objc private func openSettings() {
let vc = SettingsViewController()
vc.hidesBottomBarWhenPushed = true
navigationController?.pushViewController(vc, animated: true)
}

// MARK: - Register Cells

private func registerCells() {
ProfileCollectionView.register(
UINib(nibName: "ProfileCollectionViewCell", bundle: nil),
forCellWithReuseIdentifier: "ProfileCell"
)

ProfileCollectionView.register(
    UINib(nibName: "SkinProfileCollectionViewCell", bundle: nil),
    forCellWithReuseIdentifier: "SkinProfileCell"
)

ProfileCollectionView.register(
    UINib(nibName: "SectionHeaderReusableView", bundle: nil),
    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
    withReuseIdentifier: SectionHeaderReusableView.identifier
)


}

// MARK: - Sections

func numberOfSections(in collectionView: UICollectionView) -> Int {
return 2
}

func collectionView(_ collectionView: UICollectionView,
numberOfItemsInSection section: Int) -> Int {
return 1
}

// MARK: - Cells

func collectionView(_ collectionView: UICollectionView,
cellForItemAt indexPath: IndexPath)
-> UICollectionViewCell {

switch indexPath.section {

case 0:
    let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "ProfileCell",
        for: indexPath
    ) as! ProfileCollectionViewCell

    // Use name from login (Google/Apple/Guest), fall back to saved profile, then "User"
    let loginName = UserDefaults.standard.string(forKey: "userName")
    cell.nameLabel.text = loginName ?? userProfile?.name ?? "User"
    cell.ageLabel.isUserInteractionEnabled = true
    cell.ageLabel.tag = 99
    let ageTap = UITapGestureRecognizer(target: self, action: #selector(ageLabelTapped))
    cell.ageLabel.addGestureRecognizer(ageTap)
    // Compute age from saved birth year
    var ageText = "Age unknown"
    if let data = UserDefaults.standard.data(forKey: "onboardingData"),
       let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
       let birthYear = od.birthYear {
        let age = Calendar.current.component(.year, from: Date()) - birthYear
        ageText = " \(age) years  "
    } else if let profile = AppDataModel.shared.userProfile,
              let age = profile.age {
        ageText = " \(age) years  "
    }
    cell.ageLabel.text = ageText
//    cell.daysLabel.text = "23"
//    cell.JournalLabel.text = "17"

    return cell

case 1:
    let cell = collectionView.dequeueReusableCell(
        withReuseIdentifier: "SkinProfileCell",
        for: indexPath
    ) as! SkinProfileCollectionViewCell

    cell.onItemSelected = { [weak self] index in
        guard let self = self else { return }

        switch index {
        case 0:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(
                withIdentifier: "OnboardingSkinTypeViewController"
            ) as? OnboardingSkinTypeViewController {
                vc.isEditingProfile = true
                var data = OnboardingData()
                if let (t, u, c) = self.skinTypeFromSaved() {
                    data.tZone = t
                    data.uZone = u
                    data.cZone = c
                }
                vc.onboardingData = data
                vc.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        case 1: self.navigateTo(ProfileSkinConcernsViewController())
        case 2:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(
                withIdentifier: "OnboardingSensitivityViewController"
            ) as? OnboardingSensitivityViewController {
                vc.isEditingProfile = true
                vc.onboardingData = OnboardingData()
                vc.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        case 3:
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let vc = storyboard.instantiateViewController(
                withIdentifier: "OnboardingGoalsViewController"
            ) as? OnboardingGoalsViewController {
                vc.isEditingProfile = true
                vc.onboardingData = OnboardingData()
                vc.hidesBottomBarWhenPushed = true
                self.navigationController?.pushViewController(vc, animated: true)
            }
        case 4: self.navigateTo(SavedRoutinesViewController())
        default: break
        }
    }

    // Compute skin type fresh every time cell is displayed
    var skinText = "Not set"
    if let data = UserDefaults.standard.data(forKey: "onboardingData"),
       let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
       let t = od.tZone, let u = od.uZone, let c = od.cZone {
        let zones = [t, u, c]
        let counts = Dictionary(grouping: zones) { $0 }.mapValues { $0.count }
        skinText = (counts.max(by: { $0.value < $1.value })?.key.rawValue ?? "normal").capitalized
    } else if let profile = AppDataModel.shared.userProfile {
        skinText = profile.dominantSkinType.rawValue.capitalized
    }
    cell.updateSkinType(skinText)
    // Update goals count fresh
    var goalsText = "None"
    if let data = UserDefaults.standard.data(forKey: "onboardingData"),
       let od = try? JSONDecoder().decode(OnboardingData.self, from: data) {
        goalsText = od.goals.isEmpty ? "None" : "\(od.goals.count) Goals"
    } else if let profile = AppDataModel.shared.userProfile {
        goalsText = profile.goals.isEmpty ? "None" : "\(profile.goals.count) Goals"
    }
    cell.updateGoals(goalsText)
    var sensitivityText = "Normal"
    if let data = UserDefaults.standard.data(forKey: "onboardingData"),
       let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
       let s = od.sensitivity {
        switch s {
        case .hardlyEver: sensitivityText = "Hardly Ever"
        case .sometimes:  sensitivityText = "Sometimes"
        case .often:      sensitivityText = "Often"
        case .veryEasily: sensitivityText = "Very Easily"
        }
    } else if let profile = AppDataModel.shared.userProfile {
        switch profile.sensitivity {
        case .hardlyEver: sensitivityText = "Hardly Ever"
        case .sometimes:  sensitivityText = "Sometimes"
        case .often:      sensitivityText = "Often"
        case .veryEasily: sensitivityText = "Very Easily"
        }
    }
    cell.updateSensitivity(sensitivityText)
    // existing skin type code above...
    cell.updateSkinType(skinText)

    // ADD THIS HERE:
    var concernsText = "None"
    if let profile = AppDataModel.shared.userProfile, !profile.concerns.isEmpty {
        concernsText = "\(profile.concerns.count) Concerns"
    } else if let saved = UserDefaults.standard.array(forKey: "saved_concerns") as? [String], !saved.isEmpty {
        concernsText = "\(saved.count) Concerns"
    }
    cell.updateConcerns(concernsText)

    // existing goals code below...


    return cell
default:
    return UICollectionViewCell()
}


}

// MARK: - Header

func collectionView(_ collectionView: UICollectionView,
viewForSupplementaryElementOfKind kind: String,
at indexPath: IndexPath)
-> UICollectionReusableView {


let header = collectionView.dequeueReusableSupplementaryView(
    ofKind: kind,
    withReuseIdentifier: SectionHeaderReusableView.identifier,
    for: indexPath
) as! SectionHeaderReusableView

header.titleLabel.textColor = .systemGray
header.titleLabel.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
header.titleLabel.text = indexPath.section == 1 ? "SKIN PROFILE" : ""

return header

}
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showSkinTypeEdit",
           let vc = segue.destination as? OnboardingSkinTypeViewController {
            vc.isEditingProfile = true
            vc.onboardingData = OnboardingData()
        }
    }

// MARK: - Layout
    private func skinTypeFromSaved() -> (SkinType, SkinType, SkinType)? {
        // Try AppDataModel first
        if let profile = AppDataModel.shared.userProfile {
            return (profile.tZone, profile.uZone, profile.cZone)
        }
        // Fallback: read from onboardingData key
        if let data = UserDefaults.standard.data(forKey: "onboardingData"),
           let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
           let t = od.tZone, let u = od.uZone, let c = od.cZone {
            return (t, u, c)
        }
        return nil
    }
    @objc private func ageLabelTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(
            withIdentifier: "OnboardingDOBViewController"
        ) as? OnboardingDOBViewController {
            vc.isEditingProfile = true
            vc.onboardingData = OnboardingData()
            vc.hidesBottomBarWhenPushed = true
            navigationController?.pushViewController(vc, animated: true)
        }
    }

private func createLayout() -> UICollectionViewLayout {

return UICollectionViewCompositionalLayout { sectionIndex, _ in

    let sectionHeights: [Int: CGFloat] = [
        0: 140,   // Profile Card
        1: 320    // Skin Profile
    ]

    let height = sectionHeights[sectionIndex] ?? 250

    let itemSize = NSCollectionLayoutSize(
        widthDimension: .fractionalWidth(1),
        heightDimension: .absolute(height)
    )

    let item = NSCollectionLayoutItem(layoutSize: itemSize)

    let group = NSCollectionLayoutGroup.vertical(
        layoutSize: itemSize,
        subitems: [item]
    )

    let section = NSCollectionLayoutSection(group: group)

    section.contentInsets = NSDirectionalEdgeInsets(
        top: sectionIndex == 0 ? 12 : 16,
        leading: 16,
        bottom: 8,
        trailing: 16
    )

    if sectionIndex != 0 {
        let headerSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .absolute(40)
        )

        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: headerSize,
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top
        )

        section.boundarySupplementaryItems = [header]
    }

    return section
}


}

// MARK: - Navigation Helper

private func navigateTo(_ vc: UIViewController) {
vc.hidesBottomBarWhenPushed = true
navigationController?.pushViewController(vc, animated: true)
}
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        ProfileCollectionView.reloadData()
    }

}
