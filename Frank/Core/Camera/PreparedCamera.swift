@preconcurrency import AVFoundation
import CoreImage
import Foundation

enum FrameQuality: String, Codable, Sendable {
    case unknown, good, poor
}

struct PreparedFrame: Equatable, Sendable {
    let id: String
    let jpeg: Data
    let capturedAt: Date
    let quality: FrameQuality

    func ageMs(at date: Date = Date()) -> Int {
        max(0, Int(date.timeIntervalSince(capturedAt) * 1_000))
    }
}

actor PreparedFrameStore {
    private var frames: [PreparedFrame] = []
    private let capacity: Int

    init(capacity: Int = 3) { self.capacity = capacity }

    func add(_ frame: PreparedFrame) {
        frames.append(frame)
        if frames.count > capacity { frames.removeFirst(frames.count - capacity) }
    }

    func freshest(maxAgeMs: Int, now: Date = Date()) -> PreparedFrame? {
        frames.reversed().first { $0.ageMs(at: now) <= maxAgeMs && $0.quality != .poor }
    }
}

protocol PreparedFrameProviding: Sendable {
    func start() async -> Bool
    func stop() async
    func freshest(maxAgeMs: Int) async -> PreparedFrame?
}

final class PreparedCamera: NSObject, PreparedFrameProviding, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "frank.camera")
    private let store = PreparedFrameStore()
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var lastCapture = Date.distantPast

    func start() async -> Bool {
        let allowed: Bool
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: allowed = true
        case .notDetermined: allowed = await AVCaptureDevice.requestAccess(for: .video)
        default: allowed = false
        }
        guard allowed else { return false }
        return await withCheckedContinuation { continuation in
            queue.async { [self] in
                do {
                    if session.inputs.isEmpty { try configure() }
                    session.startRunning()
                    continuation.resume(returning: true)
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in
                if session.isRunning { session.stopRunning() }
                continuation.resume()
            }
        }
    }

    func freshest(maxAgeMs: Int) async -> PreparedFrame? {
        await store.freshest(maxAgeMs: maxAgeMs)
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .medium
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.unavailable
        }
        try camera.lockForConfiguration()
        if camera.isFocusModeSupported(.continuousAutoFocus) { camera.focusMode = .continuousAutoFocus }
        if camera.isExposureModeSupported(.continuousAutoExposure) { camera.exposureMode = .continuousAutoExposure }
        camera.unlockForConfiguration()

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else { throw CameraError.unavailable }
        session.addInput(input)
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        guard session.canAddOutput(output) else { throw CameraError.unavailable }
        session.addOutput(output)
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastCapture) >= 0.35,
              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastCapture = now
        let image = CIImage(cvPixelBuffer: imageBuffer).oriented(.right)
        guard let jpeg = context.jpegRepresentation(
            of: image,
            colorSpace: CGColorSpaceCreateDeviceRGB(),
            options: [kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: 0.72]
        ) else { return }
        let frame = PreparedFrame(id: UUID().uuidString.lowercased(), jpeg: jpeg, capturedAt: now, quality: .good)
        Task { await store.add(frame) }
    }
}

enum CameraError: Error {
    case unavailable
}
