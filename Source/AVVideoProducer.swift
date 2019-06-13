//
//  AVVideoProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

import AVFoundation

public final class AVVideoProducer: NSObject, MediaSampleProducer {
    
    fileprivate var queue: DispatchQueue
    fileprivate var running: Bool = false
    
    fileprivate lazy var forwarder: VideoSampleForwarder = {
        let videoForwarder = VideoSampleForwarder(queue: queue, sampleCallback: { [weak self] (sampleBuffer) in
            guard let strongSelf = self, strongSelf.running else { return }
            strongSelf.notifyConsumersWhenMediaSampleReady(.videoSampleBuffer(sampleBuffer))
        })
        return videoForwarder
    }()
    
    enum Error: Swift.Error {
        case failToAddSampleBufferOutput
    }
    
    public let producerType: ProducerType = .video
    
    public var sampleConsumers = SampleConsumerContainer()
    
    public var output: AVCaptureVideoDataOutput {
        return forwarder.output
    }
    
    public var isRunning: Bool {
        return running
    }
    
    public var videoTransform: CGAffineTransform? = nil
    
    public init(videoQueue: DispatchQueue? = nil) {
        if videoQueue == nil {
            let highQueue = DispatchQueue.global(qos: .userInteractive)
            queue = DispatchQueue(label: "AVVideoProducer.VideoQueue", attributes: [], target: highQueue)
        } else {
            queue = videoQueue!
        }
        
        super.init()
    }
    
    public func startRunning() throws {
        guard !running else { return }
        running = true
    }
    
    public func stopRunning() {
        guard running else { return }
        running = false
        
    }
    
    public func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String : Any]? {
        return forwarder.output.recommendedVideoSettingsForAssetWriter(writingTo: fileType.rawType)
    }
}

fileprivate final class VideoSampleForwarder: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
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
