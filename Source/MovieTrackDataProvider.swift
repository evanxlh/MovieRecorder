//
//  MovieTrackDataProvider.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/30.
//

import CoreMedia
import CoreVideo

/// The media track type which the movie can have in this movie recorder.
public enum MovieTrackType: Int {
    case audio
    case video
}

public struct AudioTrackConfiguration {
    public init() { }
}

public struct VideoTrackConfiguration {
    public var framerate: Int
    public var resolution: CGSize
    
    public init(framerate: Int, resolution: CGSize) {
        self.framerate = framerate
        self.resolution = resolution
    }
}

/// The configuration for the movie tracks.
public enum MovieTrackConfiguration {
    
    /// The movie only has one video track.
    case video(VideoTrackConfiguration)
    
    /// The movie has one audio track, and one video track.
    case audioAndVideo(AudioTrackConfiguration, VideoTrackConfiguration)
    
    public var hasAudioTrack: Bool {
        return audio != nil
    }
    
    public var audio: AudioTrackConfiguration? {
        switch self {
        case .audioAndVideo(let configuration, _):
            return configuration
        default:
            return nil
        }
    }
    
    public var video: VideoTrackConfiguration {
        switch self {
        case .video(let configuration):
            return configuration
        case .audioAndVideo(_, let configuration):
            return configuration
        }
    }
    
    public var videoSize: CGSize {
        return video.resolution
    }
    
    public var videoFramerate: Int {
        return video.framerate
    }
}

public enum MovieTrackData {
    case audioSampleBuffer(CMSampleBuffer)
    case videoSampleBuffer(CMSampleBuffer)
    case videoPixelBuffer(CVPixelBuffer, CMTime)
    
    public var trackType: MovieTrackType {
        switch self {
        case .audioSampleBuffer:
            return .audio
        case .videoPixelBuffer, .videoSampleBuffer:
            return .video
        }
    }
    
    public var isAudioTrack: Bool {
        return trackType == .audio
    }
    
    public var isVideoTrack: Bool {
        return trackType == .video
    }
}

public enum MovieTrackDataProviderError: Swift.Error {
    case failToStart(Error)
    case failToOutputTrackData(Error)
}

public protocol MovieTrackDataProvider: class {
    
    /// Inidcates track data provider is running or not.
    var isRunning: Bool { get }
    
    /// Specifying which tracks the movie has.
    var trackConfiguration: MovieTrackConfiguration { get }
    
    /// Handle errors, when any error occurs, this errorHandler will be invoked.
    var errorHandler: ((_ error: MovieTrackDataProviderError) -> Void)? { get set }
    
    /// Handle outputting media track data. When provider produce one track data,
    /// `trackDataHandler` will be invoked one time.
    var trackDataHandler: ((_ trackData: MovieTrackData) -> Void)? { get set }
    
    /// Start provider, let it produce track data periodicity.
    func startRunning(completionBlcok: @escaping (() -> Void))
    
    /// Stop provider, let it not produce track data.
    func stopRunning(completionBlcok: @escaping (() -> Void))
}

public extension MovieTrackDataProvider {
    
    var hasAudioTrack: Bool {
        return trackConfiguration.hasAudioTrack
    }
    
    var audioTrackConfiguration: AudioTrackConfiguration? {
        return trackConfiguration.audio
    }
    
    var videoTrackConfiguration: VideoTrackConfiguration {
        return trackConfiguration.video
    }
    
}
