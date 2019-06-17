//
//  MetalGameViewController.swift
//  Example
//
//  Created by Evan Xie on 2019/5/24.
//

import UIKit
import MetalKit
import MovieRecorder

// Our iOS specific view controller
class MetalGameViewController: RecorderViewController {

    var renderer: Renderer!
    var mtkView: MTKView!

    override func viewDidLoad() {

        super.viewDidLoad()
        
        guard let mtkView = view as? MTKView else {
            print("View of Gameview controller is not an MTKView")
            return
        }

        // Select the device to render with.  We choose the default device
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            print("Metal is not supported")
            return
        }
        
        mtkView.device = defaultDevice
        mtkView.backgroundColor = UIColor.black
        mtkView.preferredFramesPerSecond = 60
        mtkView.framebufferOnly = false

        guard let newRenderer = Renderer(metalKitView: mtkView) else {
            print("Renderer cannot be initialized")
            return
        }

        renderer = newRenderer

        renderer.mtkView(mtkView, drawableSizeWillChange: mtkView.drawableSize)

        mtkView.delegate = renderer
        self.mtkView = mtkView
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        mtkView.isPaused = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        mtkView.isPaused = true
    }
    
    override func createRecorder() {
        
        var movieURL = URL(fileURLWithPath: NSTemporaryDirectory())
        movieURL = movieURL.appendingPathComponent("myMovie.mp4")
        let width = mtkView.bounds.width * UIScreen.main.nativeScale
        let heigth = mtkView.bounds.height * UIScreen.main.nativeScale
        let size = CGSize(width: width, height: heigth)
        
        let configuration = RecorderConfiguration(outputURL: movieURL, videoFramerate: mtkView.preferredFramesPerSecond, videoResulution: size)
        
        recorder = MTLTextureRecorder(device: mtkView.device!, configuration: configuration)
        
        recorder?.errorHandler = { [weak self] error in
            self?.recordButton.isEnabled = true
            self?.recordButton.setTitle("REC", for: .normal)
            self?.recorder = nil
            print("recorder error: \(error)")
        }
        
        renderer.recorder = recorder as? MTLTextureRecorder
    }
}
