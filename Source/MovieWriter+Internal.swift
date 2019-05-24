//
//  MovieWriter+Internal.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import Foundation

internal extension MovieWriter {
    
    enum Track: Int {
        case audio
        case video
    }
    
    enum State: Int, CustomStringConvertible {
        case starting
        case writing
        case stoppingPhase1
        case stoppingPhase2
        case stopped
        case cancelling
        case cancelled
        case failed
        
        var description: String {
            return ["starting", "writing", "stoppingPhase1", "stoppingPhase2", "stopped", "cancelling", "cancelled", "failed"][rawValue]
        }
        
        func canTransitionToState(_ newState: State) -> Bool {
            return transitableStates.contains(newState)
        }
        
        //MARK: - Private
        
        private var transitableStates: [State] {
            switch self {
            case .starting:
                return startingTransitableStates
            case .writing:
                return writingTransitableStates
            case .stoppingPhase1:
                return stoppingPhase1TransitableStates
            case .stoppingPhase2:
                return stoppingPhase2TransitableStates
            case .stopped:
                return stoppedTransitableStates
            case .cancelling:
                return cancellingTransitableStates
            case .cancelled:
                return cancelledTransitableStates
            case .failed:
                return failedTransitableStates
            }
        }
        
        private var startingTransitableStates: [State] {
            return [.writing, .failed]
        }
        
        private var writingTransitableStates: [State] {
            return [.cancelling, .stoppingPhase1, .failed]
        }
        
        private var stoppingPhase1TransitableStates: [State] {
            return [.stoppingPhase2]
        }
        
        private var stoppingPhase2TransitableStates: [State] {
            return [.stopped, .failed]
        }
        
        private var stoppedTransitableStates: [State] {
            return [.starting]
        }
        
        private var cancellingTransitableStates: [State] {
            return [.cancelled]
        }
        
        private var cancelledTransitableStates: [State] {
            return [.stopped]
        }
        
        private var failedTransitableStates: [State] {
            return [.stopped]
        }
    }
    
}
