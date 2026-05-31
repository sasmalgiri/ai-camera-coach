//
//  CameraService.swift
//  AI Camera Coach
//

import AVFoundation
import CoreImage
import UIKit

@MainActor
protocol CameraServiceDelegate: AnyObject {
    func cameraService(_ service: CameraService, didOutput frame: CIImage)
    func cameraService(_ service: CameraService, didCapture original: UIImage)
    func cameraService(_ service: CameraService, didFail error: Error)
}

/// AVFoundation lives off the main actor; the whole service is `nonisolated`.
/// Delegate notifications are explicitly hopped to the main actor.
nonisolated final class CameraService: NSObject, @unchecked Sendable {

    let session = AVCaptureSession()

    @MainActor weak var delegate: CameraServiceDelegate?

    private let sessionQueue = DispatchQueue(label: "ai.camera.coach.session")
    private let videoQueue = DispatchQueue(label: "ai.camera.coach.video")

    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var input: AVCaptureDeviceInput?

    private(set) var isConfigured = false
    private(set) var isAuthorized = false

    func requestAuthorization() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
        return isAuthorized
    }

    func configure() async {
        guard !isConfigured, isAuthorized else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                self.applyConfiguration()
                cont.resume()
            }
        }
        isConfigured = true
    }

    private func applyConfiguration() {
        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .back),
              let newInput = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(newInput) else {
            session.commitConfiguration()
            return
        }
        session.addInput(newInput)
        input = newInput

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            if let connection = videoOutput.connection(with: .video),
               connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }

        if let connection = photoOutput.connection(with: .video),
           connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
        }

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async {
            if !self.session.isRunning { self.session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    func capturePhoto(flash: AVCaptureDevice.FlashMode) {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if self.photoOutput.supportedFlashModes.contains(flash) {
                settings.flashMode = flash
            }
            settings.photoQualityPrioritization = .quality
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func switchCamera() {
        sessionQueue.async {
            guard let currentInput = self.input else { return }
            let target: AVCaptureDevice.Position =
                (currentInput.device.position == .back) ? .front : .back
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                          for: .video,
                                                          position: target),
                  let newInput = try? AVCaptureDeviceInput(device: newDevice) else {
                return
            }

            self.session.beginConfiguration()
            self.session.removeInput(currentInput)
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
                self.input = newInput
            } else {
                self.session.addInput(currentInput)
            }
            self.session.commitConfiguration()
        }
    }
}

extension CameraService: @preconcurrency AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let frame = FrameBox(image: CIImage(cvPixelBuffer: pixelBuffer))
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didOutput: frame.image)
        }
    }
}

extension CameraService: @preconcurrency AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let error {
            let errBox = ErrorBox(error: error)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.cameraService(self, didFail: errBox.error)
            }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        let imageBox = ImageBox(image: image)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.delegate?.cameraService(self, didCapture: imageBox.image)
        }
    }
}

// MARK: - Sendable boxes

private struct FrameBox: @unchecked Sendable { let image: CIImage }
private struct ImageBox: @unchecked Sendable { let image: UIImage }
private struct ErrorBox: @unchecked Sendable { let error: Error }
