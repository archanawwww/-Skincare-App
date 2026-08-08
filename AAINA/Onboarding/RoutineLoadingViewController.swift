import UIKit

class RoutineLoadingViewController: UIViewController {

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!
    var capturedImage: UIImage?
    var returnToMainAppAfterGeneration = true

    private let spinner = UIActivityIndicatorView(style: .large)
    private let headlineLabel = UILabel()
    private let subLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        navigationItem.hidesBackButton = true
        view.backgroundColor = .systemBackground
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startAnalysis()
    }

    // MARK: - UI

    private func setupUI() {
        spinner.color = .label
        spinner.startAnimating()
        spinner.translatesAutoresizingMaskIntoConstraints = false

        headlineLabel.text = "Building your routine…"
        headlineLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        headlineLabel.textAlignment = .center
        headlineLabel.translatesAutoresizingMaskIntoConstraints = false

        subLabel.text = "Personalising based on your skin profile"
        subLabel.font = .systemFont(ofSize: 15)
        subLabel.textColor = .secondaryLabel
        subLabel.textAlignment = .center
        subLabel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(spinner)
        view.addSubview(headlineLabel)
        view.addSubview(subLabel)

        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),

            headlineLabel.topAnchor.constraint(equalTo: spinner.bottomAnchor, constant: 28),
            headlineLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            headlineLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            headlineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            subLabel.topAnchor.constraint(equalTo: headlineLabel.bottomAnchor, constant: 8),
            subLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Gemini Call

    private func startAnalysis() {
        Task {
            do {
                let loginName = UserDefaults.standard.string(forKey: "userName") ?? "User"
                if await dataModel.loadTodayRoutineFromFirestore() != nil {
                    if let profile = UserProfile.from(onboarding: self.onboardingData, name: loginName) {
                        AppDataModel.shared.saveProfile(profile)
                    }
                    await MainActor.run {
                        if self.returnToMainAppAfterGeneration {
                            self.transitionToOnboardingResult()
                        } else {
                            self.navigationController?.popToRootViewController(animated: true)
                        }
                    }
                    return
                }

                let prompt = RoutinePromptBuilder.build(
                    onboardingData: onboardingData,
                    ingredients: dataModel.allIngredients(),
                    imageProvided: capturedImage != nil
                )
                let output = try await GeminiFreeService().generateRoutine(
                    prompt: prompt,
                    image: capturedImage
                )

                dataModel.saveAIRoutine(output.routine)
                dataModel.saveLastFaceScanResult(output.scanResult)

                if let profile = UserProfile.from(onboarding: self.onboardingData, name: loginName) {
                    AppDataModel.shared.saveProfile(profile)
                }

                await MainActor.run {
                    if self.returnToMainAppAfterGeneration {
                        self.transitionToOnboardingResult()
                    } else {
                        self.navigationController?.popToRootViewController(animated: true)
                    }
                }
            } catch {
                await MainActor.run { self.showFailureAlert(error: error) }
            }
        }
    }

    // MARK: - Navigation

    private func transitionToMainApp() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let tabBarVC = storyboard.instantiateViewController(
            withIdentifier: "MainTabBarViewController"
        ) as? MainTabBarViewController else { return }
        tabBarVC.dataModel = dataModel
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let sceneDelegate = windowScene.delegate as? SceneDelegate {
            sceneDelegate.window?.rootViewController = tabBarVC
            sceneDelegate.window?.makeKeyAndVisible()
        }
    }

    private func transitionToOnboardingResult() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let resultVC = storyboard.instantiateViewController(
            withIdentifier: "OnboardingResultViewController"
        ) as? OnboardingResultViewController else { return }
        resultVC.onboardingData = onboardingData
        resultVC.dataModel = dataModel
        navigationController?.pushViewController(resultVC, animated: true)
    }

    private func showFailureAlert(error: Error) {
        let nsError = error as NSError
        let detail: String
        if nsError.domain == "Gemini" && nsError.code == 429 {
            detail = "The AI service is rate-limited right now. Please try again in a minute or use a default routine."
        } else if nsError.domain == "Gemini" {
            detail = "Gemini error (\(nsError.code)). \(nsError.localizedDescription)"
        } else {
            detail = nsError.localizedDescription
        }

        let alert = UIAlertController(
            title: "Couldn't build your routine",
            message: detail,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Retry", style: .default) { [weak self] _ in
            self?.startAnalysis()
        })
        alert.addAction(UIAlertAction(title: "Use Default Routine", style: .cancel) { [weak self] _ in
            guard let self else { return }
            let loginName = UserDefaults.standard.string(forKey: "userName") ?? "User"
            if let profile = UserProfile.from(onboarding: self.onboardingData, name: loginName) {
                AppDataModel.shared.saveProfile(profile)
            }
            DispatchQueue.main.async { self.transitionToOnboardingResult() }
        })
        present(alert, animated: true)
    }
}
