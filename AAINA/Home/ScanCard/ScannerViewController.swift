//
//  ScannerViewController.swift
//  AAINA
//
//  Ingredient Scanner — camera-first UI with square frame,
//  stability-gated OCR, and routine-match result screen.
//

import UIKit
import AVFoundation
import Vision
import CoreImage

class ScannerViewController: UIViewController {

    // ── IBOutlets kept so the XIB/storyboard still compiles ──
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var scanButton: UIButton!

    // ── Camera ──
    private let sessionQueue  = DispatchQueue(label: "scanner.session")
    private let videoQueue    = DispatchQueue(label: "scanner.video")
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private weak var cameraDevice: AVCaptureDevice?
    private let ciContext = CIContext()
    private var cameraAuthorizationInFlight = false

    // ── UI ──
    private let cameraContainer   = UIView()          // square frame
    private let cornerOverlay     = ScanFrameView()   // animated corners
    private let statusLabel       = UILabel()
    private let hintLabel         = UILabel()
    private let actionButton      = UIButton(type: .custom)
    private let dimView           = UIView()
    private let zoomControlsView  = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
    private let zoomOutButton     = UIButton(type: .system)
    private let zoomInButton      = UIButton(type: .system)
    private let zoomSlider        = UISlider()
    private let zoomValueLabel    = UILabel()
    private var minZoomFactor: CGFloat = 1
    private var maxZoomFactor: CGFloat = 1
    private var currentZoomFactor: CGFloat = 1
    private var pinchStartZoomFactor: CGFloat = 1

    // ── OCR state ──
    var step: String = ""
    private var isScanning        = false
    private var isFinishingScan   = false
    private var lastOCRDate       = Date.distantPast
    private var lastStableText    = ""
    private var stableReadCount   = 0
    private var scannedLabelText  = ""
    private var scannedIngredients: [String] = []

    private let routineManager    = RoutineManager()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ingredient Scanner"
        navigationItem.largeTitleDisplayMode = .never
        navigationController?.navigationBar.prefersLargeTitles = false
        view.applyAINABackground()
        buildUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ensureCameraPreview()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutCameraFrame()
        previewLayer?.frame = cameraContainer.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCamera()
    }

    // Keep IBAction wired up in case storyboard still references it
    @IBAction func startScanningTapped(_ sender: UIButton) {
        beginScanning()
    }
}

// MARK: - UI Construction

private extension ScannerViewController {

