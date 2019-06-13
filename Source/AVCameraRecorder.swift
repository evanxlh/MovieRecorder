//
//  AVCameraRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/13.
//

import AVFoundation

public final class AVCameraRecorder: Recordable {
    
    fileprivate let internalRecorder: MovieRecorder
    
    fileprivate var cameraSession: AVCameraSession
    fileprivate let videoProducer: AVVideoProducer
    fileprivate var audioProducer: AVAudioProducer? = nil
    
    deinit {
        print("\(self) deinit")
    }
    
    public var isRecording: Bool {
        return internalRecorder.isRecording
    }
    
    public var metadata: [AVMetadataItem]? {
        get { return internalRecorder.metadata }
        set { internalRecorder.metadata = newValue }
    }
    
    public var errorHandler: ErrorHandler? {
        get { return internalRecorder.errorHandler }
        set { internalRecorder.errorHandler = newValue }
    }
    
    /// You can specify the final recorded video orientation. Default is portrait orientation.
    public var recordingOrientation: AVCaptureVideoOrientation = .portrait
    
    public init(session: AVCameraSession, enablesAudio: Bool = false, outputURL: URL) {
        if enablesAudio {
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        cameraSession = session
        videoProducer = AVVideoProducer(videoQueue: nil)
        internalRecorder = MovieRecorder(outputURL: outputURL, audioProducer: audioProducer, videoProducer: videoProducer, movieFileType: .mov)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        guard !isRecording else { return }
        
        cameraSession.configureSession(configurationBlock: { [unowned self] in
            
            try self.cameraSession.addOutput(self.videoProducer.output)
            
            if let videBufferOrietation = self.videoProducer.output.connection(with: .video)?.videoOrientation, let sensor = self.cameraSession.sensor {
                
                let transform = self.cameraSession.getVideoAffineTransform(
                    from: videBufferOrietation,
                    to: self.recordingOrientation,
                    isFrontCamera: sensor.isFront,
                    withAutoMirroring: true
                )
                self.videoProducer.videoTransform = transform
            }
            
            if let producer = self.audioProducer {
                try self.cameraSession.addOutput(producer.output)
            }
            
        }, onSuccees: { [weak self] in
            
            self?.internalRecorder.startRecording(completionBlock: completionBlock)
            
        }, onFailure: { (error) in
            DispatchQueue.main.async {
                self.errorHandler?(.failedToStart(underlyingError: error))
            }
        })
    }
    
    public func stopRecording(completionBlock: @escaping ((URL) -> Void)) {
        guard isRecording else { return }
        
        internalRecorder.stopRecording(completionBlock: completionBlock)
        cameraSession.configureSession(configurationBlock: { [weak self] in
            self?.cameraSession.removeAllOutputs()
        })
    }
}
