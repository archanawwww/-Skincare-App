import UIKit

class OnboardingDOBViewController: UIViewController,
                                   UIPickerViewDelegate,
                                   UIPickerViewDataSource {

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var dobCardView: UIView!
    @IBOutlet weak var yearPicker: UIPickerView!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var privacyContainerView: UIView!
    @IBOutlet weak var privacyIcon: UIImageView!
    @IBOutlet weak var privacyLabel: UILabel!

    var dataModel: AppDataModel!
    var isEditingProfile: Bool = false

    var onboardingData = OnboardingData()
    var selectedYear: Int? = nil

    let maxYear = 2012
    let minYear = 1900

    var years: [Int] {
        return Array(minYear...maxYear).reversed()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light

        view.applyAINABackground()
        setupDOBCard()
        setupPrivacyView()
        setupNextButton()

        // Picker setup FIRST
        yearPicker.delegate = self
        yearPicker.dataSource = self
        yearPicker.setValue(UIColor.ainaTextPrimary, forKey: "textColor")

        selectedYear = onboardingData.birthYear
        if let savedYear = selectedYear,
           let index = years.firstIndex(of: savedYear) {
            yearPicker.selectRow(index, inComponent: 0, animated: false)
            nextButton.isEnabled = true
            nextButton.alpha = 1.0
        } else {
            nextButton.isEnabled = false
            nextButton.alpha = 0.5
        }

        // isEditingProfile block AFTER picker is ready
        if isEditingProfile {
            nextButton.setTitle("Save", for: .normal)
            nextButton.isEnabled = true
            nextButton.alpha = 1.0
            progressView.isHidden = true
            view.subviews.forEach { subview in
                if let label = subview as? UILabel,
                   label.text?.contains("Step") == true {
                    label.isHidden = true
                }
            }
            if let data = UserDefaults.standard.data(forKey: "onboardingData"),
               let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
               let savedYear = od.birthYear,
               let index = years.firstIndex(of: savedYear) {
                yearPicker.selectRow(index, inComponent: 0, animated: false)
                selectedYear = savedYear
            }
        }
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        

        progressView.progressTintColor = .ainaCoralPink
        progressView.trackTintColor = UIColor.ainaRoseLight.withAlphaComponent(0.3)
        progressView.layer.cornerRadius = 2

        if yearPicker.subviews.count > 1 {
            yearPicker.subviews[1].backgroundColor = UIColor.ainaTintedGlassMedium
        }
    }


    private func setupBlobs() {

        let blob1 = UIView()
        blob1.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.25)
        blob1.layer.cornerRadius = 160
        blob1.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blob1)

        let blob2 = UIView()
        blob2.backgroundColor = UIColor.ainaDustyRose.withAlphaComponent(0.15)
        blob2.layer.cornerRadius = 130
        blob2.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(blob2)

        NSLayoutConstraint.activate([
            blob1.widthAnchor.constraint(equalToConstant: 300),
            blob1.heightAnchor.constraint(equalToConstant: 300),
            blob1.topAnchor.constraint(equalTo: view.topAnchor, constant: -80),
            blob1.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 80),

            blob2.widthAnchor.constraint(equalToConstant: 250),
            blob2.heightAnchor.constraint(equalToConstant: 250),
            blob2.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 60),
            blob2.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -60)
        ])
    }

    // GLASS CARD

    private func setupDOBCard() {

        dobCardView.backgroundColor = .clear

        // Apply same glass effect as journal
        dobCardView.applyGlass(cornerRadius: 24)

        // Shadow for floating look
        dobCardView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        dobCardView.layer.shadowOpacity = 0.10
        dobCardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        dobCardView.layer.shadowRadius = 20
        dobCardView.layer.masksToBounds = false

        // Optional: premium border
        dobCardView.layer.borderWidth = 1
        dobCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    }

    // PRIVACY VIEW 

    private func setupPrivacyView() {

        privacyContainerView.backgroundColor = UIColor(red: 0.992, green: 0.910, blue: 0.933, alpha: 0.82)
        privacyContainerView.layer.cornerRadius = 14
        privacyContainerView.layer.masksToBounds = false

        privacyContainerView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        privacyContainerView.layer.shadowOpacity = 0.10
        privacyContainerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        privacyContainerView.layer.shadowRadius = 14

        privacyContainerView.layer.borderWidth = 1
        privacyContainerView.layer.borderColor = UIColor(red: 0.929, green: 0.690, blue: 0.753, alpha: 1.0).cgColor

        privacyIcon.tintColor = UIColor(red: 0.839, green: 0.333, blue: 0.467, alpha: 1.0)
        privacyIcon.image = UIImage(systemName: "lock.shield.fill")

        privacyLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        privacyLabel.textColor = UIColor(red: 0.400, green: 0.180, blue: 0.240, alpha: 1.0)
        privacyLabel.numberOfLines = 0
        privacyLabel.lineBreakMode = .byWordWrapping
    }
    // MARK: - BUTTON

    private func setupNextButton() {
        nextButton.backgroundColor = .ainaCoralPink
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.layer.cornerRadius = 20
        nextButton.isEnabled = false
        nextButton.alpha = 0.5
    }

    // MARK: - Picker

    func numberOfComponents(in pickerView: UIPickerView) -> Int { return 1 }

    func pickerView(_ pickerView: UIPickerView,
                    numberOfRowsInComponent component: Int) -> Int {
        return years.count
    }
    func pickerView(_ pickerView: UIPickerView,
                    attributedTitleForRow row: Int,
                    forComponent component: Int) -> NSAttributedString? {

        let year = "\(years[row])"

        let isSelected = (row == pickerView.selectedRow(inComponent: component))

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: isSelected ? UIColor.ainaTextPrimary : UIColor.gray,
            .font: isSelected ? UIFont.boldSystemFont(ofSize: 22)
                              : UIFont.systemFont(ofSize: 18)
        ]

        return NSAttributedString(string: year, attributes: attributes)
    }

