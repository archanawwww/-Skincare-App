import UIKit

class OnboardingExposureViewController: UIViewController {

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!

    @IBOutlet weak var exposureCardView: UIView!
    @IBOutlet var exposureButtons: [UIButton]!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var progressView: UIProgressView!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light

        view.applyAINABackground()

        setupCard()

        progressView.progressTintColor = .ainaCoralPink
        progressView.trackTintColor = UIColor.ainaRoseLight.withAlphaComponent(0.3)

        setupButtons()
        setupNextButton()
        if let exposure = onboardingData.uvExposure {
            let tag = tagFrom(exposure)
            if let button = exposureButtons.first(where: { $0.tag == tag }) {
                updateSelection(selected: button)
                enableNextButton()
            }
        }
    }

    // MARK: - UI Setup

    private func setupCard() {
        exposureCardView.backgroundColor = .clear

      
        exposureCardView.applyGlass(cornerRadius: 24)

        exposureCardView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        exposureCardView.layer.shadowOpacity = 0.10
        exposureCardView.layer.shadowOffset = CGSize(width: 0, height: 8)
        exposureCardView.layer.shadowRadius = 20
        exposureCardView.layer.masksToBounds = false

        exposureCardView.layer.borderWidth = 1
        exposureCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
    }

    private func setupButtons() {
        exposureButtons.forEach {

            $0.layer.cornerRadius = 22

            // MATCH OTHER SCREENS
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

    // MARK: - Actions

    @IBAction func exposureTapped(_ sender: UIButton) {

        let level = exposureLevel(from: sender.tag)
        onboardingData.uvExposure = level

        updateSelection(selected: sender)
        provideHaptic()
        enableNextButton()
    }

    @IBAction func finishTapped(_ sender: UIButton) {

        guard onboardingData.uvExposure != nil else { return }

        AppDataModel.shared.saveOnboardingProgress(onboardingData)

        let cameraVC = OnboardingCameraViewController()
        cameraVC.onboardingData = onboardingData
        cameraVC.dataModel = dataModel

        navigationController?.pushViewController(cameraVC, animated: true)
    }

    // MARK: - Selection UI

    private func updateSelection(selected: UIButton) {
        for button in exposureButtons {

            if button == selected {

                // MATCH SELECTED STYLE
                button.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.15)
                button.layer.borderColor = UIColor.ainaCoralPink.cgColor
                button.layer.borderWidth = 1

                button.setTitleColor(.ainaCoralPink, for: .normal)

                UIView.animate(withDuration: 0.15,
                               animations: {
                    button.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
                }) { _ in
                    UIView.animate(withDuration: 0.15) {
                        button.transform = .identity
                    }
                }

            } else {

                // MATCH UNSELECTED STYLE
                button.backgroundColor = UIColor.white.withAlphaComponent(0.25)
                button.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.25).cgColor
                button.layer.borderWidth = 1

                button.setTitleColor(.ainaTextPrimary, for: .normal)
            }
        }
    }

    // MARK: - Haptics

    private func provideHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    // MARK: - Data

    private func saveToUserDefaults(_ onboardingData: OnboardingData) {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(onboardingData) {
            UserDefaults.standard.set(data, forKey: "onboardingData")
        }
    }

    private func exposureLevel(from tag: Int) -> UVExposureLevel {
        switch tag {
        case 0: return .rarely
        case 1: return .moderate
        case 2: return .high
        case 3: return .veryHigh
        default: return .moderate
        }
    }

    private func tagFrom(_ exposure: UVExposureLevel) -> Int {
        switch exposure {
        case .rarely: return 0
        case .moderate: return 1
        case .high: return 2
        case .veryHigh: return 3
        }
    }
}
