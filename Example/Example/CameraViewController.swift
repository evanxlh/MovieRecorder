//
//  CameraViewController.swift
//  Example
//
//  Created by Evan Xie on 2019/5/31.
//

import UIKit
import MovieRecorder

class CameraViewController: RecorderViewController {
    
    var session: AVCameraSession!
    
    override func viewDidLoad() {
        
        session = AVCameraSession()
        try! session.useAudioDeviceInput()
        try! session.useVideoDeviceInput(for: .back(.hd4K3840x2160))
        
        super.viewDidLoad()
        
        let preview = view as! PreviewView
        preview.session = session.session
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillAppear(animated)
        session.stopRunning()
    }
    
    override func createRecorder() {
        var movieURL = URL(fileURLWithPath: NSTemporaryDirectory())
        movieURL = movieURL.appendingPathComponent("myMovie.mp4")
        
        let videoSize = CGSize(width: 3840, height: 2160)
        let configuraiton = RecorderConfiguration(outputURL: movieURL, videoFramerate: 30, videoResulution: videoSize, enablesAudioTrack: false, fileType: .mov)
        recorder = AVCameraRecorder(session: session, configuration: configuraiton)
        recorder?.metadata = SCNViewRecorder.commonMetaldata(withCreator: "Evan Xie", copyrights: "Evan Xie, 2019")
        
        recorder?.errorHandler = { [weak self] error in
            self?.recordButton.isEnabled = true
            self?.recordButton.setTitle("REC", for: .normal)
            self?.recorder = nil
            print("recorder error: \(error)")
        }
    }
}
