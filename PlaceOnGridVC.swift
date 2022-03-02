//
//  PlaceOnGridVC.swift
//  SoCodeApplication
//
//  Created by LeoChernyak on 21.07.2020.
//  Copyright © 2020 LeoChernyak. All rights reserved.
//

import UIKit
import ARKit
import SceneKit
import RecordButton
import ARVideoKit

class PlaceOnGridVC: UIViewController, ARSCNViewDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @IBOutlet weak var swipeDownLbl: UILabel!
    @IBOutlet weak var galleryBtn: UIButton!
    @IBOutlet weak var instructionLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var cameraButton: RecordButton!
    var grids = [Grid]()
    var detectedImage: String?
    let imagePicker = UIImagePickerController()
    var recorder:RecordAR?
    var progress : CGFloat! = 0
    var videoIsGoing: Bool = false
    var progressTimer : Timer!
    var material: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        imagePicker.delegate = self
        self.loadLastImageThumb { [weak self] (image) in
              DispatchQueue.main.async {
                   self?.galleryBtn.setImage(image, for: .normal)
              }
        }
        galleryBtn.imageView?.contentMode = .scaleAspectFill
        //Video
        cameraButton.buttonColor = .white
        recorder?.onlyRenderWhileRecording = true
        recorder?.contentMode = .auto //ALSO TRIED .auto
        recorder?.enableAdjustEnvironmentLighting = true
        recorder?.inputViewOrientations = [.portrait]
        recorder?.deleteCacheWhenExported = true
        recorder = RecordAR(ARSceneKit: sceneView)
        let longPressGesture = UILongPressGestureRecognizer.init(target: self, action: #selector(handleLongPress))
        cameraButton.addGestureRecognizer(longPressGesture)
        
        //AR to Grid
        sceneView.delegate = self
        let scene = SCNScene()
        sceneView.scene = scene
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapped))
        sceneView.addGestureRecognizer(gestureRecognizer)
        // Do any additional setup after loading the view.
        self.swipeDownLbl.alpha = 0
        self.instructionLabel.alpha = 0
        
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        self.swipeDownLbl.fadeIn(duration: 1.0, delay: 2.0) { (success) in
            print("Fade in 1")
            self.swipeDownLbl.fadeOut(duration: 1.0, delay: 2.0) { (success) in
                print("Fade out 2")
                self.instructionLabel.fadeIn(duration: 1.0, delay: 2.0) { (success) in
                     print("Fade in 3")
//                    self.swipeDownLbl.fadeOut()
                    print("Fade in 4")
                }
            }
        }

    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        galleryBtn.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: galleryBtn.bounds.width - galleryBtn.bounds.height)
        galleryBtn.imageView?.layer.cornerRadius = 10
        galleryBtn.imageView?.layer.borderWidth = 3
        galleryBtn.imageView?.layer.borderColor = UIColor.white.cgColor
        
    }
    
    @IBAction func resetArBtnTap(_ sender: Any) {
        for node in sceneView.scene.rootNode.childNodes {
            node.removeFromParentNode()
        }
        let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .vertical
        sceneView.session.run(configuration, options: options)
        
    }
    
    @IBAction func dismissVCbySwipe(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func galleryBtnClicked(_ sender: Any) {
        if UIImagePickerController.isSourceTypeAvailable(.photoLibrary) {
            imagePicker.videoExportPreset = AVAssetExportPresetPassthrough
            imagePicker.sourceType = .photoLibrary;
            imagePicker.mediaTypes = ["public.image"]
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    @IBAction func cameraBtnClicked(_ sender: Any) {
        if videoIsGoing {
//            ActionService().toggleTorchForVideo(on: false)
            print("LONG PRESS STOPED")
            recorder?.stopAndExport()
            self.progressTimer.invalidate()
            self.cameraButton.buttonState = .idle
            self.progress = 0
            let image = sceneView.snapshot()
            self.galleryBtn.setImage(image, for: .normal)
            self.galleryBtn.setNeedsDisplay()
            videoIsGoing = false
        } else {
//            ActionService().toggleTorch(on: flash)
            let image = sceneView.snapshot()
//            ActionService().flashBlink(view: self.view)
            CustomAlbum().saveImage(image: image)
            self.galleryBtn.setImage(image, for: .normal)
            self.galleryBtn.setNeedsDisplay()
        }
    }
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }
        let grid = Grid(anchor: planeAnchor)
        self.grids.append(grid)
        node.addChildNode(grid)
        self.instructionLabel.fadeOut()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor, planeAnchor.alignment == .vertical else { return }
        let grid = self.grids.filter { grid in
            return grid.anchor.identifier == planeAnchor.identifier
        }.first
        
        guard let foundGrid = grid else {
            return
        }
        
        foundGrid.update(anchor: planeAnchor)
    }
    
    @objc func tapped(gesture: UITapGestureRecognizer) {
        // Get 2D position of touch event on screen
        let touchPosition = gesture.location(in: sceneView)
        
        // Translate those 2D points to 3D points using hitTest (existing plane)
        let hitTestResults = sceneView.hitTest(touchPosition, types: .existingPlaneUsingExtent)
        
        // Get hitTest results and ensure that the hitTest corresponds to a grid that has been placed on a wall
        guard let hitTest = hitTestResults.first, let anchor = hitTest.anchor as? ARPlaneAnchor, let gridIndex = grids.index(where: { $0.anchor == anchor }) else {
            return
        }
        addPainting(hitTest, grids[gridIndex])
    }
    
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            print("LONG PRESS STARTED")
//            ActionService().toggleTorchForVideo(on: flash)
            recorder?.record()
            self.progressTimer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(updateProgress), userInfo: nil, repeats: true)
            self.cameraButton.buttonState = .recording
            videoIsGoing = true
        default: break
        }
    }
    
    @objc func updateProgress() {
        
        let maxDuration = CGFloat(10) // Max duration of the recordButton
        
        progress = progress + (CGFloat(0.05) / maxDuration)
        cameraButton.setProgress(progress)
        
        if progress >= 1 {
            progressTimer.invalidate()
        }
        
    }
    
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                self.material = image
                picker.dismiss(animated: true)
            }
        }
    
    func addPainting(_ hitResult: ARHitTestResult, _ grid: Grid) {
        // 1.
        
        let image = UIImage(named: detectedImage!)
        let planeGeometry = SCNPlane(width: (image?.size.width)!/500, height: (image?.size.height)!/500)
        let material = SCNMaterial()
        if let photoMaterial = self.material {
            material.diffuse.contents = photoMaterial
        } else {
            material.diffuse.contents = UIImage(named: detectedImage ?? "dickpic")
        }
    
        planeGeometry.materials = [material]
        
        // 2.
        //            let modelScene = SCNScene(named: "playFrame.scn")!
        let paintingNode = SCNNode(geometry: planeGeometry)
        //            modelNode = modelScene.rootNode
        paintingNode.transform = SCNMatrix4(hitResult.anchor!.transform)
        paintingNode.eulerAngles = SCNVector3(paintingNode.eulerAngles.x + (-Float.pi / 2), paintingNode.eulerAngles.y, paintingNode.eulerAngles.z)
        paintingNode.position = SCNVector3(hitResult.worldTransform.columns.3.x, hitResult.worldTransform.columns.3.y, hitResult.worldTransform.columns.3.z)
        
        sceneView.scene.rootNode.addChildNode(paintingNode)
        grid.removeFromParentNode()
    }
}


extension UIView {
    func fadeIn(duration: TimeInterval = 1.0, delay: TimeInterval = 0.0, completion: @escaping ((Bool) -> Void) = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn, animations: {
            self.alpha = 1.0
        }, completion: completion)
    }

    func fadeOut(duration: TimeInterval = 1.0, delay: TimeInterval = 3.0, completion: @escaping (Bool) -> Void = {(finished: Bool) -> Void in}) {
        UIView.animate(withDuration: duration, delay: delay, options: .curveEaseIn, animations: {
            self.alpha = 0.0
        }, completion: completion)
    }
}
