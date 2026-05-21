import SwiftUI
import AVFoundation

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    let onCancel: () -> Void
    let onPermissionDenied: () -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        QRScannerViewController(
            onScan: onScan,
            onCancel: onCancel,
            onPermissionDenied: onPermissionDenied
        )
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    private let onScan: (String) -> Void
    private let onCancel: () -> Void
    private let onPermissionDenied: () -> Void

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "mone.qr.scanner.session")

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didScan = false

    init(
        onScan: @escaping (String) -> Void,
        onCancel: @escaping () -> Void,
        onPermissionDenied: @escaping () -> Void
    ) {
        self.onScan = onScan
        self.onCancel = onCancel
        self.onPermissionDenied = onPermissionDenied
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addCancelButton()
        checkCameraPermission()
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
                    granted ? self.setupScanner() : self.onPermissionDenied()
                }
            }

        case .denied, .restricted:
            onPermissionDenied()

        @unknown default:
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

        for device in devices {
            do {
                let input = try AVCaptureDeviceInput(device: device)
                if captureSession.canAddInput(input) {
                    selectedInput = input
                    break
                }
            } catch {
                continue
            }
        }

        guard let selectedInput else {
            showMessage("Could not start any available camera.")
            return
        }

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

        addScannerOverlay()

        sessionQueue.async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    /// Preference order:
    /// 1. Rear primary 1x wide
    /// 2. Rear 0.5x ultra-wide
    /// 3. Rear 2x telephoto
    /// 4. Front camera
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

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !didScan else { return }

        guard
            let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
            object.type == .qr,
            let rawValue = object.stringValue,
            !rawValue.isEmpty
        else {
            return
        }

        didScan = true
        stopSession()
        onScan(rawValue)
    }

    private func addCancelButton() {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)

        button.addAction(UIAction { [weak self] _ in
            self?.onCancel()
        }, for: .touchUpInside)

        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)

        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func addScannerOverlay() {
        let label = UILabel()
        label.text = "Scan a UPI QR"
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .semibold)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        label.layer.cornerRadius = 14
        label.clipsToBounds = true

        let frameView = UIView()
        frameView.layer.borderColor = UIColor.white.withAlphaComponent(0.85).cgColor
        frameView.layer.borderWidth = 2
        frameView.layer.cornerRadius = 28
        frameView.backgroundColor = UIColor.clear

        label.translatesAutoresizingMaskIntoConstraints = false
        frameView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(frameView)
        view.addSubview(label)

        NSLayoutConstraint.activate([
            frameView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            frameView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            frameView.widthAnchor.constraint(equalToConstant: 260),
            frameView.heightAnchor.constraint(equalToConstant: 260),

            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: frameView.topAnchor, constant: -24),
            label.widthAnchor.constraint(greaterThanOrEqualToConstant: 170),
            label.heightAnchor.constraint(equalToConstant: 44)
        ])
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
