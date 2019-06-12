//
//  MTKViewProducer.swift
//  MovieRecorder
//
//  Created by Evan Xie on 2019/6/11.
//

#if canImport(MetalKit)
import MetalKit

internal final class MTKViewProducer: NSObject, MediaSampleProducer {
    
    fileprivate var running: Bool = false
    
    var isRunning: Bool {
        return running
    }
    
    var producerType: ProducerType {
        return .video
    }
    
    let sampleConsumers = SampleConsumerContainer()
    
    func startRunning() throws {
        
    }
    
    func stopRunning() {
        
    }
    
    func recommendedSettingsForFileType(_ fileType: MovieFileType) -> [String : Any]? {
        return nil
    }
    
}

#endif
