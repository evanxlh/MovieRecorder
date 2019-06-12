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
    
    public init(view: SCNView, enablesAudio: Bool = false, outputURL: URL) {
        if enablesAudio {
            audioSession = AVCameraSession()
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        videoProducer = SCNViewProducer(scnView: view, videoSize: view.bounds.size.scaleBy(UIScreen.main.nativeScale), videoFramerate: 60)
        internalRecorder = MovieRecorder(outputURL: outputURL, audioProducer: audioProducer, videoProducer: videoProducer, movieFileType: .mov)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        
        if let session = audioSession, let producer = audioProducer {
            
            session.configureSession(configurationBlock: {
                try session.addAudioDeviceInput()
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
