import UIKit

class OnboardingSensitivityViewController: UIViewController {

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!
    var isEditingProfile: Bool = false
    
    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var sensitivityCardView: UIView!
    @IBOutlet var sensitivityButtons: [UIButton]!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var progressview: UIProgressView!
    
    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light

        view.applyAINABackground()
        setupCard()

        progressview.progressTintColor = .ainaCoralPink
        progressview.trackTintColor = UIColor.ainaRoseLight.withAlphaComponent(0.3)

        if onboardingData == nil {
            onboardingData = OnboardingData()
        }

        setupButtons()
        setupNextButton()
        if isEditingProfile {
            nextButton.setTitle("Save", for: .normal)
            nextButton.isEnabled = true
            nextButton.alpha = 1.0
            progressview.isHidden = true
            view.subviews.forEach { subview in
                if let label = subview as? UILabel,
                   label.text?.contains("Step") == true {
                    label.isHidden = true
                }
            }
            preselectSavedSensitivity()
        } else if onboardingData.sensitivity != nil {
            preselectCurrentSensitivity()
        }
    }

    // MARK: - Actions

    @IBAction func sensitivityTapped(_ sender: UIButton) {
        let level = sensitivityLevel(from: sender.tag)
        onboardingData.sensitivity = level

        updateSelection(selected: sender)
        enableNextButton()
        provideHaptic()
    }

    @IBAction func nextTapped(_ sender: UIButton) {
        guard let sensitivity = onboardingData.sensitivity else { return }
        AppDataModel.shared.saveOnboardingProgress(onboardingData)

        if isEditingProfile {
            var od = OnboardingData()
            if let existing = UserDefaults.standard.data(forKey: "onboardingData"),
               let decoded = try? JSONDecoder().decode(OnboardingData.self, from: existing) {
                od = decoded
            }
            od.sensitivity = sensitivity
            if let encoded = try? JSONEncoder().encode(od) {
                UserDefaults.standard.set(encoded, forKey: "onboardingData")
                UserDefaults.standard.synchronize()
            }
            if var updated = AppDataModel.shared.userProfile {
                updated.sensitivity = sensitivity
                AppDataModel.shared.saveProfile(updated)
            }
            navigationController?.popViewController(animated: true)
            return
        }

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(
            withIdentifier: "OnboardingGoalsViewController"
        ) as? OnboardingGoalsViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    private func preselectSavedSensitivity() {
        if let data = UserDefaults.standard.data(forKey: "onboardingData"),
           let od = try? JSONDecoder().decode(OnboardingData.self, from: data),
           let sensitivity = od.sensitivity {
            onboardingData.sensitivity = sensitivity
            let tag = tagFrom(sensitivity)
            if let btn = sensitivityButtons.first(where: { $0.tag == tag }) {
                updateSelection(selected: btn)
            }
            enableNextButton()
        }
    }

    private func preselectCurrentSensitivity() {
        guard let sensitivity = onboardingData.sensitivity else { return }
        let tag = tagFrom(sensitivity)
        if let btn = sensitivityButtons.first(where: { $0.tag == tag }) {
            updateSelection(selected: btn)
        }
        enableNextButton()
    }

    private func tagFrom(_ level: SensitivityLevel) -> Int {
        switch level {
        case .hardlyEver: return 0
        case .sometimes:  return 1
        case .often:      return 2
        case .veryEasily: return 3
        }
    }

    // MARK: - UI Setup

    private func setupCard() {
        sensitivityCardView.backgroundColor = .clear

        sensitivityCardView.applyGlass(cornerRadius: 24)

        sensitivityCardView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        sensitivityCardView.layer.shadowOpacity = 0.10
        sensitivityCardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        sensitivityCardView.layer.shadowRadius = 20
        sensitivityCardView.layer.masksToBounds = false

        sensitivityCardView.layer.borderWidth = 1
        sensitivityCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    }

    private func setupButtons() {
        sensitivityButtons.forEach {

            var config = UIButton.Configuration.plain()
            config.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)

            $0.configuration = config
            $0.layer.cornerRadius = 22
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.25)

            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.25).cgColor

            $0.setTitleColor(.ainaTextPrimary, for: .normal)
        }
    }

    private func setupNextButton() {
        nextButton.layer.cornerRadius = 20
        nextButton.backgroundColor = .ainaCoralPink
        nextButton.setTitleColor(.white, for: .normal)

        nextButton.isEnabled = false
        nextButton.alpha = 0.5
    }

    private func enableNextButton() {
        nextButton.isEnabled = true
        nextButton.alpha = 1.0
    }

    // MARK: - Selection UI

    private func updateSelection(selected: UIButton) {
        for button in sensitivityButtons {

            if button == selected {

                button.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
                button.setTitleColor(.ainaCoralPink, for: .normal)

                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.ainaCoralPink.cgColor

                UIView.animate(withDuration: 0.15,
                               animations: {
                    button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }) { _ in
                    UIView.animate(withDuration: 0.15) {
                        button.transform = .identity
                    }
                }

            } else {


                button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
                button.setTitleColor(.ainaTextPrimary, for: .normal)

                button.layer.borderWidth = 1
                button.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.25).cgColor
            }
        }
    }

    // MARK: - Haptics

    private func provideHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Mapping

    private func sensitivityLevel(from tag: Int) -> SensitivityLevel {
        switch tag {
        case 0: return .hardlyEver
        case 1: return .sometimes
        case 2: return .often
        case 3: return .veryEasily
        default: return .sometimes
        }
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SensitivityToGoal",
           let vc = segue.destination as? OnboardingGoalsViewController {

            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
        }
    }
}
