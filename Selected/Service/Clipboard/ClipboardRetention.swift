import Foundation

extension ClipboardHistoryTime {
    func cutoffDate(relativeTo date: Date, calendar: Calendar) -> Date {
        let component: Calendar.Component
        let value: Int
        switch self {
        case .OneDay: (component, value) = (.hour, -24)
        case .SevenDays: (component, value) = (.day, -7)
        case .ThirtyDays: (component, value) = (.day, -30)
        case .ThreeMonths: (component, value) = (.month, -3)
        case .SixMonths: (component, value) = (.month, -6)
        case .OneYear: (component, value) = (.year, -1)
        }
        return calendar.date(byAdding: component, value: value, to: date)!
    }
}
