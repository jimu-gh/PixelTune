//
//  ResultViewController.swift
//  PixelTune
//
//  Created by Jim on 4/24/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import Foundation
import UIKit
import Alamofire
import SwiftyJSON
import CoreData

class ResultViewController: UIViewController, SPTAudioStreamingPlaybackDelegate, SPTAudioStreamingDelegate, UICollectionViewDelegate, UICollectionViewDataSource, UITableViewDelegate, UITableViewDataSource, SaveViewControllerDelegate {
    
    // SAVED IMAGE //
    
    var image: UIImage?
    
    // GOOGLE DECLARATIONS //
    
    let googleapisession = URLSession.shared
    var googleAPIKey = "AIzaSyDnq4bkSqiisbQyfRqZlNlN2ONPIvNGLEg"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    // SPOTIFY DECLARATIONS
    
    var auth = SPTAuth.defaultInstance()
    var session : SPTSession!
    var player: SPTAudioStreamingController?
    var loginUrl: URL?
    
    // GOOGLE API DATA CONTAINERS //
    
    var labelData = [String]()
    var emotionData = [String:Double]()
    var textData = [String]()
    var binaryImageData : String!
    
    // SPOTIFY MUSIC OBJECT CONTAINERS //
    var tracklist = [TrackObj]()
    var tracks = [JSON]()
    var artists = [JSON]()
    
    struct TrackObj {
        var Track : JSON
        var Artist : JSON
    }
    
    var currentTrack : Int?
    var songChosen = false
    
    var favorites = [FavoritesItem]()
    
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    // DELEGATES AND OUTLETS //
    
    weak var delegate: ResultViewControllerDelegate?
    
    @IBOutlet weak var trackTable: UITableView!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var playPauseButton: UIButton!
    @IBOutlet weak var prevSongButton: UIButton!
    @IBOutlet weak var nextSongButton: UIButton!
    @IBOutlet weak var textField1: UITextField!
    @IBOutlet weak var labelCollection: UICollectionView!
    @IBOutlet weak var nowPlayingLabel: UILabel!
    @IBOutlet weak var favoriteButton: UIButton!
    
    
    // FUNCTIONS //
    
