//
//  FixedRoutineEntity+CoreDataProperties.swift
//  sessions
//
//  Created by Mirza Biçer on 9/14/24.
//
//

import Foundation
import CoreData


extension FixedRoutineEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<FixedRoutineEntity> {
        return NSFetchRequest<FixedRoutineEntity>(entityName: "FixedRoutineEntity")
    }

    @NSManaged public var cloudKitRecordID: Data?
    @NSManaged public var flexibility: Double
    @NSManaged public var id: UUID?
    @NSManaged public var recurrence: String?
    @NSManaged public var routineDescription: String?
    @NSManaged public var startTime: Date?
    @NSManaged public var title: String?
    @NSManaged public var tasks: TaskEntity?

}

extension FixedRoutineEntity : Identifiable {

}