    func buildUI() {
        // ── background dim (behind camera frame) ──
        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        dimView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dimView)
        NSLayoutConstraint.activate([
            dimView.topAnchor.constraint(equalTo: view.topAnchor),
            dimView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // ── square camera container ──
        cameraContainer.backgroundColor = .black
        cameraContainer.layer.cornerRadius = 20
        cameraContainer.layer.cornerCurve = .continuous
        cameraContainer.clipsToBounds = true
        cameraContainer.isUserInteractionEnabled = true
        cameraContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraContainer)

        // ── corner overlay drawn on top of preview ──
        cornerOverlay.translatesAutoresizingMaskIntoConstraints = false
        cornerOverlay.backgroundColor = .clear
        cornerOverlay.isUserInteractionEnabled = false
        cameraContainer.addSubview(cornerOverlay)
        NSLayoutConstraint.activate([
            cornerOverlay.topAnchor.constraint(equalTo: cameraContainer.topAnchor),
            cornerOverlay.leadingAnchor.constraint(equalTo: cameraContainer.leadingAnchor),
            cornerOverlay.trailingAnchor.constraint(equalTo: cameraContainer.trailingAnchor),
            cornerOverlay.bottomAnchor.constraint(equalTo: cameraContainer.bottomAnchor)
        ])

        buildZoomControls()

        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleZoomPinch(_:)))
        cameraContainer.addGestureRecognizer(pinch)

        // ── status label (inside/below frame when scanning) ──
        statusLabel.text = ""
        statusLabel.textColor = .ainaTextPrimary
        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        // ── hint label ──
        hintLabel.text = "Place your product label inside the frame.\nTap Start Scanning when it looks clear."
        hintLabel.textColor = .ainaTextSecondary
        hintLabel.font = .systemFont(ofSize: 15)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        // ── action button ──
        actionButton.setTitle("Start Scanning", for: .normal)
        actionButton.setTitleColor(.white, for: .normal)
        actionButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        actionButton.backgroundColor = .ainaCoralPink
        actionButton.layer.cornerRadius = 16
        actionButton.layer.cornerCurve = .continuous
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        // subtle shadow
        actionButton.layer.shadowColor  = UIColor.ainaDustyRose.cgColor
        actionButton.layer.shadowOpacity = 0.35
        actionButton.layer.shadowOffset  = CGSize(width: 0, height: 6)
        actionButton.layer.shadowRadius  = 10
        view.addSubview(actionButton)

        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            actionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            actionButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            actionButton.heightAnchor.constraint(equalToConstant: 56),

            hintLabel.bottomAnchor.constraint(equalTo: actionButton.topAnchor, constant: -20),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            statusLabel.bottomAnchor.constraint(equalTo: hintLabel.topAnchor, constant: -8),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24)
        ])

        // hide IBOutlets so they don't interfere
        infoLabel?.isHidden = true
        scanButton?.isHidden = true
    }

    func buildZoomControls() {
        zoomControlsView.layer.cornerRadius = 18
        zoomControlsView.layer.cornerCurve = .continuous
        zoomControlsView.clipsToBounds = true
        zoomControlsView.translatesAutoresizingMaskIntoConstraints = false
        cameraContainer.addSubview(zoomControlsView)

        let content = zoomControlsView.contentView

        [zoomOutButton, zoomInButton].forEach { button in
            button.tintColor = .white
            button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
            button.layer.cornerRadius = 15
            button.layer.cornerCurve = .continuous
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 30).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
        }

        zoomOutButton.setImage(UIImage(systemName: "minus.magnifyingglass"), for: .normal)
        zoomOutButton.setTitle(UIImage(systemName: "minus.magnifyingglass") == nil ? "-" : nil, for: .normal)
        zoomOutButton.addTarget(self, action: #selector(zoomOutTapped), for: .touchUpInside)

        zoomInButton.setImage(UIImage(systemName: "plus.magnifyingglass"), for: .normal)
        zoomInButton.setTitle(UIImage(systemName: "plus.magnifyingglass") == nil ? "+" : nil, for: .normal)
        zoomInButton.addTarget(self, action: #selector(zoomInTapped), for: .touchUpInside)

        zoomSlider.minimumValue = 1
        zoomSlider.maximumValue = 1
        zoomSlider.value = 1
        zoomSlider.minimumTrackTintColor = .ainaCoralPink
        zoomSlider.maximumTrackTintColor = UIColor.white.withAlphaComponent(0.35)
        zoomSlider.thumbTintColor = .white
        zoomSlider.translatesAutoresizingMaskIntoConstraints = false
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged(_:)), for: .valueChanged)

        zoomValueLabel.text = "1.0x"
        zoomValueLabel.textColor = .white
        zoomValueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
        zoomValueLabel.textAlignment = .center
        zoomValueLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomValueLabel.setContentHuggingPriority(.required, for: .horizontal)

        content.addSubview(zoomOutButton)
        content.addSubview(zoomSlider)
        content.addSubview(zoomInButton)
        content.addSubview(zoomValueLabel)

        NSLayoutConstraint.activate([
            zoomControlsView.leadingAnchor.constraint(equalTo: cameraContainer.leadingAnchor, constant: 14),
            zoomControlsView.trailingAnchor.constraint(equalTo: cameraContainer.trailingAnchor, constant: -14),
            zoomControlsView.bottomAnchor.constraint(equalTo: cameraContainer.bottomAnchor, constant: -14),
            zoomControlsView.heightAnchor.constraint(equalToConstant: 46),

            zoomOutButton.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            zoomOutButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            zoomSlider.leadingAnchor.constraint(equalTo: zoomOutButton.trailingAnchor, constant: 10),
            zoomSlider.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            zoomInButton.leadingAnchor.constraint(equalTo: zoomSlider.trailingAnchor, constant: 10),
            zoomInButton.centerYAnchor.constraint(equalTo: content.centerYAnchor),

            zoomValueLabel.leadingAnchor.constraint(equalTo: zoomInButton.trailingAnchor, constant: 8),
            zoomValueLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            zoomValueLabel.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            zoomValueLabel.widthAnchor.constraint(equalToConstant: 42)
        ])
    }

    /// Called every layout pass — positions the square camera frame
    func layoutCameraFrame() {
        guard cameraContainer.superview != nil else { return }

        let safeTop = view.safeAreaInsets.top
        let buttonAreaHeight: CGFloat = 56 + 24 + 16   // button + bottom + gap
        let hintHeight: CGFloat = 70
        let labelHeight: CGFloat = 40
        let topPadding: CGFloat = 16

        let availableHeight = view.bounds.height
            - safeTop
            - buttonAreaHeight
            - hintHeight
            - labelHeight
            - topPadding * 2

        let side = min(view.bounds.width - 48, availableHeight)
        let x    = (view.bounds.width - side) / 2
        let y    = safeTop + topPadding

        cameraContainer.frame = CGRect(x: x, y: y, width: side, height: side)
    }
}

