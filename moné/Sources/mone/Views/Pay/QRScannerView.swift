import SwiftUI
import AVFoundation
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    /// Return true when the QR is accepted.
    /// Return false when the QR is not valid for this screen.
    let onCodeDetected: (String) -> Bool
    let onPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(
            onCodeDetected: onCodeDetected,
            onPermissionDenied: onPermissionDenied
        )
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    private let onCodeDetected: (String) -> Bool
    private let onPermissionDenied: () -> Void

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "mone.qr.scanner.session")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var activeVideoDevice: AVCaptureDevice?
    private var didAcceptCode = false
    private var isSessionConfigured = false

    private var toastLabel: UILabel?
    private var lastRejectedCode: String?
    private var lastRejectedAt: Date?

    private var initialZoomFactor: CGFloat = 1.0

    init(
        onCodeDetected: @escaping (String) -> Bool,
        onPermissionDenied: @escaping () -> Void
    ) {
        self.onCodeDetected = onCodeDetected
        self.onPermissionDenied = onPermissionDenied
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
            Foundation.NotificationCenter.default.removeObserver(self)
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            view.backgroundColor = .black
            checkCameraPermission()
            addPinchToZoom()

            Foundation.NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidBecomeActive),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if isSessionConfigured, !didAcceptCode {
            startSession()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupScanner()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    if granted {
                        self.setupScanner()
                    } else {
                        self.showMessage("Camera permission is needed to scan UPI QR codes.")
                        self.onPermissionDenied()
                    }
                }
            }

        case .denied, .restricted:
            showMessage("Camera permission is needed to scan UPI QR codes. Enable it from iPhone Settings.")
            onPermissionDenied()

        @unknown default:
            showMessage("Camera permission is unavailable.")
            onPermissionDenied()
        }
    }

    private func setupScanner() {
        let devices = preferredCameraDevices()

        guard !devices.isEmpty else {
            showMessage("No camera is available on this device.")
            return
        }

        var selectedInput: AVCaptureDeviceInput?
        var selectedDevice: AVCaptureDevice?

        for device in devices {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input) {
                    selectedInput = input
                    selectedDevice = device
                    break
                }
            } catch {
                continue
            }
        }

        guard let selectedInput, let selectedDevice else {
            showMessage("Could not start any available camera.")
            return
        }

        activeVideoDevice = selectedDevice
        captureSession.addInput(selectedInput)

        let metadataOutput = AVCaptureMetadataOutput()

        guard captureSession.canAddOutput(metadataOutput) else {
            showMessage("Could not scan QR codes.")
            return
        }

        captureSession.addOutput(metadataOutput)
        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)

        guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
            showMessage("QR scanning is not supported on this device.")
            return
        }

        metadataOutput.metadataObjectTypes = [.qr]

        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds

        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        addScannerGlassOverlay()

        isSessionConfigured = true
        startSession()
    }

    /// Preference order:
    /// 1. Rear primary 1x wide
    /// 2. Rear 0.5x ultra-wide
    /// 3. Rear 2x telephoto
    /// 4. Front camera
    ///
    /// Note: iOS can only tell us whether a camera device can be opened.
    /// It cannot reliably detect a physically damaged lens that still initializes.
    private func preferredCameraDevices() -> [AVCaptureDevice] {
        let candidates: [AVCaptureDevice?] = [
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
            AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back),
            AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back),
            AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        ]

        var seen = Set<String>()

        return candidates.compactMap { device in
            guard let device else { return nil }
            guard !seen.contains(device.uniqueID) else { return nil }
            seen.insert(device.uniqueID)
            return device
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
    
    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didAcceptCode else { return }

        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let rawValue = object.stringValue,
            !rawValue.isEmpty
        else {
            return
        }

        let accepted = onCodeDetected(rawValue)

        if accepted {
            didAcceptCode = true
            stopSession()
        } else {
            showInvalidQRToast(for: rawValue)
        }
    }

    // MARK: - Zoom

    private func addPinchToZoom() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        view.addGestureRecognizer(pinch)
    }
    
    @objc private func appDidBecomeActive() {
        if isSessionConfigured, !didAcceptCode {
            startSession()
        }
    }

    @objc private func handlePinch(_ sender: UIPinchGestureRecognizer) {
        guard let device = activeVideoDevice else { return }

        switch sender.state {
        case .began:
            initialZoomFactor = device.videoZoomFactor

        case .changed:
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6.0)
            let desiredZoom = initialZoomFactor * sender.scale
            let clampedZoom = max(1.0, min(desiredZoom, maxZoom))

            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = clampedZoom
                device.unlockForConfiguration()
            } catch {
                return
            }

        default:
            break
        }
    }

    // MARK: - Overlay

    private func addScannerGlassOverlay() {
        let overlay = ScannerGlassOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func showInvalidQRToast(for rawValue: String) {
        let now = Date()

        if lastRejectedCode == rawValue,
           let lastRejectedAt,
           now.timeIntervalSince(lastRejectedAt) < 2.0 {
            return
        }

        lastRejectedCode = rawValue
        lastRejectedAt = now

        MoneTactileFeedback.playInvalidScanRejection()
        showToast("This isn’t a UPI payment QR")
    }

    private func showToast(_ message: String) {
        toastLabel?.removeFromSuperview()

        let label = PaddedLabel()
        label.text = message
        label.textInsets = UIEdgeInsets(top: 12, left: 18, bottom: 12, right: 18)
        label.textColor = .white
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        label.numberOfLines = 2
        label.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        label.layer.cornerRadius = 18
        label.clipsToBounds = true
        label.alpha = 0

        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        toastLabel = label

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -34),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48)
        ])

        UIView.animate(withDuration: 0.18) {
            label.alpha = 1
            label.transform = CGAffineTransform(translationX: 0, y: -4)
        } completion: { _ in
            UIView.animate(
                withDuration: 0.22,
                delay: 1.75,
                options: [.curveEaseInOut]
            ) {
                label.alpha = 0
                label.transform = CGAffineTransform(translationX: 0, y: 4)
            } completion: { _ in
                label.removeFromSuperview()
            }
        }
    }

    private func showMessage(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0

        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28)
        ])
    }
}

