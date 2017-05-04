//
//  AlbumViewController.swift
//  PixelTune
//
//  Created by Jim on 4/27/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import SwiftyJSON

class AlbumViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout, SPTAudioStreamingPlaybackDelegate, SPTAudioStreamingDelegate {
    
    var album = [AlbumItem]()
    
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    weak var delegate: AlbumViewControllerDelegate?
    
    // PLAYER DECLARATIONS //
    
    var auth = SPTAuth.defaultInstance()
    var session : SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    
    @IBOutlet weak var albumCollection: UICollectionView!
    
    @IBAction func exitAlbum(_ sender: UIBarButtonItem) {
        self.player?.setIsPlaying(false, callback: nil)
        delegate?.exitAlbumButton(by: self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        fetchAlbum()
        
        loginSetup()
        
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
                print("Session is valid (FAVORITES)")
                playUsingSession(sessionObj: sptsession)
            }
            
        } else {
            print("No session, need to login.")
        }
        
        albumCollection.delegate = self
        albumCollection.dataSource = self
        albumCollection.reloadData()
    }
    
    func loginSetup(){
        auth!.redirectURL     = URL(string: "PixelTune://returnAfterLogin")
        auth!.clientID        = "79887262b9bf49838c1c63b140bbfbc0"
        auth!.requestedScopes = [SPTAuthStreamingScope, SPTAuthPlaylistReadPrivateScope, SPTAuthPlaylistModifyPublicScope, SPTAuthPlaylistModifyPrivateScope, SPTAuthUserReadPrivateScope]
        loginUrl = auth!.spotifyWebAuthenticationURL()
    }
    
    func playUsingSession(sessionObj: SPTSession!) {
        if self.player == nil {
            self.player = SPTAudioStreamingController.sharedInstance()
            self.player!.playbackDelegate = self
            self.player!.delegate = self
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func fetchAlbum(){
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "AlbumItem")
        do {
            let result = try managedObjectContext.fetch(request)
            album = result as! [AlbumItem]
        }
        catch {
            print("Error fetching favorites")
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return album.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "InstatuneCell", for: indexPath) as! InstatuneCell
        if let imagetoconvert = album[indexPath.row].image {
            cell.Image.image = UIImage(data:imagetoconvert as Data, scale:1.0)
        } else {
            print("image error")
        }
        cell.Title.text = album[indexPath.row].title
        cell.Desc.text = album[indexPath.row].desc
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize.init(width: 375, height: 375)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        playSong(position: indexPath.row)
    }
    
    func playSong(position: Int){
        let songURI = album[position].songuri
        self.player?.playSpotifyURI(songURI, startingWith: 0, startingWithPosition: 0, callback: { (error) in
            if (error == nil) {
                print("Playing from selection!")
            }
            else {
                print(error!)
            }
        })
    }
    
    @IBAction func deleteLastInstatune(_ sender: UIButton) {
        let lastInstatune = album[album.count-1]
        managedObjectContext.delete(lastInstatune)
        do{
            try managedObjectContext.save()
        } catch {
            print("\(error)")
        }
        album.remove(at: album.count-1)
        albumCollection.reloadData()
    }

}
