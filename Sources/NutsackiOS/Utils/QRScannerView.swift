import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit

struct QRScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.onScan = onScan
        controller.onDismiss = { dismiss() }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var onScan: ((String) -> Void)?
    var onDismiss: (() -> Void)?
    private var scanAreaView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = UIColor.systemBackground
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            failed()
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            failed()
            return
        }
        
        // Add overlay first
        addOverlay()
        
        // Create camera preview container with square shape
        let cameraContainer = UIView()
        cameraContainer.backgroundColor = .systemBackground
        cameraContainer.layer.cornerRadius = 12
        cameraContainer.layer.borderWidth = 3
        cameraContainer.layer.borderColor = UIColor.label.cgColor
        cameraContainer.clipsToBounds = true
        cameraContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraContainer)
        
        NSLayoutConstraint.activate([
            cameraContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            cameraContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            cameraContainer.widthAnchor.constraint(equalToConstant: 280),
            cameraContainer.heightAnchor.constraint(equalToConstant: 280)
        ])
        
        // Add preview layer to container
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = CGRect(x: 0, y: 0, width: 280, height: 280)
        previewLayer.videoGravity = .resizeAspectFill
        cameraContainer.layer.addSublayer(previewLayer)
        
        // Store reference to scan area for metadata output
        scanAreaView = cameraContainer
        
        // Add close button
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .label
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Add paste button
        let pasteButton = UIButton(type: .system)
        pasteButton.setTitle("Paste", for: .normal)
        pasteButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        pasteButton.backgroundColor = .systemBlue
        pasteButton.setTitleColor(.white, for: .normal)
        pasteButton.layer.cornerRadius = 12
        pasteButton.addTarget(self, action: #selector(pasteTapped), for: .touchUpInside)
        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pasteButton)
        
        NSLayoutConstraint.activate([
            pasteButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            pasteButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            pasteButton.widthAnchor.constraint(equalToConstant: 120),
            pasteButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }
    
    func addOverlay() {
        // Add instruction label
        let label = UILabel()
        label.text = "Scan QR Code"
        label.textColor = .label
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: view.centerYAnchor, constant: -200)
        ])
    }
    
    func failed() {
        let ac = UIAlertController(title: "Scanning not supported", message: "Your device does not support scanning a code from an item. Please use a device with a camera.", preferredStyle: .alert)
        ac.addAction(UIAlertAction(title: "OK", style: .default))
        present(ac, animated: true)
        captureSession = nil
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if (captureSession?.isRunning == true) {
            captureSession.stopRunning()
        }
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        captureSession.stopRunning()
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            found(code: stringValue)
        }
    }
    
    func found(code: String) {
        onScan?(code)
        onDismiss?()
    }
    
    @objc func closeTapped() {
        onDismiss?()
    }
    
    @objc func pasteTapped() {
        if let pasteboardString = UIPasteboard.general.string {
            found(code: pasteboardString)
        } else {
            let alert = UIAlertController(title: "No Text", message: "There is no text in the clipboard to paste.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let scanArea = scanAreaView {
            previewLayer?.frame = scanArea.bounds
        }
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
#else
// Placeholder for non-iOS platforms
struct QRScannerView: View {
    let onScan: (String) -> Void
    
    var body: some View {
        Text("QR scanning is only available on iOS")
            .foregroundColor(.secondary)
    }
}
#endif