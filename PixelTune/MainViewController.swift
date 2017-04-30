//
//  ViewController.swift
//  PixelTune
//
//  Created by Jim on 4/24/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import UIKit
import SwiftyJSON

class MainViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, ResultViewControllerDelegate, FavoriteViewControllerDelegate, SPTAudioStreamingPlaybackDelegate, SPTAudioStreamingDelegate, AlbumViewControllerDelegate {
    
    @IBOutlet weak var imagePicked: UIImageView!
    var imageBool = false

    var googleAPIKey = "AIzaSyDnq4bkSqiisbQyfRqZlNlN2ONPIvNGLEg"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    // PLAYER DECLARATIONS //
    
    var auth = SPTAuth.defaultInstance()
    var session : SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var libraryButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let userDefaults = UserDefaults.standard
        
        if let sessionObj:AnyObject = userDefaults.object(forKey: "SpotifySession") as AnyObject? {
            
            let sessionDataObj = sessionObj as! Data
            
            let sptsession = NSKeyedUnarchiver.unarchiveObject(with: sessionDataObj) as! SPTSession
            if !sptsession.isValid(){
                print("Session not valid")
                SPTAuth.defaultInstance().renewSession(sptsession, callback: { (error, session) in
                    if error == nil {
                        print("No errors in renewing")
                        let sessionData = NSKeyedArchiver.archivedData(withRootObject: session!)
                        userDefaults.set(sessionData, forKey:"SpotifySession")
                        userDefaults.synchronize()
                        self.session = session
                        self.playUsingSession(sessionObj: session)
                    } else {
                        print("Error refreshing session")
                    }
                    
                })
            } else {
                print("Session is valid (MAIN)")
                playUsingSession(sessionObj: sptsession)
            }
            
        } else {
            print("No session, need to login.")
        }
    }
    
    func playUsingSession(sessionObj: SPTSession!) {
        if self.player == nil {
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
            do {
                try self.player!.start(withClientId: auth?.clientID)
            } catch {
                print("Error starting player")
            }
            self.player!.login(withAccessToken: sessionObj.accessToken)
        }
    }
    
    func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
        self.player?.playSpotifyURI("spotify:track:7GhIk7Il098yCjg4BQjzvb", startingWith: 0, startingWithPosition: 0, callback: { (error) in
            if (error == nil) {
                print("Playing!")
            }
        })
        self.player?.setIsPlaying(false, callback: nil)
    }
    

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // OPEN CAMERA //
    
    @IBAction func openCameraButton(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.camera;
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // OPEN LIBRARY //
    
    @IBAction func openLibraryButton(_ sender: UIButton) {
        if UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.photoLibrary) {
            let imagePicker = UIImagePickerController()
            imagePicker.delegate = self
            imagePicker.sourceType = UIImagePickerControllerSourceType.photoLibrary;
            imagePicker.allowsEditing = false
            self.present(imagePicker, animated: true, completion: nil)
        }
    }
    
    // OPEN ALBUMS //
    
    @IBAction func openAlbumButton(_ sender: UIButton) {
        performSegue(withIdentifier: "AlbumSegue", sender: self)
    }
    
    
    @IBAction func openFavoritesButton(_ sender: UIButton) {
        performSegue(withIdentifier: "FavSegue", sender: self)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingImage image: UIImage!, editingInfo: [NSObject : AnyObject]!) {
        imagePicked.image = image
        imageBool = true
        self.dismiss(animated: true, completion: nil);
    }
    
    @IBAction func tuneButton(_ sender: UIBarButtonItem) {
        if imageBool == false {
            let alert = UIAlertController(title: "Choose a picture", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:nil)
            alert.addAction(dismiss)
            present(alert, animated: true, completion: nil)
        }
        else{
            performSegue(withIdentifier: "TuneSegue", sender: self)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TuneSegue" {
            let binaryImageData = base64EncodeImage(imagePicked.image!)
            let navigationController = segue.destination as! UINavigationController
            let ResultViewController = navigationController.topViewController as! ResultViewController
            ResultViewController.binaryImageData = binaryImageData
            ResultViewController.delegate = self
            ResultViewController.image = imagePicked.image!
        }
        if segue.identifier == "FavSegue" {
            let navigationController = segue.destination as! UINavigationController
            let FavoriteViewController = navigationController.topViewController as! FavoriteViewController
            FavoriteViewController.delegate = self
        }
        if segue.identifier == "AlbumSegue" {
            let navigationController = segue.destination as! UINavigationController
            let AlbumViewController = navigationController.topViewController as! AlbumViewController
            AlbumViewController.delegate = self
        }
    }

// SAVE PIC
//    let imageData = UIImageJPEGRepresentation(imagePicked.image!, 0.6)
//    let compressedJPGImage = UIImage(data: imageData!)
//    UIImageWriteToSavedPhotosAlbum(compressedJPGImage!, nil, nil, nil)

    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }

    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if ((imagedata?.count)! > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func exitTunesButton(by controller: ResultViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func resetButton(_ sender: UIBarButtonItem) {
        imagePicked.image = nil
        imageBool = false
    }
    
    func exitFavoritesButton(by controller: FavoriteViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func exitAlbumButton(by controller: AlbumViewController) {
        dismiss(animated: true, completion: nil)
    }
    
}


//Client ID
//79887262b9bf49838c1c63b140bbfbc0
//Client Secret
//1638cada9a5e4d63a725fb1c908f9d3a
