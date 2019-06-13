//
//  MTLTextureRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

#if canImport(Metal)
import MetalKit
import AVFoundation

public final class MTLTextureRecorder: Recordable {
    
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
    
    public init(device: MTLDevice, textureSize: CGSize, enablesAudio: Bool = false, outputURL: URL) {
        if enablesAudio {
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        videoProducer = MTLTextureProducer(device: device, textureSize: textureSize)
        internalRecorder = MovieRecorder(outputURL: outputURL, audioProducer: audioProducer, videoProducer: videoProducer, movieFileType: .mov)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        internalRecorder.startRecording(completionBlock: completionBlock)
    }
    
    public func stopRecording(completionBlock: @escaping ((URL) -> Void)) {
        internalRecorder.stopRecording(completionBlock: completionBlock)
    }
}
#endif
