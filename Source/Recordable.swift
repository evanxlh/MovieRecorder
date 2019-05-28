//
//  Recordable.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import Foundation

public typealias RecorderErrorHandler = (_ error: RecorderError) -> Void

public enum RecorderError: Error {
    
    /// Fail to start recorder
    case failedToStart(underlyingError: Error)
    
    /// Fail to stop recorder
    case failedToStop(underlyingError: Error)
    
    /// Fail to write more audio/video buffer data when recording.
    case failedToRecord(underlyingError: Error)
}

public struct RecorderConfiguration {
    public var videoSize: CGSize
    public var quality: Quality
    public var outputURL: URL
    public var isAudioActive: Bool
    
    public init(outputURL: URL, videoSize: CGSize, quality: Quality = .medium, isAudioActive: Bool = true) {
        self.outputURL = outputURL
        self.videoSize = videoSize
        self.quality = quality
        self.isAudioActive = isAudioActive
    }
}

public protocol Recordable: AnyObject {
    
    /// Handle recorder possible errors.
    var errorHandler: RecorderErrorHandler? { get set }
    
    /// Recorder configuration for specifying video resolution, quality, and so on.
    var configuration: RecorderConfiguration { get set }
    
    /// Get current recorder state, it's thread safe.
    var state: RecorderState { get }
    
    /**
     Start recording. When successfully, callback block will be executed on the main thread.
     If failed, `errorHandler` will be executed on the main thread.
     */
    func start(callback: @escaping (() -> Void))
    
    /**
     Stop recording. When successfully, callback block with the movie url will be executed on the main thread.
     If failed, `errorHandler` will be executed on the main thread.
     */
    func stop(callback: @escaping ((URL) -> Void))
}

extension Recordable {
    
    /// Check recorder is recording now or not, means recorder is started successfully.
    /// In this state, recorder can write audio/video buffer data to movie file.
    public var isRecording: Bool {
        return state == .recording
    }
}


public enum RecorderState: Int, CustomStringConvertible {
    case starting
    case recording
    case stopping
    case stopped
    case failed
    
    public var description: String {
        return ["starting", "recording", "stopping", "stopped", "failed"][rawValue]
    }
    
    func canTransitionToState(_ newState: RecorderState) -> Bool {
        return transitableStates.contains(newState)
    }
    
    //MARK: - Private
    
    /// The states to which current state can be transitioned.
    private var transitableStates: [RecorderState] {
        switch self {
        case .starting:
            return startingTransitableStates
        case .recording:
            return recordingTransitableStates
        case .stopping:
            return stoppingTransitableStates
        case .stopped:
            return stoppedTransitableStates
        case .failed:
            return failedTransitableStates
        }
    }
    
    private var startingTransitableStates: [RecorderState] {
        return [.recording, .failed]
    }
    
    private var recordingTransitableStates: [RecorderState] {
        return [.stopping, .failed]
    }
    
    private var stoppingTransitableStates: [RecorderState] {
        return [.stopped, .failed]
    }
    
    private var stoppedTransitableStates: [RecorderState] {
        return [.starting]
    }
    
    private var failedTransitableStates: [RecorderState] {
        return [.starting]
    }
}