// MARK: - Camera Flow

private extension ScannerViewController {

    @objc func actionButtonTapped() {
        if !isScanning {
            beginScanning()
        }
    }

    func beginScanning() {
        guard !isScanning else { return }
        isScanning = true
        resetScanState()

        actionButton.isEnabled = false
        actionButton.alpha     = 0.5
        actionButton.setTitle("Scanning…", for: .normal)
        hintLabel.text         = "Hold the label steady inside the frame."
        statusLabel.text       = "Starting scan…"
        ensureCameraPreview()
    }

    func ensureCameraPreview() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCameraIfNeeded()
        case .notDetermined:
            requestCameraAccessIfNeeded()
        default:
            showPermissionDenied()
        }
    }

    func requestCameraAccessIfNeeded() {
        guard !cameraAuthorizationInFlight else { return }
        cameraAuthorizationInFlight = true
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                self.cameraAuthorizationInFlight = false
                granted ? self.setupCameraIfNeeded() : self.showPermissionDenied()
            }
        }
    }

    func setupCameraIfNeeded() {
        if let session = captureSession {
            if !session.isRunning {
                sessionQueue.async { session.startRunning() }
            }
            updatePreviewUI()
            return
        }

        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            let input  = try? AVCaptureDeviceInput(device: device)
        else { showPermissionDenied(); return }

        cameraDevice = device
        configureCamera(device)
        configureZoomLimits(for: device)

        if session.canAddInput(input)  { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(output) { session.addOutput(output) }
        if let connection = output.connection(with: .video) {
            configurePortraitOrientation(for: connection)
        }

        captureSession = session

        if previewLayer == nil {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill
            preview.frame        = cameraContainer.bounds
            cameraContainer.layer.insertSublayer(preview, at: 0)
            previewLayer = preview
        }

        sessionQueue.async { session.startRunning() }
        updatePreviewUI()
    }

    func stopCamera() {
        sessionQueue.async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    func configureCamera(_ device: AVCaptureDevice) {
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                device.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            device.unlockForConfiguration()
        } catch {
            return
        }
    }

    func configurePortraitOrientation(for connection: AVCaptureConnection) {
        if #available(iOS 17.0, *) {
            if connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        } else if (connection.value(forKey: "videoOrientationSupported") as? Bool) == true {
            connection.setValue(1, forKey: "videoOrientation")
        }
    }

    func updatePreviewUI() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.cornerOverlay.startAnimating()
            self.updateZoomControlsAvailability()
            if self.isScanning {
                self.statusLabel.text = "Hold steady inside the frame."
            } else {
                self.statusLabel.text = ""
                self.hintLabel.text = "Place your product label inside the frame.\nTap Start Scanning when it looks clear."
            }
        }
    }

    func resetScanState() {
        scannedIngredients = []
        scannedLabelText   = ""
        isFinishingScan    = false
        lastOCRDate        = .distantPast
        lastStableText     = ""
        stableReadCount    = 0
    }

    func configureZoomLimits(for device: AVCaptureDevice) {
        let supportedMaxZoom = min(device.activeFormat.videoMaxZoomFactor, 6)
        minZoomFactor = 1
        maxZoomFactor = max(minZoomFactor, supportedMaxZoom)
        applyZoomFactor(minZoomFactor, animated: false)
        updateZoomControlsAvailability()
    }

    func applyZoomFactor(_ factor: CGFloat, animated: Bool = true) {
        guard let device = cameraDevice else { return }
        let clampedFactor = min(max(factor, minZoomFactor), maxZoomFactor)

        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
        } catch {
            return
        }

        currentZoomFactor = clampedFactor
        DispatchQueue.main.async { [weak self] in
            self?.updateZoomUI(animated: animated)
        }
    }

    func updateZoomUI(animated: Bool) {
        let updates = {
            self.zoomSlider.minimumValue = Float(self.minZoomFactor)
            self.zoomSlider.maximumValue = Float(self.maxZoomFactor)
            self.zoomSlider.value = Float(self.currentZoomFactor)
            self.zoomValueLabel.text = String(format: "%.1fx", self.currentZoomFactor)
            self.updateZoomControlsAvailability()
        }

        if animated {
            UIView.animate(withDuration: 0.18, animations: updates)
        } else {
            updates()
        }
    }

    func updateZoomControlsAvailability() {
        let canZoom = maxZoomFactor > minZoomFactor
        zoomControlsView.alpha = canZoom ? 1 : 0.55
        zoomOutButton.isEnabled = canZoom && currentZoomFactor > minZoomFactor + 0.01
        zoomInButton.isEnabled = canZoom && currentZoomFactor < maxZoomFactor - 0.01
        zoomSlider.isEnabled = canZoom
    }

    @objc func zoomOutTapped() {
        applyZoomFactor(currentZoomFactor - 0.5)
    }

    @objc func zoomInTapped() {
        applyZoomFactor(currentZoomFactor + 0.5)
    }

    @objc func zoomSliderChanged(_ sender: UISlider) {
        applyZoomFactor(CGFloat(sender.value), animated: false)
    }

    @objc func handleZoomPinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pinchStartZoomFactor = currentZoomFactor
        case .changed:
            applyZoomFactor(pinchStartZoomFactor * gesture.scale, animated: false)
        default:
            break
        }
    }

    func showPermissionDenied() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.isScanning            = false
            self.actionButton.isEnabled = true
            self.actionButton.alpha    = 1
            self.actionButton.setTitle("Start Scanning", for: .normal)
            self.statusLabel.text      = ""
            self.hintLabel.text        = "Camera access is required.\nPlease enable it in Settings and try again."
        }
    }
}

