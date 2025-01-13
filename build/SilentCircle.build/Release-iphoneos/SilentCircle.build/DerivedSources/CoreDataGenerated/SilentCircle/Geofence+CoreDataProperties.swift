//
//  Geofence+CoreDataProperties.swift
//  
//
//  Created by Jorge Larumbe on 1/12/25.
//
//  This file was automatically generated and should not be edited.
//

import Foundation
import CoreData


extension Geofence {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Geofence> {
        return NSFetchRequest<Geofence>(entityName: "Geofence")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var isActive: Bool
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var name: String?
    @NSManaged public var radius: Double

}

extension Geofence : Identifiable {

}
