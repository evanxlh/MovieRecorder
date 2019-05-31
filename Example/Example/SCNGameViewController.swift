//
//  SCNGameViewController.swift
//  Example
//
//  Created by Evan Xie on 2019/5/29.
//

import UIKit
import QuartzCore
import SceneKit
import MovieRecorder
import AVKit

class SCNGameViewController: UIViewController {

    fileprivate var recorder: MovieRecorder?
    
    var button = UIButton(type: .custom)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // create a new scene
        let scene = SCNScene(named: "art.scnassets/ship.scn")!
        
        // create and add a camera to the scene
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        scene.rootNode.addChildNode(cameraNode)
        
        // place the camera
        cameraNode.position = SCNVector3(x: 0, y: 0, z: 15)
        
        // create and add a light to the scene
        let lightNode = SCNNode()
        lightNode.light = SCNLight()
        lightNode.light!.type = .omni
        lightNode.position = SCNVector3(x: 0, y: 10, z: 10)
        scene.rootNode.addChildNode(lightNode)
        
        // create and add an ambient light to the scene
        let ambientLightNode = SCNNode()
        ambientLightNode.light = SCNLight()
        ambientLightNode.light!.type = .ambient
        ambientLightNode.light!.color = UIColor.darkGray
        scene.rootNode.addChildNode(ambientLightNode)
        
        // retrieve the ship node
        let ship = scene.rootNode.childNode(withName: "ship", recursively: true)!
        
        // animate the 3d object
        ship.runAction(SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 2, z: 0, duration: 1)))
        
        // retrieve the SCNView
        let scnView = self.view as! SCNView
        scnView.antialiasingMode = .multisampling4X
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.black
        
        addRecordButton()
    }
    
    fileprivate func addRecordButton() {
        button.backgroundColor = UIColor.red
        button.borderColor = UIColor.white
        button.borderWidth = 2
        button.shadowRadius = 2
        button.shadowOpacity = 0.5
        button.cornerRadius = 35
        button.setTitle("REC", for: .normal)
        button.addTarget(self, action: #selector(recorderButtonTapped), for: .touchUpInside)
        view.addSubview(button)
        
        button.translatesAutoresizingMaskIntoConstraints = false
        let widthConstraint = NSLayoutConstraint(item: button, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 70)
        let heightConstraint = NSLayoutConstraint(item: button, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: 70)
        button.addConstraints([widthConstraint, heightConstraint])
        
        let centerX = NSLayoutConstraint(item: button, attribute: .centerX, relatedBy: .equal, toItem: view, attribute: .centerX, multiplier: 1.0, constant: 0)
        let bottomY = NSLayoutConstraint(item: button, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1.0, constant: -100)
        view.addConstraints([centerX, bottomY])
        
    }
    
    override var shouldAutorotate: Bool {
        return true
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }
    
    @IBAction func recorderButtonTapped(_ sender: UIButton) {
        
        if recorder == nil {
            createRecorder()
            sender.isEnabled = false
            recorder?.startRecording(completionBlock: {
                sender.setTitle("STOP", for: .normal)
                sender.isEnabled = true
            })
        } else {
            sender.isEnabled = false
            recorder?.stopRecording(completionBlock: { (movieURL) in
                sender.isEnabled = true
                sender.setTitle("REC", for: .normal)
                let playerViewController = AVPlayerViewController()
                let player = AVPlayer(url: movieURL)
                playerViewController.player = player
                self.present(playerViewController, animated: true, completion: {
                    player.play()
                })
                
                self.recorder = nil
            })
        }
    }
    
    private func createRecorder() {
        let scale = UIScreen.main.nativeScale
        let size = CGSize(width: view.bounds.width * scale, height: view.bounds.height * scale)
        let movieURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("MyMovie.mp4")
        let audioConfiguration = AudioTrackConfiguration()
        let videoConfiguration = VideoTrackConfiguration(framerate: 60, resolution: size)
        let trackConfiguration = MovieTrackConfiguration.audioAndVideo(audioConfiguration, videoConfiguration)
        let provider = SCNViewTrackDataProvider(scnView: self.view as! SCNView, trackConfiguration: trackConfiguration)
        
        recorder = MovieRecorder(outputURL: movieURL, trackDataProvider: provider)
        recorder?.errorHandler = { error in
            self.button.isEnabled = true
            self.button.setTitle("REC", for: .normal)
            print("recorder error: \(error)")
            self.recorder = nil
        }
    }

}
