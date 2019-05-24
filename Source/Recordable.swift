//
//  Recordable.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/24.
//

import Foundation

public typealias RecorderStartCallback = (_ result: Result<Void, Error>) -> Void
public typealias RecorderStopCallback = (_ result: Result<URL, Error>) -> Void

public protocol Recordable: AnyObject {
    
    var configuration: RecorderConfiguration { get set }
    var state: RecorderState { get }
    
    func start(callback: @escaping RecorderStartCallback)
    func stop(callback: @escaping RecorderStopCallback)
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
