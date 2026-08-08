import UIKit
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import Lottie

class LoginViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var animationContainerView: UIView!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var subtitleLabel: UILabel!
    @IBOutlet weak var appleButton: UIButton!
    @IBOutlet weak var googleButton: UIButton!
    @IBOutlet weak var privacyLabel: UILabel!

    // Lottie view — added in code since storyboard cant render it directly
    private var animationView: LottieAnimationView!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        setupBackground()
        setupLottieAnimation()
        styleButtons()
    }

    // MARK: - Background
    // light pink matching app theme
    private func setupBackground() {
        view.backgroundColor = UIColor(red: 0.96, green: 0.90, blue: 0.92, alpha: 1)
    }

    // MARK: - Lottie Animation
    // adding lottie on top of the outlet container view
    private func setupLottieAnimation() {
        animationView = LottieAnimationView(name: "face_animation")
        animationView.translatesAutoresizingMaskIntoConstraints = false
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .loop
        animationView.backgroundColor = .clear
        animationView.isOpaque = false
        animationView.play()

        animationContainerView.addSubview(animationView)

        // pin lottie to fill the container view fully
        NSLayoutConstraint.activate([
            animationView.topAnchor.constraint(equalTo: animationContainerView.topAnchor),
            animationView.leadingAnchor.constraint(equalTo: animationContainerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: animationContainerView.trailingAnchor),
            animationView.bottomAnchor.constraint(equalTo: animationContainerView.bottomAnchor)
        ])
    }

    // MARK: - Button Styling
    // styling done in code since storyboard doesnt handle corner radius well
    private func styleButtons() {
        appleButton.layer.cornerRadius = 14
        appleButton.clipsToBounds = true

        googleButton.layer.cornerRadius = 14
        googleButton.layer.borderWidth = 1
        googleButton.layer.borderColor = UIColor.lightGray.cgColor
        googleButton.clipsToBounds = true
    }

    // MARK: - Google Login
    @IBAction func googleTapped(_ sender: UIButton) {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("missing clientID from firebase")
            return
        }

        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        GIDSignIn.sharedInstance.signIn(withPresenting: self) { result, error in
            if let error = error {
                print("google sign in error:", error.localizedDescription)
                return
            }

            guard let user = result?.user else { return }
            guard let idToken = user.idToken?.tokenString else {
                print("google sign in missing id token")
                return
            }
            let name = user.profile?.name ?? "User"
            let accessToken = user.accessToken.tokenString
            Task {
                do {
                    let firebaseUser = try await FirestoreSyncService.shared.signInWithGoogle(
                        idToken: idToken,
                        accessToken: accessToken
                    )
                    let exists = try await FirestoreSyncService.shared.userDocumentExists(uid: firebaseUser.uid)
                    await FirestoreSyncService.shared.upsertUserShell(name: name, isGuest: false)
                    let state = try await FirestoreSyncService.shared.loadUserState()
                    await AppDataModel.shared.applyRemoteUserState(state)
                    await MainActor.run {
                        self.saveLogin(name: name, isGuest: false)
                        if exists, state.profile != nil {
                            self.goToHome()
                        } else {
                            self.goToOnboarding()
                        }
                    }
                } catch {
                    await MainActor.run {
                        print("firebase google sign in error:", error.localizedDescription)
                        self.showLoginError(error)
                    }
                }
            }
        }
    }

    // MARK: - Apple Login
    // Sign In with Apple requires a paid Apple Developer Program membership.
    // The capability has been disabled until the app is enrolled in the program.
    @IBAction func appleTapped(_ sender: UIButton) {
        let alert = UIAlertController(
            title: "Coming Soon",
            message: "Sign In with Apple will be available in a future release. Please use Google Sign-In.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // --- Requires Apple Developer Program enrollment ($99/year) ---
        // let request = ASAuthorizationAppleIDProvider().createRequest()
        // request.requestedScopes = [.fullName, .email]
        // let controller = ASAuthorizationController(authorizationRequests: [request])
        // controller.delegate = self
        // controller.presentationContextProvider = self
        // controller.performRequests()
    }

    // MARK: - Save Login Info
    // saving login state and name to userdefaults
    // member since year is only set once — never overwritten
    private func saveLogin(name: String, isGuest: Bool = false) {
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(name, forKey: "userName")
        UserDefaults.standard.set(isGuest, forKey: "isGuestLogin")
        if UserDefaults.standard.object(forKey: "loginDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "loginDate")
        }

        if UserDefaults.standard.integer(forKey: "member_since_year") == 0 {
            let year = Calendar.current.component(.year, from: Date())
            UserDefaults.standard.set(year, forKey: "member_since_year")
        }
    }

    // MARK: - Go To Onboarding
    // replacing root view controller so user cant go back to login
    private func goToOnboarding() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        guard let dobVC = storyboard.instantiateViewController(
            withIdentifier: "OnboardingDOBViewController"
        ) as? OnboardingDOBViewController else {
            print("dob view controller not found in storyboard")
            return
        }

        dobVC.dataModel = AppDataModel.shared
        dobVC.onboardingData = AppDataModel.shared.loadOnboardingProgress() ?? OnboardingData()

        let nav = UINavigationController(rootViewController: dobVC)

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = nav
            window.makeKeyAndVisible()
        }
    }

    private func goToHome() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        guard let tabBarVC = storyboard.instantiateViewController(
            withIdentifier: "MainTabBarViewController"
        ) as? MainTabBarViewController else { return }
        tabBarVC.dataModel = AppDataModel.shared

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController = tabBarVC
            window.makeKeyAndVisible()
        }
    }

    private func showLoginError(_ error: Error) {
        let alert = UIAlertController(
            title: "Login failed",
            message: error.localizedDescription,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Apple Sign In Delegate
// Disabled — requires Apple Developer Program enrollment.
// Re-enable by restoring the delegate conformance and uncommenting appleTapped().
//
// extension LoginViewController: ASAuthorizationControllerDelegate,
//                                 ASAuthorizationControllerPresentationContextProviding {
//
//     func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
//         return view.window!
//     }
//
//     func authorizationController(
//         controller: ASAuthorizationController,
//         didCompleteWithAuthorization authorization: ASAuthorization
//     ) {
//         if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
//             let given  = credential.fullName?.givenName ?? ""
//             let family = credential.fullName?.familyName ?? ""
//             let fullName = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
//             let existing = UserDefaults.standard.string(forKey: "userName") ?? ""
//             let name = fullName.isEmpty ? (existing.isEmpty ? "User" : existing) : fullName
//             saveLogin(name: name)
//             goToOnboarding()
//         }
//     }
//
//     func authorizationController(
//         controller: ASAuthorizationController,
//         didCompleteWithError error: Error
//     ) {
//         print("apple sign in failed:", error.localizedDescription)
//     }
// }
