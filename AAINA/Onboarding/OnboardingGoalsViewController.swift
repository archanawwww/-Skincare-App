import UIKit

class OnboardingGoalsViewController: UIViewController {

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!
    var isEditingProfile: Bool = false

    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet var goalButtons: [UIButton]!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet var goalsCard: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        

        view.applyAINABackground()
        if onboardingData == nil { onboardingData = OnboardingData() }

        setupCard()

        progressView.progressTintColor = .ainaCoralPink
        progressView.trackTintColor = UIColor.ainaRoseLight.withAlphaComponent(0.3)

        setupButtons()
        setupNextButton()
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
            preselectSavedGoals()
        } else {
            updateAllButtons()
            validateNextButton()
        }
    }

    // MARK: - Actions

    @IBAction func goalTapped(_ sender: UIButton) {

        let goal = goalFrom(tag: sender.tag)

        if goal == .routineOnly {
            onboardingData.goals.removeAll()
            onboardingData.goals.append(.routineOnly)
        } else {
            onboardingData.goals.removeAll { $0 == .routineOnly }

            if onboardingData.goals.contains(goal) {
                onboardingData.goals.removeAll { $0 == goal }
            } else {
                onboardingData.goals.append(goal)
            }
        }

        updateAllButtons()
        validateNextButton()
    }

    @IBAction func nextTapped(_ sender: UIButton) {
        guard !onboardingData.goals.isEmpty else { return }
        AppDataModel.shared.saveOnboardingProgress(onboardingData)

        if isEditingProfile {
            var od = OnboardingData()
            if let existing = UserDefaults.standard.data(forKey: "onboardingData"),
               let decoded = try? JSONDecoder().decode(OnboardingData.self, from: existing) {
                od = decoded
            }
            od.goals = onboardingData.goals
            if let encoded = try? JSONEncoder().encode(od) {
                UserDefaults.standard.set(encoded, forKey: "onboardingData")
                UserDefaults.standard.synchronize()
            }
            if var updated = AppDataModel.shared.userProfile {
                updated.goals = onboardingData.goals
                AppDataModel.shared.saveProfile(updated)
            }
            navigationController?.popViewController(animated: true)
            return
        }
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(
            withIdentifier: "OnboardingExposureViewController"
        ) as? OnboardingExposureViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "GoalToWork",
           let vc = segue.destination as? OnboardingExposureViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
        }
    }

    // MARK: - UI SETUP

    private func setupCard() {
        goalsCard.backgroundColor = .clear

        // SAME AS DOB & SENSITIVITY
        goalsCard.applyGlass(cornerRadius: 24)

        goalsCard.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        goalsCard.layer.shadowOpacity = 0.10
        goalsCard.layer.shadowOffset = CGSize(width: 0, height: 8)
        goalsCard.layer.shadowRadius = 20
        goalsCard.layer.masksToBounds = false

        goalsCard.layer.borderWidth = 1
        goalsCard.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    }

    private func setupButtons() {
        goalButtons.forEach {

            $0.layer.cornerRadius = 22

            //MATCH OTHER SCREENS
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.25)

            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.25).cgColor

            $0.setTitleColor(.ainaTextPrimary, for: .normal)
        }
    }

    private func updateButtonState(_ button: UIButton, isSelected: Bool) {

        if isSelected {

            //MATCH SKIN TYPE / SENSITIVITY
            button.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
            button.layer.borderColor = UIColor.ainaCoralPink.cgColor
            button.setTitleColor(.ainaCoralPink, for: .normal)

        } else {

            //MATCH UNSELECTED STYLE
            button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
            button.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.25).cgColor
            button.setTitleColor(.ainaTextPrimary, for: .normal)
        }
    }
    private func preselectSavedGoals() {
        if let data = UserDefaults.standard.data(forKey: "onboardingData"),
           let od = try? JSONDecoder().decode(OnboardingData.self, from: data) {
            onboardingData.goals = od.goals
        }
        updateAllButtons()
        validateNextButton()
    }

    private func setupNextButton() {
        nextButton.layer.cornerRadius = 20
        nextButton.backgroundColor = .ainaCoralPink
        nextButton.setTitleColor(.white, for: .normal)
        nextButton.isEnabled = false
        nextButton.alpha = 0.5
    }

    private func validateNextButton() {
        let hasSelection = !onboardingData.goals.isEmpty
        nextButton.isEnabled = hasSelection
        nextButton.alpha = hasSelection ? 1.0 : 0.5
    }

    private func updateAllButtons() {
        for button in goalButtons {
            let goal = goalFrom(tag: button.tag)
            let isSelected = onboardingData.goals.contains(goal)
            updateButtonState(button, isSelected: isSelected)
        }
    }

    // MARK: - Mapping

    private func goalFrom(tag: Int) -> SkinGoal {
        switch tag {
        case 0: return .maintainSkin
        case 1: return .hydration
        case 2: return .oilControl
        case 3: return .glow
        case 4: return .toneImprove
        case 5: return .antiAging
        case 6: return .poreMinimize
        case 7: return .routineOnly
        default: return .routineOnly
        }
    }
}
