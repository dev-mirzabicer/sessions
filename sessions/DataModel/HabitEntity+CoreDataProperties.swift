//
//  HabitEntity+CoreDataProperties.swift
//  sessions
//
//  Created by Mirza Biçer on 9/14/24.
//
//

import Foundation
import CoreData


extension HabitEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<HabitEntity> {
        return NSFetchRequest<HabitEntity>(entityName: "HabitEntity")
    }

    @NSManaged public var cloudKitRecordID: Data?
    @NSManaged public var dueDate: Date?
    @NSManaged public var duration: Double
    @NSManaged public var frequency: String?
    @NSManaged public var goal: Double
    @NSManaged public var goalProgress: Double
    @NSManaged public var habitDescription: String?
    @NSManaged public var id: UUID?
    @NSManaged public var isScheduled: Bool
    @NSManaged public var notes: String?
    @NSManaged public var priority: Int16
    @NSManaged public var project: String?
    @NSManaged public var reminder: Date?
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var scheduledTime: Date?
    @NSManaged public var specificDays: String?
    @NSManaged public var streak: Int16
    @NSManaged public var streakFreezeAvailable: Bool
    @NSManaged public var tags: String?
    @NSManaged public var title: String?

}

extension HabitEntity : Identifiable {

}
