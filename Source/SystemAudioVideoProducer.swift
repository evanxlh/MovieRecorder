//
//  SystemAudioVideoProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import AVFoundation

extension SystemAudioVideoProducer {
    
    public enum Mode: Int {
        case audio
        case video
        case audioAndVideo
    }
    
    public enum CCError: Error {
        case captureDeviceUnavailable(CaptureDeviceUnavailableReason)
        case failToAddDeviceInput
        case internalError(NSError)
        
        public enum CaptureDeviceUnavailableReason: Int {
            case audioDeviceUnavailable
            case videoDeviceUnavailable
        }
    }
}

public class SystemAudioVideoProducer: NSObject, BufferProducer {
    
    public var delegate: BufferProducerDelegate?
    
    private var session: AVCaptureSession
    private let queue: DispatchQueue
    
    public private(set) var isCapturing: Bool = false
    
    public init(mode: Mode) throws {
        session = AVCaptureSession()
        session.sessionPreset = .hd4K3840x2160
        queue = DispatchQueue(label: "queue.CameraCaptureSession")
        super.init()
        try setupSession(mode)
    }
    
    public func start() {
        guard !isCapturing else { return }
        session.startRunning()
    }
    
    public func stop() {
        guard isCapturing else { return }
        session.stopRunning()
    }
}

extension SystemAudioVideoProducer: AVCaptureAudioDataOutputSampleBufferDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if output.connection(with: .audio) == connection {
            delegate?.bufferProducer(self, didOutput: .audioSampleBuffer(sampleBuffer))
        } else if output.connection(with: .video) == connection {
            delegate?.bufferProducer(self, didOutput: .videoSampleBuffer(sampleBuffer))
        }
    }
    
    fileprivate func getAudioDevice() throws -> AVCaptureDevice {
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw CCError.captureDeviceUnavailable(.audioDeviceUnavailable)
        }
        return audioDevice
    }
    
    fileprivate func getVideoDevice() throws -> AVCaptureDevice {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            throw CCError.captureDeviceUnavailable(.videoDeviceUnavailable)
        }
        return videoDevice
    }
    
    fileprivate func addDeviceInput(_ captureDevice: AVCaptureDevice) throws {
        let deviceInput = try AVCaptureDeviceInput(device: captureDevice)
        guard session.canAddInput(deviceInput) else {
            throw CCError.failToAddDeviceInput
        }
        session.addInput(deviceInput)
    }
    
    fileprivate func addAudioDataOutput() {
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(audioOutput)
    }
    
    fileprivate func addVideoDataOutput() {
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        session.addOutput(videoOutput)
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
    
    fileprivate func setupSession(_ mode: Mode) throws {
        switch mode {
        case .audio:
            try setupAudioDataOutputPipeline()
        case .video:
            try setupVideoDataOutputPipeline()
        case .audioAndVideo:
            try setupAudioDataOutputPipeline()
            try setupVideoDataOutputPipeline()
        }
    }
}
