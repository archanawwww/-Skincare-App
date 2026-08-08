import UIKit

class OnboardingSkinTypeViewController: UIViewController {

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!
    var isEditingProfile: Bool = false

    @IBOutlet var tZoneButtons: [UIButton]!
    @IBOutlet var uZoneButtons: [UIButton]!
    @IBOutlet var cZoneButtons: [UIButton]!

    @IBOutlet weak var stepLabel: UILabel!
    @IBOutlet weak var tZoneCardView: UIView!
    @IBOutlet weak var uZoneCardView: UIView!
    @IBOutlet weak var cZoneCardView: UIView!

    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var infoView: UIView!
    
    @IBOutlet weak var progressView: UIProgressView!
    
    

    @IBOutlet weak var backgroundView: UIView!

    @IBOutlet weak var infoTitleLabel: UILabel!
    @IBOutlet weak var infoSubtitleLabel: UILabel!
    @IBOutlet weak var infoDescriptionLabel: UILabel!
    @IBOutlet weak var infoImageView: UIImageView!
    @IBOutlet weak var notSureView: UIView!
    @IBOutlet weak var notSureIcon: UIImageView!
    @IBOutlet weak var notSureLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        view.applyAINABackground()
        if onboardingData == nil {
            onboardingData = OnboardingData()
        }
        progressView.progressTintColor = .ainaCoralPink
        progressView.trackTintColor = UIColor.ainaRoseLight.withAlphaComponent(0.3)

        setupCards()
       
        styleButtons(tZoneButtons)
        styleButtons(uZoneButtons)
        styleButtons(cZoneButtons)
        setupNextButton()
        if isEditingProfile {
            nextButton.setTitle("Save", for: .normal)
            nextButton.isEnabled = true
            nextButton.alpha = 1.0
        }
        setupPopupUI()
        setupNotSureUI()

        // Initial state
        infoView.isHidden = true
        infoView.alpha = 0

