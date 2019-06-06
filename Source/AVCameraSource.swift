//
//  AVCameraSource.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/6.
//

import AVFoundation

public class AVCameraSource: NSObject, SampleSource {
    
    fileprivate var audioForwarder: AudioSampleForwarder?
    fileprivate var videoForwarder: VideoSampleForwarder?
    fileprivate var workingQueue: DispatchQueue
    fileprivate var running: Bool = false
    
    enum Error: Swift.Error {
        case failToAddSampleBufferOutput
    }
    
    public var sourceType: SampleSourceType
    
    public var recommendedEncodingSettings: MediaSampleRecommendedEncodingSettings = .audioVideo([:], [:])
    
    public var sampleConsumers = SampleConsumerContainer()
    
    public var isRunning: Bool {
        return running
    }
    
    public init(type: SampleSourceType) {
        sourceType = type
        workingQueue = DispatchQueue(label: "AVCameraSource.WorkingQueue", qos: .userInteractive)
        super.init()
        setupSampleForwarder()
    }
    
    public func startRunning() throws {
        guard !running else { return }
        running = true
    }
    
    public func stopRunning() {
        guard running else { return }
        running = false
        
    }
    
    public func bindCaptureSession(_ session: AVCaptureSession) throws {
        switch sourceType {
        case .audio:
            try addSampleOutput(audioForwarder!.output, session: session)
        case .video:
            try addSampleOutput(videoForwarder!.output, session: session)
        case .audioVideo:
            try addSampleOutput(audioForwarder!.output, session: session)
            try addSampleOutput(videoForwarder!.output, session: session)
        }
    }
    
    public func unbindCaptureSession(_ session: AVCaptureSession) {
        if let forwarder = audioForwarder {
            session.removeOutput(forwarder.output)
        }
        if let forwarder = videoForwarder {
            session.removeOutput(forwarder.output)
        }
    }
}

fileprivate extension AVCameraSource {
    
    func setupSampleForwarder() {
        switch sourceType {
        case .audio:
            setupAudioSampleForwarder()
        case .video:
            setupVideoSampleForwarder()
        case .audioVideo:
            setupAudioSampleForwarder()
            setupVideoSampleForwarder()
        }
    }
    
    func setupAudioSampleForwarder() {
        audioForwarder = AudioSampleForwarder(queue: workingQueue, sampleCallback: { [weak self] (sampleBuffer) in
            guard let strongSelf = self, strongSelf.running else { return }
            strongSelf.notifyConsumersWhenMediaSampleReady(.audioSampleBuffer(sampleBuffer))
        })
    }
    
    func setupVideoSampleForwarder() {
        videoForwarder = VideoSampleForwarder(queue: workingQueue, sampleCallback: { [weak self] (sampleBuffer) in
            guard let strongSelf = self, strongSelf.running else { return }
            strongSelf.notifyConsumersWhenMediaSampleReady(.videoSampleBuffer(sampleBuffer))
        })
    }
    
    func addSampleOutput(_ output: AVCaptureOutput, session: AVCaptureSession) throws {
        guard session.canAddOutput(output) else {
            throw Error.failToAddSampleBufferOutput
        }
        session.addOutput(output)
    }
}

fileprivate class AudioSampleForwarder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    let output: AVCaptureAudioDataOutput
    let sampleCallback: (CMSampleBuffer) -> Void
    
    init(queue: DispatchQueue, sampleCallback: @escaping ((CMSampleBuffer) -> Void)) {
        self.output = AVCaptureAudioDataOutput()
        self.sampleCallback = sampleCallback
        super.init()
        self.output.setSampleBufferDelegate(self, queue: queue)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleCallback(sampleBuffer)
    }
}

fileprivate class VideoSampleForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    let output: AVCaptureVideoDataOutput
    let sampleCallback: (CMSampleBuffer) -> Void
    
    init(queue: DispatchQueue, sampleCallback: @escaping ((CMSampleBuffer) -> Void)) {
        self.output = AVCaptureVideoDataOutput()
        self.sampleCallback = sampleCallback
        super.init()
        self.output.setSampleBufferDelegate(self, queue: queue)
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        sampleCallback(sampleBuffer)
    }
}