    func makeAPICalls (){
        for label in self.labelData{
            let cleanlabel = label.replacingOccurrences(of: " ", with: "+")
            let trackqueryurl = "https://api.spotify.com/v1/search?q=" + cleanlabel + "&type=track&offset=0&limit=5"
            
            Alamofire.request(trackqueryurl, method: .get).validate().responseJSON { response in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    
                    // ADD ARTIST AND SONG TO TRACKLIST AS TRACKOBJ //
                    
                    if let trackhits = json["tracks"]["items"].array {
                        for track in trackhits {
                            if let artistqueryurl = track["artists"][0]["href"].string {
                                
                                Alamofire.request(artistqueryurl, method: .get).validate().responseJSON { response in
                                    switch response.result {
                                    case .success(let value):
                                        
                                        let artist = JSON(value)
                                        let songtobeadded = TrackObj(Track: track, Artist: artist)
                                        self.tracklist.append(songtobeadded)
                                        
                                    case .failure(let error):
                                        print(error)
                                    }
                                    
                                    // DE DUPE tracklist //
                                    for i in 0..<self.tracklist.count {
                                        for var j in stride(from: i+1, to: self.tracklist.count, by: 1) {
                                            if let uri1 = self.tracklist[i].Track["uri"].string {
                                                if let uri2 = self.tracklist[j].Track["uri"].string {
                                                    if uri1 == uri2 {
                                                        self.tracklist.remove(at: j)
                                                        j -= 1
                                                    }
                                                    else {
                                                        
                                                        var namematch = false
                                                        
                                                        if let jname = self.tracklist[j].Track["name"].string {
                                                            if let iname = self.tracklist[i].Track["name"].string {
                                                                if jname == iname {
                                                                    namematch = true
                                                                }
                                                            }
                                                        }
                                                        
                                                        var artistmatch = false
                                                        
                                                        if let jartist = self.tracklist[j].Artist["name"].string {
                                                            if let iartist = self.tracklist[i].Artist["name"].string {
                                                                if jartist == iartist {
                                                                    artistmatch = true
                                                                }
                                                            }
                                                        }
                                                        
                                                        if namematch && artistmatch {
                                                            self.tracklist.remove(at: j)
                                                            j -= 1
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    // SORTS //
                                    
                                    for i in 0..<self.tracklist.count {
                                        for j in 0..<self.tracklist.count-1-i {
                                            if let popularity1 = self.tracklist[j].Track["popularity"].int {
                                                if let popularity2 = self.tracklist[j+1].Track["popularity"].int {
                                                    if popularity1 < popularity2 {
                                                        let temp = self.tracklist[j]
                                                        self.tracklist[j] = self.tracklist[j+1]
                                                        self.tracklist[j+1] = temp
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    DispatchQueue.main.async{
                                        self.trackTable.isHidden = false
                                        self.trackTable.reloadData()
                                        self.playPauseButton.isHidden = false
                                        self.nextSongButton.isHidden = false
                                        self.prevSongButton.isHidden = false
                                    }
                                }
                            }
                        }
                    } else {
                        print("No tracks found")
                    }

                case .failure(let error):
                    print(error)
                }
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        playPauseButton.isHidden = true
        nextSongButton.isHidden = true
        prevSongButton.isHidden = true
        trackTable.isHidden = true
        favoriteButton.isHidden = true
        trackTable.backgroundColor = playPauseButton.backgroundColor
        
        fetchAllFavs()
        
        loginSetup()
        
        let userDefaults = UserDefaults.standard

        labelCollection.delegate = self
        labelCollection.dataSource = self
        trackTable.delegate = self
        trackTable.dataSource = self
        
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
                print("Session is valid (TUNE)")
                playUsingSession(sessionObj: sptsession)
            }
            
        } else {
            loginButton.isHidden = false
            playPauseButton.setTitle(" ", for: UIControlState.normal)
            nextSongButton.setTitle(" ", for: UIControlState.normal)
            prevSongButton.setTitle(" ", for: UIControlState.normal)
        }
        
        createRequest(with: binaryImageData!)
    }
    
    func fetchAllFavs() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "FavoritesItem")
        do {
            let result = try managedObjectContext.fetch(request)
            favorites = result as! [FavoritesItem]
        }
        catch {
            print("Error fetching favorites")
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
    
    // CREATE CLOUD VISION REQUEST //
    
    func createRequest(with imageBase64: String) {
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 6
                    ],
//                    [
//                        "type": "FACE_DETECTION",
//                        "maxResults": 6
//                    ],
//                    [
//                        "type": "DOCUMENT_TEXT_DETECTION"
//                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonDictionary: jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = googleapisession.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }

            self.analyzeResults(data)
        }
        task.resume()
        
    }
    
    func analyzeResults(_ dataToParse: Data) {
        
        // Update UI on the main thread
        DispatchQueue.main.async(execute: {
            
            // Use SwiftyJSON to parse results
            let json = JSON(data: dataToParse)
            let errorObj: JSON = json["error"]
            
            // Check for errors
            if (errorObj.dictionaryValue != [:]) {
                self.labelData.append("Error code \(errorObj["code"]): \(errorObj["message"])")
            } else {
                // Parse the response
                let responses: JSON = json["responses"][0]
                
                // Get label annotations
                let labelAnnotations: JSON = responses["labelAnnotations"]
                let numLabels: Int = labelAnnotations.count
                var labels: Array<String> = []
                
                if numLabels > 0 {
                    for index in 0..<numLabels {
                        let label = labelAnnotations[index]["description"].stringValue
                        labels.append(label)
                    }
                    self.labelData = labels
                } else {
                    print("No labels found")
                }
                
                // Get face annotations
                let faceAnnotations: JSON = responses["faceAnnotations"]
                if faceAnnotations != JSON.null {
                    let emotions: Array<String> = ["Joy", "Sorrow", "Surprise", "Anger"]
                    
                    let numPeopleDetected:Int = faceAnnotations.count
                    
                    var emotionTotals: [String: Double] = ["Sorrow": 0, "Joy": 0, "Surprise": 0, "Anger": 0]
                    
                    var emotionNormal: [String: Double] = ["Sorrow": 0, "Joy": 0, "Surprise": 0, "Anger": 0]
                    
                    var emotionLikelihoods: [String: Double] = ["VERY_LIKELY": 0.9, "LIKELY": 0.75, "POSSIBLE": 0.5, "UNLIKELY":0.25, "VERY_UNLIKELY": 0.0]
                    
                    // For each person
                    
                    for index in 0..<numPeopleDetected {
                        let personData:JSON = faceAnnotations[index]
                        // Sum all the detected emotions
                        for emotion in emotions {
                            let lookupEmotion = emotion.lowercased() + "Likelihood"
                            let result:String = personData[lookupEmotion].stringValue
                            emotionTotals[emotion]! += emotionLikelihoods[result]!
                        }
                    }
                    
                    // Get emotion likelihood as a % and display in UI
                    for (emotion, total) in emotionTotals {
                        let likelihood:Double = total / Double(numPeopleDetected)
                        let percent: Int = Int(round(likelihood * 100))
                        emotionNormal[emotion]! = Double(percent) / 100
//                        self.faceData.append("\(emotion): \(percent)%")
                    }
                    
                    self.emotionData = emotionNormal
                    
                } else {
                    print("No faces found")
                }
                
                // Get text annotations
                let textAnnotations: JSON = responses["textAnnotations"]
                if textAnnotations != JSON.null {
                    let numText: Int = textAnnotations.count
                    var texts: Array<String> = []
                    
                    if numText > 0 {
                        for index in 0..<numText {
                            let text = textAnnotations[index]["description"].stringValue
                            texts.append(text)
                        }
                    }
                    self.textData = texts
                } else {
                    print("No text found")
                }
                
                self.labelCollection.reloadData()
                self.nowPlayingLabel.text = "Your Instatunes are ready. Enjoy!"
                self.makeAPICalls()
            }
        })
        
    }
    
    @IBAction func exitTunes(_ sender: UIBarButtonItem) {
        self.player?.setIsPlaying(false, callback: nil)
        delegate?.exitTunesButton(by: self)
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
        if currentTrack == self.tracklist.count - 1 {
            print("Last track.")
        } else {
            playSong(position: currentTrack! + 1)
        }
        
    }
    
    @IBAction func prevPlayer(_ sender: UIButton) {
        if currentTrack == 0 {
            print("First track.")
        } else {
            playSong(position: currentTrack! - 1)
        }
    }
    
    @IBAction func favoriteTrack(_ sender: UIButton) {
        
        var dupe = false
        
        if let currenturi = self.tracklist[currentTrack!].Track["uri"].string {
            for fav in favorites {
                if currenturi == fav.songuri {
                    dupe = true
                }
            }
        }
        if dupe == true {
            let alert = UIAlertController(title: "Already in favorites!", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:nil)
            alert.addAction(dismiss)
            present(alert, animated: true, completion: nil)
        }
        else {
            let thisIsMySong = NSEntityDescription.insertNewObject(forEntityName: "FavoritesItem", into: managedObjectContext) as! FavoritesItem
            
            if let songname = self.tracklist[currentTrack!].Track["name"].string {
                thisIsMySong.songname = songname
            }
            if let artistname = self.tracklist[currentTrack!].Artist["name"].string {
                thisIsMySong.artistname = artistname
            }
            if let songuri = self.tracklist[currentTrack!].Track["uri"].string {
                thisIsMySong.songuri = songuri
            }
            self.favorites.append(thisIsMySong)
            let alert = UIAlertController(title: "Added to favorites!", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:nil)
            alert.addAction(dismiss)
            present(alert, animated: true, completion: nil)
            do{
                try managedObjectContext.save()
            } catch {
                print ("\(error)")
            }
        }
    }
    
    @IBAction func saveButton(_ sender: UIBarButtonItem) {
        if currentTrack != nil {
            performSegue(withIdentifier: "SaveSegue", sender: self)
        }
        else {
            let alert = UIAlertController(title: "Choose a track to save with the picture!", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:nil)
            alert.addAction(dismiss)
            present(alert, animated: true, completion: nil)
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "SaveSegue" {
            let navigationController = segue.destination as! UINavigationController
            let SaveViewController = navigationController.topViewController as! SaveViewController
            SaveViewController.delegate = self
            SaveViewController.image = image!
            SaveViewController.track = self.tracklist[currentTrack!].Track
            SaveViewController.artist = self.tracklist[currentTrack!].Artist
        }
    }
    
    
    // LABEL COLLECTION VIEW //
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.labelData.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "ImageLabelCell", for: indexPath) as! ImageLabelCell
        cell.label.text = self.labelData[indexPath.row]
        return cell
    }
    
    // TRACK TABLE VIEW //
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.tracklist.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TrackCell", for: indexPath) as! TrackCell
        if let songname = self.tracklist[indexPath.row].Track["name"].string {
            if let artistname = self.tracklist[indexPath.row].Artist["name"].string {
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
        favoriteButton.isHidden = false
        playPauseButton.setTitle("⏸", for: UIControlState.normal)
        songChosen = true
        self.playSong(position: indexPath.row)
    }
    
    func playSong(position: Int) {
        if let songURI = self.tracklist[position].Track["uri"].string {
            
            self.player?.playSpotifyURI(songURI, startingWith: 0, startingWithPosition: 0, callback: { (error) in
                if (error == nil) {
                    print("Playing from selection!")
                }
                else {
                    print(error!)
                }
            })
        }
        
        // UPDATE NOW PLAYING //
        
        if let songname = self.tracklist[position].Track["name"].string {
            if let artistname = self.tracklist[position].Artist["name"].string {
                nowPlayingLabel.text = "Current Song: " + artistname + " - " + songname
                favoriteButton.isHidden = false
            }
        }
        
        self.currentTrack = position
    }
    
    func exitSaveButton(by controller: SaveViewController) {
        dismiss(animated: true, completion: nil)
    }
    
}

//Client ID
//79887262b9bf49838c1c63b140bbfbc0
//Client Secret
//1638cada9a5e4d63a725fb1c908f9d3a
