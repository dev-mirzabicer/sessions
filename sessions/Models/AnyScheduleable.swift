import Foundation

struct AnyScheduleable: Scheduleable {
    private let _base: Scheduleable

    var id: UUID {
        get { _base.id }
        set { _base.id = newValue }
    }
    var title: String {
        get { _base.title }
        set { _base.title = newValue }
    }
    var description: String? {
        get { _base.description }
        set { _base.description = newValue }
    }
    var isScheduled: Bool {
        get { _base.isScheduled }
        set { _base.isScheduled = newValue }
    }
    var scheduledDate: Date? {
        get { _base.scheduledDate }
        set { _base.scheduledDate = newValue }
    }
    var scheduledTime: Date? {
        get { _base.scheduledTime }
        set { _base.scheduledTime = newValue }
    }
    var duration: TimeInterval? {
        get { _base.duration }
        set { _base.duration = newValue }
    }
    var priority: Int {
        get { _base.priority }
        set { _base.priority = newValue }
    }
    var dueDate: Date? {
        get { _base.dueDate }
        set { _base.dueDate = newValue }
    }
    var reminder: Date? {
        get { _base.reminder }
        set { _base.reminder = newValue }
    }
    var tags: [String]? {
        get { _base.tags }
        set { _base.tags = newValue }
    }
    var project: String? {
        get { _base.project }
        set { _base.project = newValue }
    }
    var cloudKitRecordID: CKRecord.ID? {
        get { _base.cloudKitRecordID }
        set { _base.cloudKitRecordID = newValue }
    }

    init(_ base: Scheduleable) {
        self._base = base
    }

    func schedule(date: Date, time: Date) throws {
        try _base.schedule(date: date, time: time)
    }

    func reschedule(date: Date, time: Date) throws {
        try _base.reschedule(date: date, time: time)
    }

    func markAsComplete() {
        _base.markAsComplete()
    }
}
