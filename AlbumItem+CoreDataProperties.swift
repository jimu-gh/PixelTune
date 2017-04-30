//
//  AlbumItem+CoreDataProperties.swift
//  
//
//  Created by Jim on 4/28/17.
//
//

import Foundation
import CoreData


extension AlbumItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<AlbumItem> {
        return NSFetchRequest<AlbumItem>(entityName: "AlbumItem")
    }

    @NSManaged public var title: String?
    @NSManaged public var desc: String?
    @NSManaged public var image: NSData?
    @NSManaged public var artistname: String?
    @NSManaged public var songname: String?
    @NSManaged public var songuri: String?

}
