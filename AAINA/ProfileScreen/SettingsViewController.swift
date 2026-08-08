import UIKit
import StoreKit
import MessageUI
import UserNotifications
import SafariServices
import FirebaseAuth
import GoogleSignIn

class SettingsViewController: UIViewController,
UICollectionViewDelegate,
UICollectionViewDataSource,
MFMailComposeViewControllerDelegate {

    private var collectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Settings"
        view.applyAINABackground()
        view.backgroundColor = .clear

        navigationController?.navigationBar.tintColor = .systemPink

        setupCollectionView()
        registerCells()
    }

    private func setupCollectionView() {
        collectionView = UICollectionView(
            frame: .zero,
            collectionViewLayout: createLayout()
        )

        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.backgroundColor = .clear

        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func registerCells() {

        collectionView.register(UINib(nibName: "SpreadCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SpreadCell")
        collectionView.register(UINib(nibName: "ReachCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "ReachCell")
        collectionView.register(UINib(nibName: "LegalCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "LegalCell")
        collectionView.register(UINib(nibName: "SettingsCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "SettingsCell")
        collectionView.register(UINib(nibName: "PreferencesCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "PreferencesCell")

        collectionView.register(
            UINib(nibName: "SectionHeaderReusableView", bundle: nil),
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: SectionHeaderReusableView.identifier
        )
    }

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 5
    }

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath)
    -> UICollectionViewCell {

        switch indexPath.section {

        case 0:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SpreadCell", for: indexPath) as! SpreadCollectionViewCell
            cell.onItemSelected = { [weak self] index in
                self?.handleSpreadAction(index: index)
            }
            return cell

        case 1:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ReachCell", for: indexPath) as! ReachCollectionViewCell
            cell.onItemSelected = { [weak self] index in
                self?.handleReachAction(index: index)
            }
            return cell

        case 2:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "LegalCell", for: indexPath) as! LegalCollectionViewCell
            cell.onItemSelected = { [weak self] index in
                self?.handleLegalAction(index: index)
            }
            return cell

        case 3:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PreferencesCell", for: indexPath) as! PreferencesCollectionViewCell
            
            // FIXED (NO onItemSelected)
            cell.onLanguageTapped = { [weak self] in
                self?.openLanguage()
            }

            cell.onNotificationsChanged = { [weak self] isOn in
                guard let self else { return }
                if isOn {
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                        DispatchQueue.main.async {
                            SettingsManager.shared.isNotificationsEnabled = granted
                            if !granted {
                                // Revert toggle and direct user to Settings
                                self.collectionView.reloadData()
                                let alert = UIAlertController(
                                    title: "Notifications Disabled",
                                    message: "Please enable notifications for AAINA in your iPhone Settings.",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                })
                                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
                                self.present(alert, animated: true)
                            }
                        }
                    }
                } else {
                    SettingsManager.shared.isNotificationsEnabled = false
                }
            }

            return cell

        case 4:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SettingsCell", for: indexPath) as! SettingsCollectionViewCell
            cell.onItemSelected = { [weak self] index in
                self?.handleAccountAction(index: index)
            }
            return cell

        default:
            return UICollectionViewCell()
        }
    }

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
        header.titleLabel.font = UIFont.systemFont(ofSize: 13, weight: .semibold)

        switch indexPath.section {
        case 0: header.titleLabel.text = "SPREAD THE LOVE"
        case 1: header.titleLabel.text = "REACH US"
        case 2: header.titleLabel.text = "LEGAL"
        case 3: header.titleLabel.text = "PREFERENCES"
        case 4: header.titleLabel.text = "ACCOUNT"
        default: header.titleLabel.text = ""
        }

        return header
    }

    private func createLayout() -> UICollectionViewLayout {
        return UICollectionViewCompositionalLayout { sectionIndex, _ in

            // XIB row height = 56 pt, mainStack padding = 16 top + 16 bottom = 32 pt overhead.
            // Card height = (visible rows × 56) + 32
            let rowH: CGFloat = 56
            let padding: CGFloat = 24
            let height: CGFloat
            switch sectionIndex {
            case 0: height = rowH * 3 + padding   // Spread the Love  (3 visible rows)
            case 1: height = rowH * 2 + padding   // Reach Us         (2 rows)
            case 2: height = rowH * 2 + padding   // Legal            (2 rows)
            case 3: height = rowH * 2 + padding   // Preferences      (2 rows)
            case 4: height = rowH     + padding   // Account          (1 row)
            default: height = rowH * 2 + padding
            }

            let size = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(height)
            )

            let item = NSCollectionLayoutItem(layoutSize: size)
            let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)

            section.contentInsets = NSDirectionalEdgeInsets(
                top: 8,
                leading: 20,
                bottom: 24,
                trailing: 20
            )
            let headerSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(40)
            )
            let header = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: headerSize,
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top
            )

            section.boundarySupplementaryItems = [header]
            section.interGroupSpacing = 8
            return section
        }
    }
}

// MARK: - ACTIONS

extension SettingsViewController {

    func handleSpreadAction(index: Int) {
        switch index {
        case 0: exportReport()
        case 1: shareApp()
        case 2: leaveReview()
        case 3: rateApp()
        default: break
        }
    }

