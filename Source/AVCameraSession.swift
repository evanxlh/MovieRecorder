//
//  AVCameraSession.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import AVFoundation
import CoreVideo

/**
 A simple wrapper for AVCaptureSession. This class just provides some convenient functions for configuring session,
 but it doesn't do any session configuration automatically by itself.
 
 - Note:
 After creating AVCameraSession, you can configure the inputs and outputs according to your own use case.
 Please do any configuration by invoking `configureSession` function.
 */
public class AVCameraSession: NSObject {

    fileprivate let sessionqueue: DispatchQueue
    fileprivate var running: Bool = false
    
    public typealias Block = () -> Void
    public typealias ConfigurationBlock = () throws -> Void
    public typealias FailureBlock = (Swift.Error) -> Void
    
    public let session: AVCaptureSession
    
    public var isRunning: Bool {
        return running
    }
    
    public override init() {
        self.sessionqueue = DispatchQueue(label: "AVCameraSession.SessionQueue")
        self.session = AVCaptureSession()
        super.init()
    }
    
    public func startRunning(_ completionBlcok: (() -> Void)? = nil) {
        guard !running else { return }
        running = true
        
        sessionqueue.async { [weak self] in
            self?.session.startRunning()
            completionBlcok?()
        }
    }
    
    public func stopRunning(_ completionBlcok: (() -> Void)? = nil) {
        guard running else { return }
        running = false
        
        sessionqueue.async { [weak self] in
            self?.session.stopRunning()
            completionBlcok?()
        }
    }
    
    public func configureSession(configurationBlock: @escaping ConfigurationBlock, onSuccees: Block? = nil, onFailure: FailureBlock? = nil) {
        sessionqueue.async { [weak self] in
            guard let strongSelf = self else { return }
            do {
                strongSelf.session.beginConfiguration()
                try configurationBlock()
                strongSelf.session.commitConfiguration()
                onSuccees?()
            } catch {
                strongSelf.session.commitConfiguration()
                onFailure?(error)
            }
        }
    }
}

//MARK: - AVCaptureSession Configuraiton

public extension AVCameraSession {
    
    /*:
     All the configuration functions in this extension should be invoked in the
     `configurationBlock` of `configureSession` function.
     */
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    @discardableResult
    func addDeviceInput(for device: AVCaptureDevice) throws -> AVCaptureDeviceInput {
        let deviceInput = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(deviceInput) else {
            throw Error.failToAddDeviceInput
        }
        session.addInput(deviceInput)
        return deviceInput
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    @discardableResult
    func addAudioDeviceInput() throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(for: .audio) else {
            throw Error.captureDeviceUnavailable(.audioDeviceUnavailable)
        }
        return try addDeviceInput(for: device)
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    @discardableResult
    func addVideoDeviceInput(for sensor: CameraSensor) throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: sensor.position) else {
            throw Error.captureDeviceUnavailable(.videoDeviceUnavailable)
        }
        let input = try addDeviceInput(for: device)
        
        let preset = sensor.preset
        guard session.canSetSessionPreset(preset) else {
            throw Error.unsupportedPreset(preset, sensor.position)
        }
        session.sessionPreset = preset
        return input
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    func addOutput(_ output: AVCaptureOutput) throws {
        guard session.canAddOutput(output) else {
            throw Error.failToAddOutput
        }
        session.addOutput(output)
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    func addAudioDataOutput(_ output: AVCaptureAudioDataOutput) throws {
        try addOutput(output)
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    func addVideoDataOutput(_ output: AVCaptureVideoDataOutput) throws {
        try addOutput(output)
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    func addMovieFileOutput(_ output: AVCaptureMovieFileOutput) throws {
        try addOutput(output)
    }
    
    /**
     Should be invoked in the `configurationBlock` of `configureSession` function.
     */
    func removeAllInputsAndOutputs() {
        let inputs = session.inputs
        let outputs = session.outputs
        
        inputs.forEach { (input) in
            session.removeInput(input)
        }
        
        outputs.forEach { (output) in
            session.removeOutput(output)
        }
    }
}

//MARK: - Public Data Struct Definition

extension AVCameraSession {
    
    public enum Error: Swift.Error {
        case captureDeviceUnavailable(CaptureDeviceUnavailableReason)
        case unsupportedPreset(AVCaptureSession.Preset, AVCaptureDevice.Position)
        case failToAddDeviceInput
        case failToAddOutput
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
}