// MARK: - OCR Delegate

extension ScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard CMSampleBufferGetImageBuffer(sampleBuffer) != nil,
              isScanning,
              !isFinishingScan,
              Date().timeIntervalSince(lastOCRDate) > 0.35 else { return }

        lastOCRDate = Date()
        guard let cgImage = makeCenterCropImage(from: sampleBuffer) else {
            setStatus("Point the label inside the square frame.")
            return
        }

        let request = VNRecognizeTextRequest { [weak self] req, _ in
            guard let self,
                  let obs = req.results as? [VNRecognizedTextObservation] else { return }

            let candidates   = obs.compactMap { $0.topCandidates(1).first }
            let text         = candidates.map(\.string).joined(separator: " ")
            let confidence   = candidates.isEmpty ? 0
                : candidates.map(\.confidence).reduce(0, +) / Float(candidates.count)

            self.evaluateOCR(text: text, confidence: confidence)
        }
        request.recognitionLevel       = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight      = 0.015
        request.recognitionLanguages   = ["en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
    }

    private func makeCenterCropImage(from sampleBuffer: CMSampleBuffer) -> CGImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }

        let oriented = CIImage(cvPixelBuffer: pixelBuffer).oriented(.right)
        let cropInsetRatio: CGFloat = 0.12
        let cropSide = min(oriented.extent.width, oriented.extent.height) * (1 - cropInsetRatio * 2)
        let cropRect = CGRect(
            x: oriented.extent.midX - (cropSide / 2),
            y: oriented.extent.midY - (cropSide / 2),
            width: cropSide,
            height: cropSide
        ).integral

        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        let cropped = oriented.cropped(to: cropRect)
        return ciContext.createCGImage(cropped, from: cropped.extent)
    }

    private func evaluateOCR(text: String, confidence: Float) {
        let norm = normalized(text)
        guard norm.count > 15 else {
            setStatus("Move closer to the ingredient list.")
            stableReadCount = 0
            return
        }

        guard confidence > 0.28 else {
            setStatus("Hold steady for a sharper read.")
            stableReadCount = 0
            return
        }

        let adjusting = (cameraDevice?.isAdjustingFocus ?? false) ||
                        (cameraDevice?.isAdjustingExposure ?? false)
        if adjusting {
            setStatus("Focusing… hold still.")
            return
        }

        let similarity = jaccard(norm, lastStableText)
        if similarity > 0.72 {
            stableReadCount += 1
        } else {
            stableReadCount = 1
            lastStableText  = norm
        }

        switch stableReadCount {
        case 1:    setStatus("Reading label…")
        default:   setStatus("✓ Almost ready…")
        }

        guard stableReadCount >= 2, !isFinishingScan else { return }
        isFinishingScan    = true
        scannedLabelText   = text.trimmingCharacters(in: .whitespacesAndNewlines)
        scannedIngredients = routineManager.identifyIngredients(in: norm)

        DispatchQueue.main.async { [weak self] in self?.finishScan() }
    }

    private func setStatus(_ msg: String) {
        DispatchQueue.main.async { [weak self] in
            self?.statusLabel.text = msg
        }
    }

    private func normalized(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: "[^a-z0-9,]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+",        with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func jaccard(_ a: String, _ b: String) -> Double {
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        let sa = Set(a.split(separator: " ").map(String.init))
        let sb = Set(b.split(separator: " ").map(String.init))
        let i  = sa.intersection(sb).count
        let u  = sa.union(sb).count
        return u == 0 ? 0 : Double(i) / Double(u)
    }
}