//    func pickerView(_ pickerView: UIPickerView,
//                    didSelectRow row: Int,
//                    inComponent component: Int) {
//
//        selectedYear = years[row]
//        nextButton.isEnabled = true
//        nextButton.alpha = 1.0
//
//        print("Selected year:", selectedYear ?? 0)
//    }

    // MARK: - Navigation

    @IBAction func nextButtonTapped(_ sender: UIButton) {
        guard let year = selectedYear else { return }
        onboardingData.birthYear = year
        AppDataModel.shared.saveOnboardingProgress(onboardingData)

        if isEditingProfile {
            var od = OnboardingData()
            if let existing = UserDefaults.standard.data(forKey: "onboardingData"),
               let decoded = try? JSONDecoder().decode(OnboardingData.self, from: existing) {
                od = decoded
            }
            od.birthYear = year
            if let encoded = try? JSONEncoder().encode(od) {
                UserDefaults.standard.set(encoded, forKey: "onboardingData")
                UserDefaults.standard.synchronize()
            }
            if var updated = AppDataModel.shared.userProfile {
                updated.birthYear = year
                AppDataModel.shared.saveProfile(updated)
            }
            navigationController?.popViewController(animated: true)
            return
        }
        // original onboarding flow
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(
            withIdentifier: "OnboardingSkinTypeViewController"
        ) as? OnboardingSkinTypeViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    func pickerView(_ pickerView: UIPickerView,
                    didSelectRow row: Int,
                    inComponent component: Int) {

        selectedYear = years[row]
        nextButton.isEnabled = true
        nextButton.alpha = 1.0

       // Refresh picker to update colors
        pickerView.reloadAllComponents()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DobToSkinType",
           let vc = segue.destination as? OnboardingSkinTypeViewController {

            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
        }
    }
}
