import UIKit
import AVFoundation

class OnboardingCameraViewController: UIViewController {

    enum LaunchMode {
        case onboarding
        case homeFirstRoutineUpdate
        case homeRepeatAnalysis
    }

    var onboardingData: OnboardingData!
    var dataModel: AppDataModel!
    var launchMode: LaunchMode = .onboarding

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let ovalLayer = CAShapeLayer()
    private let captureButton = UIButton()
    private let tipLabel = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        overrideUserInterfaceStyle = .light
        
        view.backgroundColor = .black
        navigationItem.hidesBackButton = launchMode == .onboarding
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: launchMode == .onboarding ? "Skip" : "Cancel",
            style: .plain,
            target: self,
            action: #selector(skipTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = .black
        checkCameraPermission()
        setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { self.session.startRunning() }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        session.stopRunning()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        updateOvalOverlay()
    }

    // MARK: - Camera Setup

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted { self?.setupCamera() } else { self?.showCameraUnavailable() }
                }
            }
        default:
            showCameraUnavailable()
        }
    }

    private func setupCamera() {
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            showCameraUnavailable()
            return
        }

        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
    }

    // MARK: - UI

    private func setupUI() {
        // Oval dashed guide
        ovalLayer.fillColor = UIColor.clear.cgColor
        ovalLayer.strokeColor = UIColor.white.withAlphaComponent(0.75).cgColor
        ovalLayer.lineWidth = 2
        ovalLayer.lineDashPattern = [8, 4]
        view.layer.addSublayer(ovalLayer)

        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Skin Scan"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)

        // Tip
        tipLabel.text = "Position your face inside the oval\nGood lighting gives the best results"
        tipLabel.textColor = .white
        tipLabel.font = .systemFont(ofSize: 15, weight: .regular)
        tipLabel.textAlignment = .center
        tipLabel.numberOfLines = 2
        tipLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tipLabel)

        // Capture button
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 36
        captureButton.layer.borderWidth = 5
        captureButton.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -48),
            captureButton.widthAnchor.constraint(equalToConstant: 72),
            captureButton.heightAnchor.constraint(equalToConstant: 72),

            tipLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            tipLabel.bottomAnchor.constraint(equalTo: captureButton.topAnchor, constant: -28),
            tipLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            tipLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
        ])
    }

    private func updateOvalOverlay() {
        let width = view.bounds.width * 0.62
        let height = width * 1.35
        let x = (view.bounds.width - width) / 2
        let y = (view.bounds.height - height) / 2 - 40
        ovalLayer.path = UIBezierPath(ovalIn: CGRect(x: x, y: y, width: width, height: height)).cgPath
    }

    // MARK: - Actions

    @objc private func capturePhoto() {
        captureButton.isEnabled = false
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    @objc private func skipTapped() {
        guard launchMode == .onboarding else {
            navigationController?.popViewController(animated: true)
            return
        }

        let loadingVC = RoutineLoadingViewController()
        loadingVC.onboardingData = onboardingData
        loadingVC.dataModel = dataModel
        navigationController?.pushViewController(loadingVC, animated: true)
    }

    private func proceedToFaceScan(image: UIImage) {
        let faceScanVC = FaceScanOutputViewController()
        faceScanVC.capturedImage = image
        faceScanVC.onboardingData = onboardingData
        faceScanVC.dataModel = dataModel
        switch launchMode {
        case .onboarding:
            faceScanVC.launchMode = .onboarding
        case .homeFirstRoutineUpdate:
            faceScanVC.launchMode = .homeFirstRoutineUpdate
        case .homeRepeatAnalysis:
            faceScanVC.launchMode = .homeRepeatAnalysis
        }
        navigationController?.pushViewController(faceScanVC, animated: true)
    }

    private func showCameraUnavailable() {
        skipTapped()
    }
}

// MARK: - Photo Capture Delegate

extension OnboardingCameraViewController: AVCapturePhotoCaptureDelegate {

    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        session.stopRunning()

        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            skipTapped()
            return
        }

        proceedToFaceScan(image: image)
    }
}
