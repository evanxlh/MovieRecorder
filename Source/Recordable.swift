//
//  Recordable.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

import AVFoundation

public typealias ErrorHandler = (_ error: MRError) -> Void

public enum MRError: Error {
    
    /// Fail to start recorder
    case failedToStart(underlyingError: Error)
    
    /// Fail to stop recorder
    case failedToStop(underlyingError: Error)
    
    /// Fail to write more audio/video buffer data when recording.
    case failedToRecord(underlyingError: Error)
}

public struct RecorderConfiguration {
    public var outputURL: URL
    public var videoFramerate: Int
    public var videoResulution: CGSize
    public var enablesAudioTrack: Bool
    public var fileType: MovieFileType
    
    /**
     Custom recorder configuration.
     
     - Parameters:
         - outputURL: The movie saved file url.
         - videoFramerate: The video framerate of final recorded movie, it can not exceed the framerate of source video producer.
         - videoResulution: The final video resolution of your recorded movie.
         - enablesAudioTrack: Audio track is enabled by default.
         - fileType: The output movie file container type, and determins the file extension.
     */
    public init(outputURL: URL, videoFramerate: Int = 30, videoResulution: CGSize, enablesAudioTrack: Bool = true, fileType: MovieFileType = .mov) {
        self.outputURL = outputURL
        self.videoFramerate = videoFramerate
        self.videoResulution = videoResulution
        self.enablesAudioTrack = enablesAudioTrack
        self.fileType = fileType
    }
}

public protocol Recordable {
    
    /// Indicates recorder is recording or not.
    var isRecording: Bool { get }
    
    /// You can specify some metadata for the recording movie before starting recorder.
    var metadata: [AVMetadataItem]? { get set }
    
    /// Error handler for recorder. When error occurs, this handler will be invoked on the main thread.
    var errorHandler: ErrorHandler? { get set }
    
    /**
     Start recording. When successfully, callback block will be invoked on the main thread.
     If failed, `errorHandler` will be invoked on the main thread.
     */
    func startRecording(completionBlock: @escaping (() -> Void))
    
    /**
     Stop recording. When successfully, callback block with the movie url will be invoked on the main thread.
     If failed, `errorHandler` will be invoked on the main thread.
     */
    func stopRecording(completionBlock: @escaping ((URL) -> Void))
}

extension Recordable {
    
    /**
     Create a common metal data items.
     
     An example:
     
     ```
     var metadata = [AVMutableMetadataItem]()
     
     var item = AVMutableMetadataItem()
     item.key = AVMetadataKey.commonKeyCreator as NSCopying & NSObjectProtocol
     item.keySpace = AVMetadataKeySpace.common
     item.value = "Movie Recorder" as NSCopying & NSObjectProtocol
     metadata.append(item)
     
     item = AVMutableMetadataItem()
     item.key = AVMetadataKey.commonKeyCopyrights as NSCopying & NSObjectProtocol
     item.keySpace = AVMetadataKeySpace.common
     item.value = "Movie Recorder, 2019" as NSCopying & NSObjectProtocol
     metadata.append(item)
     ```
     */
    public static func commonMetaldata(withCreator creator: String, copyrights: String) -> [AVMetadataItem] {
        var metadata = [AVMutableMetadataItem]()
        
        var item = AVMutableMetadataItem()
        item.key = AVMetadataKey.commonKeyCreator as NSCopying & NSObjectProtocol
        item.keySpace = AVMetadataKeySpace.common
        item.value = creator as NSCopying & NSObjectProtocol
        metadata.append(item)
        
        item = AVMutableMetadataItem()
        item.key = AVMetadataKey.commonKeyCopyrights as NSCopying & NSObjectProtocol
        item.keySpace = AVMetadataKeySpace.common
        item.value = copyrights as NSCopying & NSObjectProtocol
        metadata.append(item)
        
        return metadata
    }
}
