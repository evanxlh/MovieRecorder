//
//  PixelBufferPool.swift
//  SwiftAssistant
//
//  Created by Evan Xie on 2019/4/24.
//

import CoreVideo

/**
 A pixel buffer pool for managing pixel buffers.
 */
internal final class PixelBufferPool {

    fileprivate var auxAttributes: CFDictionary
    
    private(set) var pool: CVPixelBufferPool!
    private(set) var pixelBufferAttributes: CFDictionary
    
    private(set) var width: Int
    private(set) var height: Int
    private(set) var pixelFormat: OSType
    
    /**
     Create CVPixelBufferPool to manage the CVPixelBuffer allocation.
     
     - Parameters:
        - pixelBufferCount:
            The maximum number of buffers allowed in the pixel buffer pool.
            Buffer pool can create only `pixelBufferCount` pixel buffers at most.
     
        - width: The width of pixel buffer
        - height: The height of pixel buffer
        - pixelFormat: The pixel format of pixel buffer. eg, kCVPixelFormatType_32BGRA
     
     - Throws: CoreVideoError.failure(CVReturnValue(CVReturn))
     */
     init(pixelBufferCount: Int, width: Int, height: Int, pixelFormat: OSType) throws {
        self.width = width
        self.height = height
        self.pixelFormat = pixelFormat
        
        auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey: pixelBufferCount] as CFDictionary
        
        pixelBufferAttributes = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormat,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        
        pool = try createPool(pixelBufferAttrs: pixelBufferAttributes, bufferCount: pixelBufferCount)
        preallocatePixelBuffers(pool: pool, bufferCount: pixelBufferCount)
    }
    
    /**
     Create pixel buffer from buffer pool.
     
     If the number of pixel buffer in buffer pool exceeds the the given `pixelBufferCount`,
     throws `CoreVideoError.failure(CVReturnValue)`.
     */
     func createPixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
        guard result == kCVReturnSuccess else {
            throw CoreVideoError.failure(CVReturnValue(result))
        }
        return pixelBuffer!
    }
    
    /**
     Create pixel buffer from a given pixel buffer.
     The given pixel buffer must has the same size dimension with pixel buffer pool size dimension.
     
     - Note: Copy a pixel buffer to another pixel buffer is a time-consuming task.
     */
    func createPixelBuffer(from pixelBuffer: CVPixelBuffer) throws -> CVPixelBuffer {
        
        let srcWidth = CVPixelBufferGetWidth(pixelBuffer)
        let srcHeight = CVPixelBufferGetHeight(pixelBuffer)
        guard srcWidth == width, srcHeight == height else {
            fatalError("The given pixel buffer size dimension must be the same as pixel buffer pool")
        }
        
        let created = try createPixelBuffer()
        CVPixelBufferLockBaseAddress(created, [])
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        
        let dataSize = CVPixelBufferGetDataSize(pixelBuffer)
        let destAddress = CVPixelBufferGetBaseAddress(created)
        let srcAddress = CVPixelBufferGetBaseAddress(pixelBuffer)
        memcpy(destAddress, srcAddress, dataSize)
        CVPixelBufferUnlockBaseAddress(created, [])
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        
        return created
    }
    
    /**
     Free all unused pixel buffers.
     */
     func flush() {
        CVPixelBufferPoolFlush(pool, CVPixelBufferPoolFlushFlags.excessBuffers)
    }
}

fileprivate extension PixelBufferPool {
    
    func createPool(pixelBufferAttrs: CFDictionary, bufferCount: Int) throws -> CVPixelBufferPool {
        var pool: CVPixelBufferPool? = nil
        let poolAttrs = [ kCVPixelBufferPoolMinimumBufferCountKey:  bufferCount ] as CFDictionary
        let result = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttrs, pixelBufferAttrs, &pool)
        guard result == kCVReturnSuccess else {
            throw CoreVideoError.failure(CVReturnValue(result))
        }
        return pool!
    }
    
    func preallocatePixelBuffers(pool: CVPixelBufferPool, bufferCount: Int) {
        var pixelBuffers = [CVPixelBuffer]()
        let auxAttris = [ kCVPixelBufferPoolAllocationThresholdKey: bufferCount] as CFDictionary
        
        for _ in 0..<bufferCount {
            var pixelBuffer: CVPixelBuffer? = nil
            let result = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttris, &pixelBuffer)
            guard result == kCVReturnSuccess else {
                print("PixelBufferPool preallocate pixel buffer failed: \(CVReturnValue(result).description)")
                break
            }
            pixelBuffers.append(pixelBuffer!)
        }
        pixelBuffers.removeAll()
    }
}
