//
//  AVCameraSession.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import AVFoundation
import CoreVideo

public class AVCameraSession: NSObject {
    
    fileprivate var session: AVCaptureSession
    fileprivate let sessionqueue: DispatchQueue
    fileprivate var running: Bool = false
    fileprivate var lock = MutexLock()
    
    fileprivate var cameraSensor: CameraSensor
    fileprivate var runningMode: RunningMode
    
    public var isRunning: Bool {
        lock.lock()
        defer { lock.unlock() }
        return running
    }
    
    public init(cameraSensor: CameraSensor, runningMode: RunningMode) {
        self.cameraSensor = cameraSensor
        self.sessionqueue = DispatchQueue(label: "AVCameraSession.SessionQueue", qos: .userInteractive)
        self.runningMode = runningMode
        self.session = AVCaptureSession()
        super.init()
    }
    
    public func startRunning(completionBlcok: @escaping (() -> Void)) {
        guard !isRunning else {
            completionBlcok()
            return
        }
        
        sessionqueue.async {
            do {
                try self.setupSession()
                self.session.startRunning()
                self.running = true
                completionBlcok()
            } catch {
                
            }
        }
    }
    
    public func stopRunning(completionBlcok: @escaping (() -> Void)) {
        guard isRunning else {
            completionBlcok()
            return
        }
        
        sessionqueue.async {
            self.session.stopRunning()
            self.running = false
            completionBlcok()
        }
    }
    
    public func switchRunningMode(_ newRunningMode: RunningMode, completionBlcok: @escaping (() -> Void)) {
        
    }
    
    public func switchCameraSensor(_ newCameraSensor: CameraSensor, completionBlcok: @escaping (() -> Void)) {
        
    }
}

extension AVCameraSession: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output.connection(with: .audio) == connection {
            
        } else if output.connection(with: .video) == connection {
            
        }
    }
}

//MARK: - AVCaptureSession Setup/Tear Down

fileprivate extension AVCameraSession {
    
    func getAudioDevice() throws -> AVCaptureDevice {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw Error.captureDeviceUnavailable(.audioDeviceUnavailable)
        }
        return audioDevice
    }
    
    func getVideoDevice() throws -> AVCaptureDevice {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw Error.captureDeviceUnavailable(.videoDeviceUnavailable)
        }
        return videoDevice
    }
    
    func addDeviceInput(_ captureDevice: AVCaptureDevice) throws {
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        guard session.canAddInput(deviceInput) else {
            throw Error.failToAddDeviceInput
        }
        session.addInput(deviceInput)
    }
    
    func addAudioDataOutput() {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: sessionqueue)
        session.addOutput(audioOutput)
    }
    
    func addVideoDataOutput() {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: sessionqueue)
        session.addOutput(videoOutput)
    }
    
    func setupAudioDataOutputPipeline() throws {
        let audioDevice = try getAudioDevice()
        try addDeviceInput(audioDevice)
        addAudioDataOutput()
    }
    
    func setupVideoDataOutputPipeline() throws {
        let videoDevice = try getVideoDevice()
        try addDeviceInput(videoDevice)
        addVideoDataOutput()
    }
    
    func setupSession() throws {
        
        session.beginConfiguration()
        switch runningMode {
        case let .audio(configuration):
            break
        case let .video(configuration):
            break
        case let .audioVideo(AudioConfiguration, videoConfiguration):
            break
        }
        
        
//        if enablesAudio {
//            try setupAudioDataOutputPipeline()
//        }
        
        try setupVideoDataOutputPipeline()
        
        let preset = cameraSensor.preset
        
        guard session.canSetSessionPreset(preset) else {
            throw Error.unsupportedPreset(preset)
        }
        session.sessionPreset = preset
        
        session.commitConfiguration()
    }
}

fileprivate extension AVCameraSession {
    
    func getSourceType(_ isAudioEnabled: Bool) -> SampleSourceType {
        if isAudioEnabled {
            return .audioVideo
        }
        return .video
    }
    
    func updateSourceType(_ newType: SampleSourceType) {
        guard !isRunning else { return }
    }
    
    func updateCameraSensor(_ newCameraSensor: CameraSensor) {
        guard cameraSensor != newCameraSensor else { return }
        guard !isRunning else { return }
    }
    
}

//MARK: - Public Data Struct Definition

extension AVCameraSession {
    
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
    
    public enum CameraSensor: Equatable {
        case back(AVCaptureSession.Preset)
        case front(AVCaptureSession.Preset)
        
        public var preset: AVCaptureSession.Preset {
            switch self {
            case .back(let preset), .front(let preset):
                return preset
            }
        }
        
        public var position: AVCaptureDevice.Position {
            switch self {
            case .back:
                return .back
            case .front:
                return .front
            }
        }
        
        public static func == (lhs: CameraSensor, rhs: CameraSensor) -> Bool {
            switch (lhs, rhs) {
            case (.back(let preset1), .back(let preset2)):
                return preset1 == preset2
            case (.front(let preset1), .front(let preset2)):
                return preset1 == preset2
            default:
                return false
            }
        }
        
        public static func != (lhs: CameraSensor, rhs: CameraSensor) -> Bool {
            return !(lhs == rhs)
        }
    }
    
    public struct AudioConfiguration: Equatable {
        public static func == (lhs: AudioConfiguration, rhs: AudioConfiguration) -> Bool {
            return true
        }
        
        public static func != (lhs: AudioConfiguration, rhs: AudioConfiguration) -> Bool {
            return !(lhs == rhs)
        }
    }
    
    public struct VideoConfiguration: Equatable {
        public var preferredFramerate: Int
        public var pixelFormat: OSStatus
        
        public static func == (lhs: VideoConfiguration, rhs: VideoConfiguration) -> Bool {
            return (lhs.preferredFramerate == rhs.preferredFramerate) && (lhs.pixelFormat == rhs.pixelFormat)
        }
        
        public static func != (lhs: VideoConfiguration, rhs: VideoConfiguration) -> Bool {
            return !(lhs == rhs)
        }
    }
    
    public enum RunningMode {
        case audio(AudioConfiguration)
        case video(VideoConfiguration)
        case audioVideo(AudioConfiguration, VideoConfiguration)
    }
}
