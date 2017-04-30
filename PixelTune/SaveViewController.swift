//
//  SaveViewController.swift
//  PixelTune
//
//  Created by Jim on 4/27/17.
//  Copyright © 2017 Jim Ho. All rights reserved.
//

import Foundation
import UIKit
import CoreData
import SwiftyJSON

class SaveViewController: UIViewController {
    
    var album = [AlbumItem]()
    
    let managedObjectContext = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
    
    var image : UIImage?
    var track : JSON?
    var artist : JSON?
    var savedimage : NSData?
    
    var keyboardOpen : Bool = false
    
    @IBOutlet weak var instatuneImage: UIImageView!
    @IBOutlet weak var SongInfo: UILabel!
    @IBOutlet weak var titleField: UITextField!
    @IBOutlet weak var descField: UITextField!
    
    weak var delegate: SaveViewControllerDelegate?
    
    // PLAYER DECLARATIONS //
    
//    var auth = SPTAuth.defaultInstance()
//    var session : SPTSession!
//    var player: SPTAudioStreamingController?
//    var loginUrl: URL?
    
    @IBAction func exitSave(_ sender: UIBarButtonItem) {
        delegate?.exitSaveButton(by: self)
    }
    
    override func viewDidLoad() {
        instatuneImage.image = image
        fetchAlbum()
        super.viewDidLoad()
        if let trackname = track!["name"].string {
            if let artistname = artist!["name"].string {
                SongInfo.text?.append(artistname)
                SongInfo.text?.append(" - ")
                SongInfo.text?.append(trackname)
            }
        }
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(SaveViewController.dismissKeyboard))
        
        //Uncomment the line below if you want the tap not not interfere and cancel other interactions.
        //tap.cancelsTouchesInView = false
        
        view.addGestureRecognizer(tap)
        

        NotificationCenter.default.addObserver(self, selector: #selector(SaveViewController.keyboardWillShow), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(SaveViewController.keyboardWillHide), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        self.savedimage = prepareImageForSaving()
    }
    
    func fetchAlbum() {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName:"AlbumItem")
        do {
            let result = try managedObjectContext.fetch(request)
            album = result as! [AlbumItem]
        }
        catch {
            print("Error fetching album")
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if keyboardOpen == false {
                self.view.frame.origin.y -= keyboardSize.height
                keyboardOpen = true
            }
        }
    }
    
    func keyboardWillHide(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            if keyboardOpen == true {
                self.view.frame.origin.y += keyboardSize.height
                keyboardOpen = false
            }
        }
    }
    
    @IBAction func saveButton(_ sender: UIButton) {
        let newInstatune = NSEntityDescription.insertNewObject(forEntityName: "AlbumItem", into: managedObjectContext) as! AlbumItem
        if let artistname = artist!["name"].string {
            newInstatune.artistname = artistname
        }
        if let songname = track!["name"].string {
            newInstatune.songname = songname
        }
        if let songuri = track!["uri"].string {
            newInstatune.songuri = songuri
        }
        newInstatune.desc = descField.text
        newInstatune.title = titleField.text
        newInstatune.image = self.savedimage
        self.album.append(newInstatune)
        do{
            try managedObjectContext.save()
            let alert = UIAlertController(title: "Instatune saved!", message: nil, preferredStyle: UIAlertControllerStyle.alert)
            let dismiss = UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler:nil)
            alert.addAction(dismiss)
            present(alert, animated: true, completion: nil)
            
        } catch {
            print ("\(error)")
        }
        
        // DO SEGUE HERE
        
    }
    
    func prepareImageForSaving() -> NSData? {
        let prepimage = UIImagePNGRepresentation(self.image!)! as NSData
        return prepimage
    }
}
