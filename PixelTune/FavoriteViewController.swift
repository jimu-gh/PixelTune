//
//  FavoriteViewController.swift
//  PixelTune
//
//  Created by Jim on 4/27/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import SwiftyJSON

class FavoriteViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, SPTAudioStreamingPlaybackDelegate, SPTAudioStreamingDelegate {
    
    var favorites = [FavoritesItem]()
    
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    @IBOutlet weak var nowPlayingLabel: UILabel!
    @IBOutlet weak var favoritesTable: UITableView!
    @IBOutlet weak var prevSongButton: UIButton!
    @IBOutlet weak var nextSongButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    
    weak var delegate: FavoriteViewControllerDelegate?
    
    // PLAYER DECLARATIONS //
    
    var auth = SPTAuth.defaultInstance()
    var session : SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    
    var songChosen = false
    var currentTrack : Int?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        favoritesTable.delegate = self
        favoritesTable.dataSource = self
        
        favoritesTable.backgroundColor = playPauseButton.backgroundColor
        
        fetchAllFavs()
        
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
    
    func fetchAllFavs(){
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "FavoritesItem")
        do {
            let result = try managedObjectContext.fetch(request)
            favorites = result as! [FavoritesItem]
        }
        catch {
            print("Error fetching favorites")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favorites.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavCell", for: indexPath) as! FavCell
        if let songname = favorites[indexPath.row].songname {
            if let artistname = self.favorites[indexPath.row].artistname {
                cell.SongInfo.text = ""
                cell.SongInfo.text?.append(artistname)
                cell.SongInfo.text?.append(" - ")
                cell.SongInfo.text?.append(songname)
            }
        }
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        songChosen = true
        playPauseButton.setTitle("⏸", for: UIControlState.normal)
        playSong(position: indexPath.row)
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        let fav = favorites[indexPath.row]
        managedObjectContext.delete(fav)
        do{
            try managedObjectContext.save()
        } catch {
            print("\(error)")
        }
        favorites.remove(at: indexPath.row)
        favoritesTable.reloadData()
    }
    
    @IBAction func exitFavorites(_ sender: UIBarButtonItem) {
        self.player?.setIsPlaying(false, callback: nil)
        delegate?.exitFavoritesButton(by: self)
    }
    
    @IBAction func pausePlayer(_ sender: UIButton) {
        if self.player != nil {
            if songChosen == false {
                songChosen = true
                playSong(position: 0)
                playPauseButton.setTitle("⏸", for: UIControlState.normal)
            }
            else if self.player?.playbackState.isPlaying == true{
                self.player?.setIsPlaying(false, callback: nil)
                playPauseButton.setTitle("▶️", for: UIControlState.normal)
            } else {
                self.player?.setIsPlaying(true, callback: nil)
                playPauseButton.setTitle("⏸", for: UIControlState.normal)
            }
        }
    }
    
    @IBAction func nextPlayer(_ sender: UIButton) {
        if currentTrack == favorites.count - 1 {
            print ("Last track.")
        } else {
            playSong(position: currentTrack! + 1)
        }
    }
    
    @IBAction func prevPlayer(_ sender: UIButton) {
        if currentTrack == 0 {
            print ("First track.")
        } else {
            playSong(position: currentTrack! - 1)
        }
    }
    
    func playSong(position: Int) {

        let songURI = favorites[position].songuri
        self.player?.playSpotifyURI(songURI, startingWith: 0, startingWithPosition: 0, callback: { (error) in
            if (error == nil) {
                print("Playing from selection!")
            }
            else {
                print(error!)
            }
        })
        
        // UPDATE LABEL //
        
        if let songname = favorites[position].songname {
            if let artistname = favorites[position].artistname {
                nowPlayingLabel.text = "Current Song: " + artistname + " - " + songname
            }
        }
        
        currentTrack = position
    }
    
    
    
    
}
