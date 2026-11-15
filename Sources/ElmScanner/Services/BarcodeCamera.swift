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

    /// Builds the capture session the first time. Prefers the built-in camera
    /// so a nearby iPhone isn't picked up unasked.
    private func configure() -> Bool {
        if configured { return true }
        #if os(iOS)
        let found = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        #else
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        let found = discovery.devices.first
        #endif
        guard let device = found ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else { return false }
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canAddInput(input), session.canAddOutput(output) else { return false }
        session.addInput(input)
        session.addOutput(output)
        configured = true
        return true
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if Date.now.timeIntervalSince(Self.launchedAt) >= Self.launchQuietTime,
           smileDetector.isSmiling(in: sampleBuffer) == true {
            DispatchQueue.main.async { [weak self] in self?.noticeSmile() }
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