    func handleReachAction(index: Int) {
        switch index {
        case 0: sendEmail()
        case 1: reportBug()
        default: break
        }
    }

    func handleLegalAction(index: Int) {
        switch index {
        case 0: openInAppBrowser("https://www.termsfeed.com/live/privacy-policy-template")
        case 1: openInAppBrowser("https://www.termsfeed.com/live/terms-of-use-template")
        default: break
        }
    }

    func handleAccountAction(index: Int) {
        logoutUser()
    }

    // MARK: - FUNCTIONS

    func exportReport() {
        // Not used — row1 in Spread is hidden
    }

    func shareApp() {
        let text = "I'm using AAINA for my skincare routine — it's amazing! Check it out "
        // Replace with actual App Store link once published
        let items: [Any] = [text]
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.popoverPresentationController?.sourceView = view
        present(vc, animated: true)
    }

    func leaveReview() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            AppStore.requestReview(in: scene)
        }
    }

    func rateApp() {
        // Opens App Store listing — replace with actual app ID once published
        if let url = URL(string: "itms-apps://itunes.apple.com/app/id000000000?action=write-review") {
            UIApplication.shared.open(url)
        } else {
            leaveReview() // fallback
        }
    }

    func sendEmail() {
        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.setToRecipients(["support@aaina.app"])
            vc.setSubject("AAINA Support Request")
            vc.setMessageBody("\n\n---\nApp Version: \(appVersion())\niOS Version: \(UIDevice.current.systemVersion)", isHTML: false)
            vc.mailComposeDelegate = self
            present(vc, animated: true)
        } else {
            // Fallback: copy email address
            UIPasteboard.general.string = "support@aaina.app"
            showToast("Email address copied: support@aaina.app")
        }
    }

    func reportBug() {
        if MFMailComposeViewController.canSendMail() {
            let vc = MFMailComposeViewController()
            vc.setToRecipients(["bugs@aaina.app"])
            vc.setSubject("Bug Report — AAINA")
            vc.setMessageBody("""
            \n\n---
            Describe the bug above this line.

            App Version: \(appVersion())
            iOS Version: \(UIDevice.current.systemVersion)
            Device: \(UIDevice.current.model)
            """, isHTML: false)
            vc.mailComposeDelegate = self
            present(vc, animated: true)
        } else {
            UIPasteboard.general.string = "bugs@aaina.app"
            showToast("Email address copied: bugs@aaina.app")
        }
    }

    func openLanguage() {
        let picker = LanguagePickerViewController()
        picker.onLanguageSelected = { [weak self] _ in
            self?.collectionView.reloadData()
        }
        navigationController?.pushViewController(picker, animated: true)
    }

    // MARK: - Helpers

    private func openInAppBrowser(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        let safari = SFSafariViewController(url: url)
        if #unavailable(iOS 26.0) {
            safari.setValue(UIColor.systemPink, forKey: "preferredControlTintColor")
        }
        present(safari, animated: true)
    }

    private func appVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build   = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    private func showToast(_ message: String) {
        let toast = UILabel()
        toast.text = message
        toast.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        toast.textColor = .white
        toast.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        toast.textAlignment = .center
        toast.numberOfLines = 2
        toast.layer.cornerRadius = 12
        toast.layer.masksToBounds = true
        toast.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toast)
        NSLayoutConstraint.activate([
            toast.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toast.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toast.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),
            toast.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])
        toast.layoutIfNeeded()
        toast.alpha = 0
        UIView.animate(withDuration: 0.3) { toast.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UIView.animate(withDuration: 0.3, animations: { toast.alpha = 0 }) { _ in toast.removeFromSuperview() }
        }
    }

    func logoutUser() {
        let alert = UIAlertController(
            title: "Log Out",
            message: "Are you sure you want to log out? Your skin profile and saved routines will be cleared.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Log Out", style: .destructive) { _ in
            try? Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()

            AppDataModel.shared.clearUserDataForLogout()
            UserDefaults.standard.removeObject(forKey: "isLoggedIn")
            UserDefaults.standard.removeObject(forKey: "userName")
            UserDefaults.standard.removeObject(forKey: "onboardingData")
            UserDefaults.standard.removeObject(forKey: "saved_concerns")
            UserDefaults.standard.removeObject(forKey: "weeklyCheckIn_lastShownWeek")
            UserDefaults.standard.removeObject(forKey: "loginDate")
            UserDefaults.standard.synchronize()

            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let loginRoot = storyboard.instantiateInitialViewController()
                ?? UINavigationController(rootViewController: storyboard.instantiateViewController(withIdentifier: "LoginViewController"))

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let sceneDelegate = windowScene.delegate as? SceneDelegate,
               let window = sceneDelegate.window ?? windowScene.windows.first {
                UIView.transition(with: window,
                                  duration: 0.4,
                                  options: .transitionCrossDissolve) {
                    window.rootViewController = loginRoot
                }
                window.makeKeyAndVisible()
            }
        })
        present(alert, animated: true)
    }

    func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Mail Delegate

    func mailComposeController(_ controller: MFMailComposeViewController,
                               didFinishWith result: MFMailComposeResult,
                               error: Error?) {
        controller.dismiss(animated: true)
    }
}