// MARK: - Result Presentation

private extension ScannerViewController {

    func finishScan() {
        stopCamera()
        cornerOverlay.stopAnimating()
        statusLabel.text = ""

        let result = routineManager.analyze(scannedIngredients: scannedIngredients, rawText: scannedLabelText, for: step)
        showResultSheet(result)
    }

    func showResultSheet(_ result: ScanAnalysisResult) {
        let vc = ScanResultViewController(result: result)
        vc.onScanAgain = { [weak self] in
            self?.resetAfterResult()
        }
        vc.modalPresentationStyle = .pageSheet
        if let sheet = vc.sheetPresentationController {
            sheet.detents             = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(vc, animated: true)
    }

    func resetAfterResult() {
        // clean up previous camera layer
        previewLayer?.removeFromSuperlayer()
        previewLayer = nil
        captureSession = nil

        resetScanState()
        isScanning             = false
        actionButton.isEnabled = true
        actionButton.alpha     = 1
        actionButton.setTitle("Start Scanning", for: .normal)
        statusLabel.text       = ""
        hintLabel.text         = "Place your product label inside the frame.\nTap Start Scanning when it looks clear."
        cornerOverlay.stopAnimating()
        ensureCameraPreview()
    }
}

// MARK: - Scan Frame View (animated corner brackets)

final class ScanFrameView: UIView {

