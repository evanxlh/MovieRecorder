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
        case idle
        case starting
        case writing
        case finishingPhase1
        case finishingPhase2
        case finished
        case failed
        
        var description: String {
            return ["starting", "writing", "finishingPhase1", "finishingPhase2", "finished", "failed"][rawValue]
        }
        
        func canTransitionToState(_ newState: State) -> Bool {
            return transitableStates.contains(newState)
        }
        
        //MARK: - Private
        
        private var transitableStates: [State] {
            switch self {
            case .idle:
                return idleTransitableStates
            case .starting:
                return startingTransitableStates
            case .writing:
                return writingTransitableStates
            case .finishingPhase1:
                return finishingPhase1TransitableStates
            case .finishingPhase2:
                return finishingPhase2TransitableStates
            case .finished:
                return finishedTransitableStates
            case .failed:
                return failedTransitableStates
            }
        }
        
        /// Idle start can transition to itself, just means keeping the idle state.
        private var idleTransitableStates: [State] {
            return [.idle, .starting]
        }
        
        private var startingTransitableStates: [State] {
            return [.writing, .failed]
        }
        
        private var writingTransitableStates: [State] {
            return [.finishingPhase1, .failed]
        }
        
        private var finishingPhase1TransitableStates: [State] {
            return [.finishingPhase2]
        }
        
        private var finishingPhase2TransitableStates: [State] {
            return [.finished, .failed]
        }
        
        private var finishedTransitableStates: [State] {
            return [.idle, .starting]
        }
        
        private var failedTransitableStates: [State] {
            return [.idle, .starting]
        }
    }
    
}
