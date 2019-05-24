//
//  Helpers.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/23.
//

import Foundation

internal final class MutexLock {
    
    private var internalLock: pthread_mutex_t
    
    deinit {
        pthread_mutex_destroy(&internalLock)
    }
    
    public init() {
        internalLock = pthread_mutex_t()
        pthread_mutex_init(&internalLock, nil)
    }
    
    public func lock() {
        pthread_mutex_lock(&internalLock)
    }
    
    public func unlock() {
        pthread_mutex_unlock(&internalLock)
    }
}