    private let shapeLayer  = CAShapeLayer()
    private let scanLine    = CALayer()
    private var scanning    = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        shapeLayer.strokeColor = UIColor.ainaCoralPink.cgColor
        shapeLayer.fillColor   = UIColor.clear.cgColor
        shapeLayer.lineWidth   = 3
        shapeLayer.lineCap     = .round
        layer.addSublayer(shapeLayer)

        scanLine.backgroundColor = UIColor.ainaCoralPink.withAlphaComponent(0.6).cgColor
        scanLine.isHidden        = true
        layer.addSublayer(scanLine)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        drawCorners()
        scanLine.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 2)
    }

    private func drawCorners() {
        let w = bounds.width, h = bounds.height
        let c: CGFloat = 28   // corner arm length

        let path = UIBezierPath()
        // top-left
        path.move(to: CGPoint(x: 0, y: c));      path.addLine(to: CGPoint(x: 0, y: 0));      path.addLine(to: CGPoint(x: c, y: 0))
        // top-right
        path.move(to: CGPoint(x: w - c, y: 0));  path.addLine(to: CGPoint(x: w, y: 0));      path.addLine(to: CGPoint(x: w, y: c))
        // bottom-right
        path.move(to: CGPoint(x: w, y: h - c));  path.addLine(to: CGPoint(x: w, y: h));      path.addLine(to: CGPoint(x: w - c, y: h))
        // bottom-left
        path.move(to: CGPoint(x: c, y: h));      path.addLine(to: CGPoint(x: 0, y: h));      path.addLine(to: CGPoint(x: 0, y: h - c))

        shapeLayer.path  = path.cgPath
        shapeLayer.frame = bounds
    }

    func startAnimating() {
        scanning             = true
        scanLine.isHidden    = false
        scanLine.frame       = CGRect(x: 0, y: 0, width: bounds.width, height: 2)
        shapeLayer.opacity   = 1

        let anim             = CABasicAnimation(keyPath: "position.y")
        anim.fromValue       = 0
        anim.toValue         = bounds.height
        anim.duration        = 1.8
        anim.autoreverses    = true
        anim.repeatCount     = .infinity
        scanLine.add(anim, forKey: "scan")

        // pulse corners
        let pulse            = CABasicAnimation(keyPath: "opacity")
        pulse.fromValue      = 1
        pulse.toValue        = 0.4
        pulse.duration       = 0.9
        pulse.autoreverses   = true
        pulse.repeatCount    = .infinity
        shapeLayer.add(pulse, forKey: "pulse")
    }

    func stopAnimating() {
        scanning          = false
        scanLine.isHidden = true
        scanLine.removeAllAnimations()
        shapeLayer.removeAllAnimations()
        shapeLayer.opacity = 1
    }
}

// MARK: - Result Sheet

final class ScanResultViewController: UIViewController {

    var onScanAgain: (() -> Void)?

    private let result:     ScanAnalysisResult
    private let scrollView  = UIScrollView()
    private let stack       = UIStackView()

    // Warm amber for "Use with Caution" — distinct from both coral (primary) and red (avoid)
    private static let amberColor = UIColor(red: 214/255, green: 144/255, blue: 54/255, alpha: 1)

    init(result: ScanAnalysisResult) {
        self.result = result
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.applyAINABackground()
        buildLayout()
    }

    // MARK: - Layout

