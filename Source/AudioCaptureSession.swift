//
//  AudioCaptureSession.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/30.
//

import AVFoundation

// A simple synchronously audio capture session.
internal class AudioCaptureSession: NSObject {
    
    enum Error: Swift.Error {
        case audioDeviceNotAvailable
    }
    
    private var session: AVCaptureSession?
    fileprivate var isRunning: Bool = false
    fileprivate var sampleBufferCallbackQueue: DispatchQueue
    
    public var sampleBufferHandler: ((_ sampleBuffer: CMSampleBuffer) -> Void)?
    
    public init(sampleBufferCallbackQueue: DispatchQueue) {
        self.sampleBufferCallbackQueue = sampleBufferCallbackQueue
        super.init()
    }
    
    public func start() throws {
        guard !isRunning else { return }
        
        session = AVCaptureSession()
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw Error.audioDeviceNotAvailable
        }
        
        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        session!.addInput(audioInput)
        
        let audioOutput = AVCaptureAudioDataOutput()
        audioOutput.setSampleBufferDelegate(self, queue: sampleBufferCallbackQueue)
        session!.addOutput(audioOutput)
        
        session?.startRunning()
        isRunning = true
    }
    
    public func stop() {
        guard isRunning else { return }
        isRunning = false
        session?.stopRunning()
        session = nil
    }
}

extension AudioCaptureSession: AVCaptureAudioDataOutputSampleBufferDelegate {
    
    public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleBufferHandler?(sampleBuffer)
    }
}
