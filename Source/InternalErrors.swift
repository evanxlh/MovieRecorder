//
//  AVUnderlyingErrors.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/5/28.
//

import CoreVideo

internal extension Int32 {
    
     var fourCharCodeString: String {
        let utf16 = [
            UInt16((self >> 24) & 0xFF),
            UInt16((self >> 16) & 0xFF),
            UInt16((self >> 8) & 0xFF),
            UInt16((self & 0xFF))
        ]
        return String(utf16CodeUnits: utf16, count: 4)
    }
}

/**
 The `CVReturn` error code wrapper.
 
 You can find the detail meaning of `CVReturn` from:
 [Apple Error Codes Lookup](https://www.osstatus.com).
 */
internal struct CVReturnValue: CustomStringConvertible, Equatable {
    let value: CVReturn
    
    init(_ value: CVReturn) {
        self.value = value
    }
    
    var fourCharCodeString: String {
        return value.fourCharCodeString
    }
    
    var description: String {
        switch value {
        case kCVReturnInvalidArgument:
            return "\(value): At least one of the arguments passed in is not valid. Either out of range or the wrong type."
        case kCVReturnAllocationFailed:
            return "\(value): The allocation for a buffer or buffer pool failed. Most likely because of lack of resources."
        case kCVReturnInvalidPixelFormat:
            return "\(value): The requested pixelformat is not supported for the CVBuffer type."
        case kCVReturnInvalidSize:
            return "\(value): The requested size (most likely too big) is not supported for the CVBuffer type."
        case kCVReturnInvalidPixelBufferAttributes:
            return "\(value): A CVBuffer cannot be created with the given attributes."
        case kCVReturnPixelBufferNotOpenGLCompatible:
            return "\(value): The Buffer cannot be used with OpenGL as either its size, pixelformat or attributes are not supported by OpenGL."
        case kCVReturnPixelBufferNotMetalCompatible:
            return "\(value): The Buffer cannot be used with Metal as either its size, pixelformat or attributes are not supported by Metal."
        case kCVReturnWouldExceedAllocationThreshold:
            return "\(value): The allocation request failed because it would have exceeded a specified allocation threshold (see kCVPixelBufferPoolAllocationThresholdKey)."
        case kCVReturnPoolAllocationFailed:
            return "\(value): The allocation for the buffer pool failed. Most likely because of lack of resources. Check if your parameters are in range."
        case kCVReturnInvalidPoolAttributes:
            return "\(value): A CVBufferPool cannot be created with the given attributes."
        case kCVReturnRetry:
            return  "\(value): A scan hasn't completely traversed the CVBufferPool due to a concurrent operation. The client can retry the scan."
        default:
            return "\(value): \(fourCharCodeString))"
        }
    }
    
    static func == (lhs: CVReturnValue, rhs: CVReturnValue) -> Bool {
        return lhs.value == rhs.value
    }
    
    static func != (lhs: CVReturnValue, rhs: CVReturnValue) -> Bool {
        return lhs.value != rhs.value
    }
}

/**
 The `OSStatus` error code wrapper.
 
 You can find the detail meaning of `OSStatus` from:
 [Apple Error Codes Lookup](https://www.osstatus.com).
 */
internal struct OSStatusValue: CustomStringConvertible, Equatable {
    
    let value: OSStatus
    
    var fourCharCodeString: String {
        return value.fourCharCodeString
    }
    
    var description: String {
        switch value {
        default:
            return "\(value): \(fourCharCodeString))"
        }
    }
    
    init(_ value: OSStatus) {
        self.value = value
    }
    
    static func == (lhs: OSStatusValue, rhs: OSStatusValue) -> Bool {
        return lhs.value == rhs.value
    }
    
    static func != (lhs: OSStatusValue, rhs: OSStatusValue) -> Bool {
        return lhs.value != rhs.value
    }
}

internal enum CoreVideoError: LocalizedError {
    case failure(CVReturnValue)
}

internal enum CoreMediaError: Error {
    case failure(OSStatus)
}