    private func buildLayout() {
        scrollView.showsVerticalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        stack.axis    = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -40)
        ])

        addVerdictCard()
        if !result.goodForYou.isEmpty      { addSection(result.goodForYou,      color: .ainaSageGreen) }
        if !result.useWithCaution.isEmpty   { addSection(result.useWithCaution,   color: Self.amberColor) }
        if !result.avoid.isEmpty            { addSection(result.avoid,            color: .ainaSoftRed) }
        if !result.detectedIngredients.isEmpty { addDetectedIngredientsCard() }
        addButtons()
    }

    // MARK: - Verdict Card

    private func addVerdictCard() {
        let accentColor: UIColor
        let iconName: String
        switch result.verdict {
        case .recommended:
            accentColor = .ainaSageGreen;       iconName = "checkmark.circle.fill"
        case .useWithCaution:
            accentColor = Self.amberColor;      iconName = "exclamationmark.triangle.fill"
        case .notRecommended:
            accentColor = .ainaSoftRed;         iconName = "xmark.circle.fill"
        case .notRelevant:
            accentColor = .ainaTextSecondary;   iconName = "questionmark.circle.fill"
        }

        let card = UIView()
        card.backgroundColor    = accentColor.withAlphaComponent(0.10)
        card.layer.cornerRadius = 18
        card.layer.cornerCurve  = .continuous
        card.translatesAutoresizingMaskIntoConstraints = false

        let bar = UIView()
        bar.backgroundColor    = accentColor
        bar.layer.cornerRadius = 3
        bar.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bar)

        let iconView = UIImageView(image: UIImage(systemName: iconName))
        iconView.tintColor    = accentColor
        iconView.contentMode  = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.text      = result.verdict.label
        titleLabel.font      = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textColor = accentColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let reasonLabel = UILabel()
        reasonLabel.text          = result.verdictReason
        reasonLabel.font          = .systemFont(ofSize: 14)
        reasonLabel.textColor     = .ainaTextPrimary
        reasonLabel.numberOfLines = 0
        reasonLabel.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(iconView)
        card.addSubview(titleLabel)
        card.addSubview(reasonLabel)

        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            bar.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            bar.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            bar.widthAnchor.constraint(equalToConstant: 4),

            iconView.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 14),
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            iconView.widthAnchor.constraint(equalToConstant: 26),
            iconView.heightAnchor.constraint(equalToConstant: 26),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            titleLabel.centerYAnchor.constraint(equalTo: iconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),

            reasonLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 10),
            reasonLabel.leadingAnchor.constraint(equalTo: bar.trailingAnchor, constant: 14),
            reasonLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            reasonLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])

        stack.addArrangedSubview(card)
    }

    // MARK: - Ingredient Section Card

    private func addSection(_ items: [CategorisedIngredient], color: UIColor) {
        let card = UIView()
        card.backgroundColor     = UIColor.white.withAlphaComponent(0.62)
        card.layer.cornerRadius  = 16
        card.layer.cornerCurve   = .continuous
        card.layer.shadowColor   = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.07
        card.layer.shadowRadius  = 8
        card.layer.shadowOffset  = CGSize(width: 0, height: 3)

        let vStack = UIStackView()
        vStack.axis    = .vertical
        vStack.spacing = 10
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        let header = UILabel()
        header.text      = sectionTitle(for: items[0].category, count: items.count)
        header.font      = .systemFont(ofSize: 11, weight: .bold)
        header.textColor = color

        let sep = UIView()
        sep.backgroundColor = color.withAlphaComponent(0.20)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true

        vStack.addArrangedSubview(header)
        vStack.addArrangedSubview(sep)

        for item in items {
            vStack.addArrangedSubview(makeIngredientRow(item, color: color))
        }

        stack.addArrangedSubview(card)
    }

    private func sectionTitle(for category: IngredientCategory, count: Int) -> String {
        let base: String
        switch category {
        case .goodForYou:     base = "GOOD FOR YOU"
        case .useWithCaution: base = "USE WITH CAUTION"
        case .avoid:          base = "AVOID"
        }
        return "\(base)  (\(count))"
    }

    private func makeIngredientRow(_ item: CategorisedIngredient, color: UIColor) -> UIView {
        let row = UIStackView()
        row.axis      = .horizontal
        row.alignment = .top
        row.spacing   = 10

        let iconLabel = UILabel()
        switch item.category {
        case .goodForYou:     iconLabel.text = "✓"
        case .useWithCaution: iconLabel.text = "!"
        case .avoid:          iconLabel.text = "✕"
        }
        iconLabel.textColor = color
        iconLabel.font      = .systemFont(ofSize: 13, weight: .bold)
        iconLabel.setContentHuggingPriority(.required, for: .horizontal)
        iconLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        let textStack = UIStackView()
        textStack.axis    = .vertical
        textStack.spacing = 2

        let nameLabel = UILabel()
        nameLabel.text      = item.name
        nameLabel.font      = .systemFont(ofSize: 15, weight: .medium)
        nameLabel.textColor = .ainaTextPrimary
        nameLabel.numberOfLines = 0

        textStack.addArrangedSubview(nameLabel)

        if !item.explanation.isEmpty {
            let expLabel = UILabel()
            expLabel.text      = item.explanation
            expLabel.font      = .systemFont(ofSize: 13)
            expLabel.textColor = .ainaTextSecondary
            expLabel.numberOfLines = 0
            textStack.addArrangedSubview(expLabel)
        }

        row.addArrangedSubview(iconLabel)
        row.addArrangedSubview(textStack)
        return row
    }

    // MARK: - Detected Ingredients Card

    private func addDetectedIngredientsCard() {
        let card = UIView()
        card.backgroundColor     = UIColor.white.withAlphaComponent(0.50)
        card.layer.cornerRadius  = 16
        card.layer.cornerCurve   = .continuous
        card.layer.shadowColor   = UIColor.ainaCardShadowColor.cgColor
        card.layer.shadowOpacity = 0.06
        card.layer.shadowRadius  = 6
        card.layer.shadowOffset  = CGSize(width: 0, height: 2)

        let vStack = UIStackView()
        vStack.axis    = .vertical
        vStack.spacing = 8
        vStack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(vStack)

        NSLayoutConstraint.activate([
            vStack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
            vStack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            vStack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            vStack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14)
        ])

        let header = UILabel()
        header.text      = "RECOGNISED INGREDIENTS  (\(result.detectedIngredients.count))"
        header.font      = .systemFont(ofSize: 11, weight: .bold)
        header.textColor = .ainaTextSecondary

        let sep = UIView()
        sep.backgroundColor = UIColor.ainaTextSecondary.withAlphaComponent(0.15)
        sep.translatesAutoresizingMaskIntoConstraints = false
        sep.heightAnchor.constraint(equalToConstant: 1).isActive = true

        let listLabel = UILabel()
        listLabel.text          = result.detectedIngredients.map { $0.capitalized }.joined(separator: "  •  ")
        listLabel.font          = .systemFont(ofSize: 12)
        listLabel.textColor     = .ainaTextSecondary
        listLabel.numberOfLines = 0

        vStack.addArrangedSubview(header)
        vStack.addArrangedSubview(sep)
        vStack.addArrangedSubview(listLabel)

        stack.addArrangedSubview(card)
    }

    // MARK: - Buttons

    private func addButtons() {
        let scanAgain = UIButton(type: .custom)
        scanAgain.setTitle("Scan Again", for: .normal)
        scanAgain.setTitleColor(.white, for: .normal)
        scanAgain.titleLabel?.font   = .systemFont(ofSize: 17, weight: .semibold)
        scanAgain.backgroundColor    = .ainaCoralPink
        scanAgain.layer.cornerRadius = 16
        scanAgain.layer.cornerCurve  = .continuous
        scanAgain.translatesAutoresizingMaskIntoConstraints = false
        scanAgain.heightAnchor.constraint(equalToConstant: 52).isActive = true
        scanAgain.addTarget(self, action: #selector(scanAgainTapped), for: .touchUpInside)

        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.setTitleColor(.ainaTextSecondary, for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 16)
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)

        stack.addArrangedSubview(scanAgain)
        stack.addArrangedSubview(done)
    }

    @objc private func scanAgainTapped() {
        dismiss(animated: true) { [weak self] in self?.onScanAgain?() }
    }

    @objc private func doneTapped() {
        dismiss(animated: true)
    }
}
