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

class SCNGameViewController: RecorderViewController {
    
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
        scnView.preferredFramesPerSecond = 60
        scnView.antialiasingMode = .multisampling4X
        
        // set the scene to the view
        scnView.scene = scene
        
        // allows the user to manipulate the camera
        scnView.allowsCameraControl = true
        
        // show statistics such as fps and timing information
        scnView.showsStatistics = true
        
        // configure the view
        scnView.backgroundColor = UIColor.black
    }

    override func createRecorder() {
        
        var movieURL = URL(fileURLWithPath: NSTemporaryDirectory())
        movieURL = movieURL.appendingPathComponent("myMovie.mp4")
        
        recorder = SCNViewRecorder(view: view as! SCNView, enablesAudio: true, outputURL: movieURL)
        recorder?.metadata = SCNViewRecorder.commonMetaldata(withCreator: "Evan Xie", copyrights: "Evan Xie, 2019")
    
        recorder?.errorHandler = { [weak self] error in
            self?.recordButton.isEnabled = true
            self?.recordButton.setTitle("REC", for: .normal)
            self?.recorder = nil
            print("recorder error: \(error)")
        }
    }

}
