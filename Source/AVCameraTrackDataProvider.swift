//
//  SystemAudioVideoProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import AVFoundation

extension AVCameraTrackDataProvider {
    
    public enum Error: Swift.Error {
        case captureDeviceUnavailable(CaptureDeviceUnavailableReason)
        case failToAddDeviceInput
        case unsupportedPreset(AVCaptureSession.Preset)
        case internalError(NSError)
        
        public enum CaptureDeviceUnavailableReason: Int {
            case audioDeviceUnavailable
            case videoDeviceUnavailable
        }
    }
}

public class AVCameraTrackDataProvider: NSObject, MovieTrackDataProvider {
    
    private let sessionqueue: DispatchQueue
    private var cameraType: CameraType
    private var hasAudioTrack: Bool
    private var running: Bool = false
    
    public enum CameraType {
        case back(AVCaptureSession.Preset)
        case front(AVCaptureSession.Preset)
        
        public var preset: AVCaptureSession.Preset {
            switch self {
            case .back(let preset), .front(let preset):
                return preset
            }
        }
    }
    
    public var errorHandler: ((MovieTrackDataProviderError) -> Void)?
    
    public var trackDataHandler: ((MovieTrackData) -> Void)?
    
    public var isRunning: Bool {
        return running
    }
    
    public var trackConfiguration: MovieTrackConfiguration
    
    public private(set) var session: AVCaptureSession?
    
    public init(cameraType: CameraType, trackConfiguration: MovieTrackConfiguration) {
        self.cameraType = cameraType
        self.trackConfiguration = trackConfiguration
        self.hasAudioTrack = trackConfiguration.hasAudioTrack
        self.sessionqueue = DispatchQueue(label: "AVCameraTrackDataProvider.SessionQueue")
        super.init()
    }
    
    public func startRunning(completionBlcok: @escaping (() -> Void)) {
        guard !isRunning else { return }
        sessionqueue.async {
            do {
                try self.setupSession()
                self.session!.startRunning()
                self.running = true
                completionBlcok()
            } catch {
                self.errorHandler?(.failToStart(error))
            }
        }
    }
    
    public func stopRunning(completionBlcok: @escaping (() -> Void)) {
        guard isRunning else { return }
        sessionqueue.async {
            self.session!.stopRunning()
            self.running = false
            completionBlcok()
        }
    }
}

extension AVCameraTrackDataProvider: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output.connection(with: .audio) == connection {
            trackDataHandler?(.audioSampleBuffer(sampleBuffer))
        } else if output.connection(with: .video) == connection {
            trackDataHandler?(.videoSampleBuffer(sampleBuffer))
        }
    }
    
    fileprivate func getAudioDevice() throws -> AVCaptureDevice {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw Error.captureDeviceUnavailable(.audioDeviceUnavailable)
        }
        return audioDevice
    }
    
    fileprivate func getVideoDevice() throws -> AVCaptureDevice {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw Error.captureDeviceUnavailable(.videoDeviceUnavailable)
        }
        return videoDevice
    }
    
    fileprivate func addDeviceInput(_ captureDevice: AVCaptureDevice) throws {
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        guard session!.canAddInput(deviceInput) else {
            throw Error.failToAddDeviceInput
        }
        session!.addInput(deviceInput)
    }
    
    fileprivate func addAudioDataOutput() {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: sessionqueue)
        session!.addOutput(audioOutput)
    }
    
    fileprivate func addVideoDataOutput() {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionqueue)
        session!.addOutput(videoOutput)
    }
    
    fileprivate func setupAudioDataOutputPipeline() throws {
        let audioDevice = try getAudioDevice()
        try addDeviceInput(audioDevice)
        addAudioDataOutput()
    }
    
    fileprivate func setupVideoDataOutputPipeline() throws {
        let videoDevice = try getVideoDevice()
        try addDeviceInput(videoDevice)
        addVideoDataOutput()
    }
    
    fileprivate func setupSession() throws {
        
        let preset = cameraType.preset
        session = AVCaptureSession()
        
        guard session!.canSetSessionPreset(preset) else {
            throw Error.unsupportedPreset(preset)
        }
        session!.sessionPreset = preset

        if hasAudioTrack {
            try setupAudioDataOutputPipeline()
        }
        
        try setupVideoDataOutputPipeline()
    }
    
    fileprivate func teardownSession() {
        session = nil
    }
}
