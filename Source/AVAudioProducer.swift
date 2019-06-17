//
//  AVAudioProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/6.
//

import AVFoundation

public final class AVAudioProducer: NSObject, AudioSampleProducer {
    
    fileprivate var queue: DispatchQueue
    fileprivate var running: Bool = false
    
    fileprivate lazy var forwarder: AudioSampleForwarder = {
        let audioForwarder = AudioSampleForwarder(queue: queue, sampleCallback: { [weak self] (sampleBuffer) in
            guard let strongSelf = self, strongSelf.running else { return }
            strongSelf.notifyConsumersWhenMediaSampleReady(.audioSampleBuffer(sampleBuffer))
        })
        return audioForwarder
    }()
    
    public let producerType: ProducerType = .audio
    
    public var sampleConsumers = SampleConsumerContainer()
    
    public var output: AVCaptureAudioDataOutput {
        return forwarder.output
    }
    
    public var isRunning: Bool {
        return running
    }
    
    deinit {
        print("\(self) deinit")
    }
    
    public init(audioQueue: DispatchQueue? = nil) {
        
        if audioQueue == nil {
            self.queue = DispatchQueue(label: "AVAudioProducer.AudioQueue")
        } else {
            self.queue = audioQueue!
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
    
    public func recommendAudioEncodingSettings(forFileType fileType: MovieFileType) -> AudioEncodingSettings? {
        return forwarder.output.recommendedAudioSettingsForAssetWriter(writingTo: fileType.rawType) as? AudioEncodingSettings
    }
}

fileprivate final class AudioSampleForwarder: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    deinit {
        print("\(self) deinit")
    }
    
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