        backgroundView.isHidden = true
        backgroundView.alpha = 0
        backgroundView.backgroundColor = UIColor.black.withAlphaComponent(0.2)
        backgroundView.isUserInteractionEnabled = false

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        backgroundView.addGestureRecognizer(tap)
        if isEditingProfile {
            preselectSavedValues()
            progressView.isHidden = true
            stepLabel.isHidden = true
            
            navigationItem.title = "Edit Skin Type"
            print("tZone buttons tags:", tZoneButtons.map { $0.tag })
            print("profile tZone:", AppDataModel.shared.userProfile?.tZone ?? "nil")
        } else {
            preselectSavedValues()
        }
        
    }

    // MARK: - Button Actions

    @IBAction func eyeTapped(_ sender: UIButton) {
        print("eye tapped", sender.tag)
        showInfo(for: sender.tag)
    }

    @IBAction func tZoneTapped(_ sender: UIButton) {
        onboardingData.tZone = skinType(from: sender.tag)
        updateSelection(selected: sender, in: tZoneButtons)
        provideHaptic()
        validateSelections()
    }

    @IBAction func uZoneTapped(_ sender: UIButton) {
        onboardingData.uZone = skinType(from: sender.tag)
        updateSelection(selected: sender, in: uZoneButtons)
        provideHaptic()
        validateSelections()
    }

    @IBAction func cZoneTapped(_ sender: UIButton) {
        onboardingData.cZone = skinType(from: sender.tag)
        updateSelection(selected: sender, in: cZoneButtons)
        provideHaptic()
        validateSelections()
    }

    @IBAction func nextTapped(_ sender: UIButton) {
        guard let tZone = onboardingData.tZone,
              let uZone = onboardingData.uZone,
              let cZone = onboardingData.cZone else { return }
        AppDataModel.shared.saveOnboardingProgress(onboardingData)
        if isEditingProfile {

            // Force write new values directly
            var od = OnboardingData()
            od.tZone = tZone
            od.uZone = uZone
            od.cZone = cZone
            
            // Preserve other fields if they exist
            if let existing = UserDefaults.standard.data(forKey: "onboardingData"),
               let decoded = try? JSONDecoder().decode(OnboardingData.self, from: existing) {
                od.birthYear = decoded.birthYear
                od.sensitivity = decoded.sensitivity
                od.goals = decoded.goals
                od.uvExposure = decoded.uvExposure
            }
            
            if let encoded = try? JSONEncoder().encode(od) {
                UserDefaults.standard.set(encoded, forKey: "onboardingData")
                UserDefaults.standard.synchronize()
                print("Saved tZone:", od.tZone ?? "nil")
                print("Saved uZone:", od.uZone ?? "nil")
                print("Saved cZone:", od.cZone ?? "nil")
            }
            
            if var updated = AppDataModel.shared.userProfile {
                updated.tZone = tZone
                updated.uZone = uZone
                updated.cZone = cZone
                AppDataModel.shared.saveProfile(updated)
            }
            
            navigationController?.popViewController(animated: true)
            return
        }
//        performSegue(withIdentifier: "SkinTypeToSensitivity", sender: self)

        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(
            withIdentifier: "OnboardingSensitivityViewController"
        ) as? OnboardingSensitivityViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
            navigationController?.pushViewController(vc, animated: true)
        }
    }

    // MARK: - Gesture

    @objc func backgroundTapped() {
        hideInfo()
    }

    // MARK: - Popup Logic

    func showInfo(for tag: Int) {

        view.bringSubviewToFront(backgroundView)
        view.bringSubviewToFront(infoView)

        backgroundView.isUserInteractionEnabled = true

        switch tag {
        case 0:
            infoTitleLabel.text = "T-Zone"
            infoSubtitleLabel.text = "Forehead, Nose & Chin"
            infoDescriptionLabel.text = "This area usually produces more oil compared to other parts of your face."
            infoImageView.image = UIImage(named: "z")

        case 1:
            infoTitleLabel.text = "C-Zone"
            infoSubtitleLabel.text = "Around Mouth"
            infoDescriptionLabel.text = "This area is prone to dryness and sensitivity."
            infoImageView.image = UIImage(named: "czone")

        case 2:
            infoTitleLabel.text = "U-Zone"
            infoSubtitleLabel.text = "Cheeks & Jawline"
            infoDescriptionLabel.text = "This area is typically normal to dry and needs hydration."
            infoImageView.image = UIImage(named: "uzone")
        default:
            break
        }

        infoView.isHidden = false
        backgroundView.isHidden = false

        infoView.alpha = 0
        backgroundView.alpha = 0

        // Smooth bottom animation (instead of scaling)
        infoView.transform = CGAffineTransform(translationX: 0, y: 30)

        UIView.animate(withDuration: 0.3,
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0.5,
                       options: .curveEaseOut,
                       animations: {
            self.backgroundView.alpha = 1
            self.infoView.alpha = 1
            self.infoView.transform = .identity
        })
    }
    private func preselectSavedValues() {
        func tag(for type: SkinType) -> Int {
            switch type {
            case .oily:        return 0
            case .normal:      return 1
            case .dry:         return 2
            case .combination: return 1
            }
        }

        if let tZone = onboardingData.tZone,
           let btn = tZoneButtons.first(where: { $0.tag == tag(for: tZone) }) {
            updateSelection(selected: btn, in: tZoneButtons)
        }
        if let uZone = onboardingData.uZone,
           let btn = uZoneButtons.first(where: { $0.tag == tag(for: uZone) }) {
            updateSelection(selected: btn, in: uZoneButtons)
        }
        if let cZone = onboardingData.cZone,
           let btn = cZoneButtons.first(where: { $0.tag == tag(for: cZone) }) {
            updateSelection(selected: btn, in: cZoneButtons)
        }

        validateSelections()
    }
    func hideInfo() {
        backgroundView.isUserInteractionEnabled = false

        UIView.animate(withDuration: 0.25, animations: {
            self.infoView.alpha = 0
            self.backgroundView.alpha = 0
            self.infoView.transform = CGAffineTransform(translationX: 0, y: 30)
        }) { _ in
            self.infoView.isHidden = true
            self.backgroundView.isHidden = true
        }
    }

    // MARK: - UI Setup
    private func setupCards() {
        [tZoneCardView, uZoneCardView, cZoneCardView].forEach {

            $0?.backgroundColor = UIColor.white.withAlphaComponent(0.35)
            $0?.layer.borderWidth = 1
            $0?.layer.cornerRadius = 20
            $0?.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            $0?.layer.cornerCurve = .continuous

            $0?.layer.shadowColor = UIColor.black.cgColor
            $0?.layer.shadowOpacity = 0.06
            $0?.layer.shadowOffset = CGSize(width: 0, height: 6)
            $0?.layer.shadowRadius = 12

            $0?.layer.masksToBounds = false
        }
    }
    private func styleButtons(_ buttons: [UIButton]) {
        buttons.forEach {
            $0.configuration = nil
            $0.layer.cornerRadius = 18
            $0.layer.borderWidth = 1
            $0.setTitle($0.currentTitle, for: .normal)

            // Default state
            $0.backgroundColor = UIColor.white.withAlphaComponent(0.15)
            $0.setTitleColor(.ainaTextPrimary, for: .normal)
            $0.setTitleColor(.ainaTextPrimary, for: .selected)
            $0.setTitleColor(.ainaTextPrimary, for: .highlighted)
            $0.tintColor = .clear
//            $0.adjustsImageWhenHighlighted = false
            $0.layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor

           
        }
    }
    private func setupNotSureUI() {

        notSureView.backgroundColor = UIColor(red: 0.992, green: 0.910, blue: 0.933, alpha: 1.0)
        notSureView.layer.cornerRadius = 14
        notSureView.layer.masksToBounds = false
        notSureView.layer.borderWidth = 1
        notSureView.layer.borderColor = UIColor(red: 0.961, green: 0.753, blue: 0.816, alpha: 1.0).cgColor

        notSureView.layer.shadowColor = UIColor.ainaCardShadowColor.cgColor
        notSureView.layer.shadowOpacity = 0.10
        notSureView.layer.shadowOffset = CGSize(width: 0, height: 5)
        notSureView.layer.shadowRadius = 14

        notSureIcon.tintColor = UIColor(red: 0.875, green: 0.439, blue: 0.541, alpha: 1.0)
        notSureIcon.image = UIImage(systemName: "sparkles")

        notSureLabel.font = UIFont.systemFont(ofSize: 13, weight: .regular)
        notSureLabel.textColor = UIColor(red: 0.478, green: 0.157, blue: 0.251, alpha: 1.0)
        notSureLabel.numberOfLines = 0
        notSureLabel.lineBreakMode = .byWordWrapping
    }
    private func setupButtons(_ buttons: [UIButton]) {
        buttons.forEach {
            $0.layer.cornerRadius = 20
            $0.backgroundColor = .clear
            $0.setTitleColor(.ainaTextPrimary, for: .normal)
            $0.layer.borderWidth = 1
            $0.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.4).cgColor
        }
    }

    private func setupNextButton() {
        nextButton.layer.cornerRadius = 20
        nextButton.backgroundColor = .ainaCoralPink
        nextButton.setTitle("Next", for: .normal) 

        nextButton.setTitleColor(.white, for: .normal)
        nextButton.setTitleColor(.white, for: .disabled)

        

        nextButton.isEnabled = false
        nextButton.alpha = 0.5
    }

    //  POPUP UI DESIGN

    private func setupPopupUI() {

        infoView.backgroundColor = UIColor.white.withAlphaComponent(0.95)
        infoView.layer.cornerRadius = 20

        // Shadow
        infoView.layer.shadowColor = UIColor.black.cgColor
        infoView.layer.shadowOpacity = 0.15
        infoView.layer.shadowOffset = CGSize(width: 0, height: 10)
        infoView.layer.shadowRadius = 25

        // Title
        infoTitleLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        infoTitleLabel.textAlignment = .center

        // Subtitle
        infoSubtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        infoSubtitleLabel.textAlignment = .center
        infoSubtitleLabel.textColor = .secondaryLabel

        // Description
        infoDescriptionLabel.font = UIFont.systemFont(ofSize: 13)
        infoDescriptionLabel.textAlignment = .center
        infoDescriptionLabel.textColor = .secondaryLabel
        infoDescriptionLabel.numberOfLines = 0

        // Icon
        infoImageView.tintColor = .ainaCoralPink
        infoImageView.contentMode = .scaleAspectFit
    }

    // MARK: - Logic

    private func updateSelection(selected: UIButton, in buttons: [UIButton]) {
        for button in buttons {
            if button == selected {

                button.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.20)
                button.setTitleColor(.ainaCoralPink, for: .normal)
                button.setTitleColor(.ainaCoralPink, for: .selected)
                button.setTitleColor(.ainaCoralPink, for: .highlighted)
                button.layer.borderColor = UIColor.ainaCoralPink.cgColor
                button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)

                UIView.animate(withDuration: 0.15,
                               animations: {
                    button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                }) { _ in
                    UIView.animate(withDuration: 0.15) {
                        button.transform = .identity
                    }
                }

            } else {
                button.backgroundColor = .clear
                button.setTitleColor(.ainaTextPrimary, for: .normal)
                button.setTitleColor(.ainaTextPrimary, for: .selected)
                button.setTitleColor(.ainaTextPrimary, for: .highlighted)
                button.layer.borderColor = UIColor.ainaTextTertiary.withAlphaComponent(0.4).cgColor
                button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .regular)
            }
        }
    }

    private func validateSelections() {
        let isComplete = onboardingData.tZone != nil &&
                         onboardingData.uZone != nil &&
                         onboardingData.cZone != nil

        nextButton.isEnabled = isComplete
        nextButton.alpha = isComplete ? 1.0 : 0.5
    }

    private func provideHaptic() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func skinType(from tag: Int) -> SkinType {
        switch tag {
        case 0: return .oily
        case 1: return .normal
        case 2: return .dry
        default: return .normal
        }
    }
//    print("isEditingProfile:", isEditingProfile)
//    print("profile:", AppDataModel.shared.userProfile?.tZone ?? "nil")

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SkinTypeToSensitivity",
           let vc = segue.destination as? OnboardingSensitivityViewController {
            vc.onboardingData = onboardingData
            vc.dataModel = dataModel
        }
    }
}
