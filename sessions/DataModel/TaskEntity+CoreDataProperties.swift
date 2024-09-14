//
//  TaskEntity+CoreDataProperties.swift
//  sessions
//
//  Created by Mirza Biçer on 9/14/24.
//
//

import Foundation
import CoreData


extension TaskEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskEntity> {
        return NSFetchRequest<TaskEntity>(entityName: "TaskEntity")
    }

    @NSManaged public var cloudKitRecordID: Data?
    @NSManaged public var dueDate: Date?
    @NSManaged public var duration: Double
    @NSManaged public var id: UUID?
    @NSManaged public var isScheduled: Bool
    @NSManaged public var priority: Int16
    @NSManaged public var project: String?
    @NSManaged public var reminder: Date?
    @NSManaged public var scheduledTime: Date?
    @NSManaged public var status: String?
    @NSManaged public var tags: String?
    @NSManaged public var taskDescription: String?
    @NSManaged public var title: String?
    @NSManaged public var fixedRoutine: FixedRoutineEntity?

}

extension TaskEntity : Identifiable {

}
