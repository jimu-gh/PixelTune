//
//  SplashViewController.swift
//  PixelTune
//
//  Created by Jim on 4/27/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import Foundation
import UIKit

class SplashViewController: UIViewController {
    
    // LOGIN DECLARATIONS //
    
    var auth = SPTAuth.defaultInstance()
    var session : SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?

    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var loginButton: UIButton!
    
    @IBAction func startButton(_ sender: UIButton) {
        performSegue(withIdentifier: "StartSegue", sender: self)
    }
    
    @IBAction func loginButton(_ sender: UIButton) {
        UIApplication.shared.open(loginUrl!, options: [:], completionHandler: nil)
        updateAfterLogin()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        loginButton.isHidden = false
        startButton.isHidden = true
        
        loginSetup()
        
        NotificationCenter.default.addObserver(self, selector: #selector(SplashViewController.updateAfterLogin), name: NSNotification.Name(rawValue: "loginSuccessfull"), object: nil)
        
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
                    } else {
                        print("Error refreshing session")
                    }
                    
                })
            } else {
                print("Session is valid (SPLASH)")
                updateAfterLogin()
            }
            
        } else {
            print("No session, need to login.")
            loginButton.isHidden = false
            startButton.isHidden = true
        }
        
    }
    
    func loginSetup(){
        auth!.redirectURL     = URL(string: "PixelTune://returnAfterLogin")
        auth!.clientID        = "79887262b9bf49838c1c63b140bbfbc0"
        auth!.requestedScopes = [SPTAuthStreamingScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistModifyPublicScope, SPTAuthPlaylistModifyPrivateScope, SPTAuthUserReadPrivateScope]
        loginUrl = auth!.spotifyWebAuthenticationURL()
    }
    
    func updateAfterLogin() {
        loginButton.isHidden = true
        startButton.isHidden = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }
}
