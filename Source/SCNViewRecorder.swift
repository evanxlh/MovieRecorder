//
//  SCNViewRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

import SceneKit
import AVFoundation

public final class SCNViewRecorder: Recordable {
    
    fileprivate let videoProducer: SCNViewProducer
    fileprivate let internalRecorder: MovieRecorder
    
    fileprivate var audioSession: AVCameraSession? = nil
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
    
    public init(view: SCNView, configuration: RecorderConfiguration) {
        if configuration.enablesAudioTrack {
            audioSession = AVCameraSession()
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        
        videoProducer = SCNViewProducer(scnView: view,
                                        videoSize: configuration.videoResulution,
                                        videoFramerate: configuration.videoFramerate)
        internalRecorder = MovieRecorder(outputURL: configuration.outputURL,
                                         audioProducer: audioProducer,
                                         videoProducer: videoProducer,
                                         movieFileType: configuration.fileType)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        guard !isRecording else { return }
        
        if let session = audioSession, let producer = audioProducer {
            
            session.configureSession(configurationBlock: {
                try session.useAudioDeviceInput()
                try session.addOutput(producer.output)
            }, onSuccees: {
                session.startRunning { [weak self] in
                    self?.internalRecorder.startRecording(completionBlock: completionBlock)
                }
            }, onFailure: { (error) in
                DispatchQueue.main.async {
                    self.errorHandler?(.failedToStart(underlyingError: error))
                }
            })
        } else {
            internalRecorder.startRecording(completionBlock: completionBlock)
        }
    }
    
    public func stopRecording(completionBlock: @escaping ((URL) -> Void)) {
        guard isRecording else { return }
        
        if let session = audioSession, let producer = audioProducer {
            internalRecorder.stopRecording(completionBlock: completionBlock)
            producer.stopRunning()
            session.stopRunning()
            session.configureSession(configurationBlock: {
                session.removeAllInputsAndOutputs()
            })
        } else {
            internalRecorder.stopRecording(completionBlock: completionBlock)
        }
    }
}