// MARK: - Glass Overlay

final class ScannerGlassOverlayView: UIView {

    private let materialView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemChromeMaterialDark)
    )

    private let tintView = UIView()
    private let shineView = UIView()
    private let dimView = UIView()

    private let viewfinderView = UIView()
    private let innerRimView = UIView()
    private let titleLabel = UILabel()
    private let helperLabel = UILabel()

    private let tintLayer = CAGradientLayer()
    private let shineLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        isUserInteractionEnabled = false
        setup()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        tintLayer.frame = bounds
        shineLayer.frame = bounds

        applyOutsideCutoutMask(to: materialView.layer)
        applyOutsideCutoutMask(to: tintView.layer)
        applyOutsideCutoutMask(to: shineView.layer)
        applyOutsideCutoutMask(to: dimView.layer)
    }

    private func setup() {
        materialView.translatesAutoresizingMaskIntoConstraints = false
        tintView.translatesAutoresizingMaskIntoConstraints = false
        shineView.translatesAutoresizingMaskIntoConstraints = false
        dimView.translatesAutoresizingMaskIntoConstraints = false
        viewfinderView.translatesAutoresizingMaskIntoConstraints = false
        innerRimView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        helperLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(materialView)
        addSubview(tintView)
        addSubview(shineView)
        addSubview(dimView)
        addSubview(viewfinderView)
        addSubview(innerRimView)
        addSubview(titleLabel)
        addSubview(helperLabel)

        tintLayer.colors = [
            UIColor.white.withAlphaComponent(0.18).cgColor,
            UIColor.white.withAlphaComponent(0.04).cgColor,
            UIColor.black.withAlphaComponent(0.12).cgColor
        ]
        tintLayer.startPoint = CGPoint(x: 0.12, y: 0.0)
        tintLayer.endPoint = CGPoint(x: 0.9, y: 1.0)
        tintLayer.locations = [0.0, 0.42, 1.0]
        tintView.layer.addSublayer(tintLayer)

        shineLayer.colors = [
            UIColor.white.withAlphaComponent(0.32).cgColor,
            UIColor.white.withAlphaComponent(0.08).cgColor,
            UIColor.clear.cgColor
        ]
        shineLayer.startPoint = CGPoint(x: 0.0, y: 0.0)
        shineLayer.endPoint = CGPoint(x: 1.0, y: 1.0)
        shineLayer.locations = [0.0, 0.22, 0.58]
        shineView.layer.addSublayer(shineLayer)

        dimView.backgroundColor = UIColor.black.withAlphaComponent(0.12)

        viewfinderView.backgroundColor = .clear
        viewfinderView.layer.cornerRadius = 32
        viewfinderView.layer.borderWidth = 2
        viewfinderView.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        viewfinderView.layer.shadowColor = UIColor.white.cgColor
        viewfinderView.layer.shadowOpacity = 0.28
        viewfinderView.layer.shadowRadius = 14
        viewfinderView.layer.shadowOffset = .zero

        innerRimView.backgroundColor = .clear
        innerRimView.layer.cornerRadius = 26
        innerRimView.layer.borderWidth = 1
        innerRimView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor

        titleLabel.text = "Scan a UPI QR"
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        helperLabel.text = "Pinch to zoom"
        helperLabel.textColor = UIColor.white.withAlphaComponent(0.76)
        helperLabel.textAlignment = .center
        helperLabel.font = .systemFont(ofSize: 13, weight: .medium)

        NSLayoutConstraint.activate([
            materialView.topAnchor.constraint(equalTo: topAnchor),
            materialView.leadingAnchor.constraint(equalTo: leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: trailingAnchor),
            materialView.bottomAnchor.constraint(equalTo: bottomAnchor),

            tintView.topAnchor.constraint(equalTo: topAnchor),
            tintView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: bottomAnchor),

            shineView.topAnchor.constraint(equalTo: topAnchor),
            shineView.leadingAnchor.constraint(equalTo: leadingAnchor),
            shineView.trailingAnchor.constraint(equalTo: trailingAnchor),
            shineView.bottomAnchor.constraint(equalTo: bottomAnchor),

            dimView.topAnchor.constraint(equalTo: topAnchor),
            dimView.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimView.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimView.bottomAnchor.constraint(equalTo: bottomAnchor),

            viewfinderView.centerXAnchor.constraint(equalTo: centerXAnchor),
            viewfinderView.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -18),
            viewfinderView.widthAnchor.constraint(equalToConstant: 270),
            viewfinderView.heightAnchor.constraint(equalToConstant: 270),

            innerRimView.centerXAnchor.constraint(equalTo: viewfinderView.centerXAnchor),
            innerRimView.centerYAnchor.constraint(equalTo: viewfinderView.centerYAnchor),
            innerRimView.widthAnchor.constraint(equalTo: viewfinderView.widthAnchor, constant: -22),
            innerRimView.heightAnchor.constraint(equalTo: viewfinderView.heightAnchor, constant: -22),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: viewfinderView.topAnchor, constant: -24),

            helperLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            helperLabel.topAnchor.constraint(equalTo: viewfinderView.bottomAnchor, constant: 18)
        ])
    }

    private func applyOutsideCutoutMask(to layer: CALayer) {
        let fullPath = UIBezierPath(rect: bounds)

        let cutoutFrame = viewfinderView.frame.insetBy(dx: -6, dy: -6)
        let cutoutPath = UIBezierPath(
            roundedRect: cutoutFrame,
            cornerRadius: viewfinderView.layer.cornerRadius + 6
        )

        fullPath.append(cutoutPath)

        let mask = CAShapeLayer()
        mask.frame = bounds
        mask.path = fullPath.cgPath
        mask.fillRule = .evenOdd

        layer.mask = mask
    }
}

final class PaddedLabel: UILabel {
    var textInsets = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: textInsets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + textInsets.left + textInsets.right,
            height: size.height + textInsets.top + textInsets.bottom
        )
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let adjustedSize = CGSize(
            width: size.width - textInsets.left - textInsets.right,
            height: size.height - textInsets.top - textInsets.bottom
        )

        let fittingSize = super.sizeThatFits(adjustedSize)

        return CGSize(
            width: fittingSize.width + textInsets.left + textInsets.right,
            height: fittingSize.height + textInsets.top + textInsets.bottom
        )
    }
}
