import AVFoundation
import Observation
import SwiftUI

/// Runs the Mac's camera (or an iPhone via Continuity Camera) and reports each
/// ISBN barcode it sees. Frames are read on a background queue; late frames
/// are dropped so slow recognition never builds up a backlog.
@Observable
final class BarcodeCamera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable {
        case idle, starting, running
        /// The user (or a restriction) turned camera access off.
        case denied
        /// No camera is connected.
        case unavailable
    }

    var status: Status = .idle

    /// A camera the user can pick.
    struct Choice: Identifiable, Equatable {
        let id: String        // AVCaptureDevice.uniqueID
        let name: String
        let position: AVCaptureDevice.Position
    }

    /// The cameras available now (refreshed when the scanner starts and when the list is opened).
    private(set) var cameras: [Choice] = []
    /// The camera in use.
    private(set) var currentID: String?
    @ObservationIgnored private var currentPosition: AVCaptureDevice.Position = .unspecified
    @ObservationIgnored private var videoOutput: AVCaptureVideoDataOutput?
    /// How far the frames are turned to be upright (90 is an iPhone held upright).
    @ObservationIgnored private var videoAngle: CGFloat = 90
    @ObservationIgnored private static let savedCameraKey = "scannerCameraID"

    /// True while someone is smiling at the camera (and for a moment after).
    private(set) var smiling = false
    /// What to say for the current smile: "Hello!" the first time, then any of the greetings.
    private(set) var greeting: LocalizedStringKey = "Hello!"
    @ObservationIgnored private var hasGreeted = false
    @ObservationIgnored private var nextGreetingAllowed = Date.distantPast
    @ObservationIgnored private var greetingsInARun = 0

    /// Called on the main queue for every ISBN seen, repeats included.
    @ObservationIgnored var onISBN: (String) -> Void = { _ in }
    /// Called on the main queue for a barcode that isn't an ISBN, only when the
    /// same frame held no ISBN (a book's own barcode wins over a price sticker).
    @ObservationIgnored var onOtherBarcode: (String) -> Void = { _ in }
    /// How many different books have ever been scanned (for the greetings).
    @ObservationIgnored var totalScanned: () -> Int = { 0 }
    @ObservationIgnored let session = AVCaptureSession()
    @ObservationIgnored private let smileDetector = SmileDetector()
    @ObservationIgnored private let queue = DispatchQueue(label: "ElmScanner.barcode-camera")
    @ObservationIgnored private var configured = false
    /// False once the scanner has been closed, so a camera-permission answer
    /// that arrives afterwards doesn't switch the camera on with nobody looking.
    @ObservationIgnored private var wantsRunning = false

    override init() {
        _ = Self.launchedAt
        super.init()
    }

    deinit {
        // Safety net: never leave the camera (and its light) on.
        let session = session
        queue.async { if session.isRunning { session.stopRunning() } }
    }

    func start() {
        guard status == .idle || status == .denied || status == .unavailable else { return }
        wantsRunning = true
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            run()
        case .notDetermined:
            status = .starting
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self, self.wantsRunning else { return }
                    if granted { self.run() } else { self.status = .denied }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        wantsRunning = false
        guard status == .running || status == .starting else { return }
        status = .idle
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func run() {
        status = .starting
        queue.async { [self] in
            guard configure() else {
                DispatchQueue.main.async { self.status = .unavailable }
                return
            }
            session.startRunning()
            DispatchQueue.main.async { if self.status == .starting { self.status = .running } }
        }
    }

    private static var discovery: AVCaptureDevice.DiscoverySession {
        #if os(iOS)
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        #else
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        #endif
    }

    /// Looks for connected cameras again (a webcam may have been plugged in).
    func refreshCameras() {
        let found = Self.discovery.devices.map { Choice(id: $0.uniqueID, name: $0.localizedName, position: $0.position) }
        if found != cameras { cameras = found }
    }

    /// Switches to another camera while the scanner is running (or sets it for the next start).
    func select(_ id: String) {
        guard id != currentID, let device = AVCaptureDevice(uniqueID: id) else { return }
        #if os(macOS)
        UserDefaults.standard.set(id, forKey: Self.savedCameraKey)   // the iPhone always starts on the back camera
        #endif
        guard configured else { return }
        queue.async { [self] in
            if install(device) { DispatchQueue.main.async { self.currentID = id } }
        }
    }

    /// iPhone: flips between the front and back cameras.
    func flip() {
        let wanted: AVCaptureDevice.Position = currentPosition == .front ? .back : .front
        if let other = cameras.first(where: { $0.position == wanted }) { select(other.id) }
    }

    /// The camera to start with. The iPhone starts on the back camera. On the Mac, the camera
    /// used last time if it is still connected, else the built-in one (so a nearby iPhone isn't
    /// picked up unasked).
    private func preferredDevice() -> AVCaptureDevice? {
        let devices = Self.discovery.devices
        #if os(iOS)
        return devices.first { $0.position == .back } ?? devices.first
        #else
        let saved = UserDefaults.standard.string(forKey: Self.savedCameraKey)
        return devices.first { $0.uniqueID == saved } ?? devices.first ?? AVCaptureDevice.default(for: .video)
        #endif
    }

    /// Puts a device on the session in place of the current one. Call on the camera queue.
    @discardableResult
    private func install(_ device: AVCaptureDevice) -> Bool {
        guard let input = try? AVCaptureDeviceInput(device: device) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach { session.removeInput($0) }
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        currentPosition = device.position
        applyRotation()
        return true
    }

    /// iOS: the angle that makes frames upright for how the screen is held.
    func setVideoRotation(_ angle: CGFloat) {
        queue.async { [self] in
            guard angle != videoAngle else { return }
            videoAngle = angle
            applyRotation()
        }
    }

    private func applyRotation() {
        #if os(iOS)
        if let connection = videoOutput?.connection(with: .video), connection.isVideoRotationAngleSupported(videoAngle) {
            connection.videoRotationAngle = videoAngle
        }
        #endif
    }

    /// Builds the capture session the first time.
    private func configure() -> Bool {
        if configured { return true }
        guard let device = preferredDevice() else { return false }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        guard install(device) else { return false }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddOutput(output) else { return false }
        session.addOutput(output)
        videoOutput = output
        applyRotation()
        configured = true
        let id = device.uniqueID
        DispatchQueue.main.async { self.currentID = id; self.refreshCameras() }
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if Date.now.timeIntervalSince(Self.launchedAt) >= Self.launchQuietTime {
            smileDetector.look(at: sampleBuffer, position: currentPosition) { [weak self] smiling in
                guard smiling else { return }
                DispatchQueue.main.async { self?.noticeSmile() }
            }
        }
        let scan = BarcodeReader.scan(in: sampleBuffer)
        guard !scan.isbns.isEmpty || !scan.others.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            if scan.isbns.isEmpty {
                if let other = scan.others.first { self?.onOtherBarcode(other) }
            } else {
                for isbn in scan.isbns { self?.onISBN(isbn) }
            }
        }
    }

    /// How long a greeting stays up, and the pause after it before the next may appear.
    private static let greetingDuration: TimeInterval = 5
    private static let greetingPause: TimeInterval = 1
    /// After this many greetings in a row, smiles are ignored for the longer rest.
    /// Smiles are ignored for this long after the app starts (this is first touched when the
    /// first camera is made, as the window opens).
    private static let launchQuietTime: TimeInterval = 10
    private static let launchedAt = Date.now

    private static let greetingsPerRun = 2
    private static let longRest: TimeInterval = 45

    /// Shows a greeting for 5 seconds, however long the smile lasts. Smiles seen while one
    /// is up, or in the second after it goes, are ignored; after the second in a row they
    /// are ignored for 45 seconds.
    private func noticeSmile() {
        guard !smiling, Date.now >= nextGreetingAllowed,
              Date.now.timeIntervalSince(Self.launchedAt) >= Self.launchQuietTime else { return }
        greeting = hasGreeted ? (GreetingView.greetings(totalScanned: totalScanned()).randomElement() ?? "Hello!") : "Hello!"
        hasGreeted = true
        smiling = true
        greetingsInARun += 1
        let rest = greetingsInARun >= Self.greetingsPerRun ? Self.longRest : Self.greetingPause
        if greetingsInARun >= Self.greetingsPerRun { greetingsInARun = 0 }
        nextGreetingAllowed = .now + Self.greetingDuration + rest
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.greetingDuration) { [weak self] in
            self?.smiling = false
        }
    }
}
