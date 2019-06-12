//
//  UIViewRecorder.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

import Foundation
import AVFoundation

public final class UIViewRecorder: Recordable {
    
    fileprivate var audioProducer: AVAudioProducer? = nil
    fileprivate let videoProducer: MTKViewProducer
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
    
    public init(view: UIView, enablesAudio: Bool = false, outputURL: URL) {
        if enablesAudio {
            audioProducer = AVAudioProducer(audioQueue: nil)
        }
        videoProducer = MTKViewProducer()
        internalRecorder = MovieRecorder(outputURL: outputURL, audioProducer: audioProducer, videoProducer: videoProducer, movieFileType: .mov)
    }
    
    public func startRecording(completionBlock: @escaping (() -> Void)) {
        internalRecorder.startRecording(completionBlock: completionBlock)
    }
    
    public func stopRecording(completionBlock: @escaping ((URL) -> Void)) {
        internalRecorder.stopRecording(completionBlock: completionBlock)
    }
}
