//
//  MTLTextureRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

#if !targetEnvironment(simulator)
import MetalKit
import AVFoundation

public final class MTLTextureRecorder: Recordable {
    
    fileprivate var audioSession: AVCameraSession? = nil
    fileprivate var audioProducer: AVAudioProducer? = nil
    
    fileprivate let videoProducer: MTLTextureProducer
    fileprivate let internalRecorder: MovieRecorder
    
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
    
    public init(device: MTLDevice, configuration: RecorderConfiguration) {
        if configuration.enablesAudioTrack {
            audioSession = AVCameraSession()
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        videoProducer = MTLTextureProducer(device: device,
                                           textureSize: configuration.videoResulution,
                                           framerate: configuration.videoFramerate)
        internalRecorder = MovieRecorder(outputURL: configuration.outputURL,
                                         audioProducer: audioProducer,
                                         videoProducer: videoProducer,
                                         movieFileType: .mov)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        
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
    
    public func recordTexture(_ texture: MTLTexture, commandBuffer: MTLCommandBuffer, atTime time: TimeInterval) {
        videoProducer.renderTexture(texture, commandBuffer: commandBuffer, atTime: time)
    }
}
#endif
