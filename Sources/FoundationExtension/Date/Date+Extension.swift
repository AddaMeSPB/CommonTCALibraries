//
//  Date+Extension.swift
//  AddaMeIOS
//
//  Created by Saroar Khandoker on 03.09.2020.
//

import Foundation

// temporary
extension String {
    public func toDate()-> Date? {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let date = formatter.date(from: self)
        return date
    }
}

extension Date {
    public func toString() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }
}
// temporary end

extension Date {
  public var toISO8601String: String? {
    ISO8601DateFormatter().string(from: self)
  }

  public func getFormattedDate(format: String) -> String {
    let dateformat = DateFormatter()
    dateformat.locale = Locale.current
    dateformat.dateFormat = format
    return dateformat.string(from: self)
  }

    func toString(format: String = "yyyy-MM-dd") -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.dateFormat = format
        return formatter.string(from: self)
    }


  public var hour: Int {
    let components = Calendar.current.dateComponents([.hour], from: self)
    return components.hour ?? 0
  }

  public var minute: Int {
    let components = Calendar.current.dateComponents([.minute], from: self)
    return components.minute ?? 0
  }

  public var hourMinuteString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: self)
  }

  public var dayMonthYear: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yyyy"
    return formatter.string(from: self)
  }

  public var dateFormatter: String {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale.autoupdatingCurrent

    let timeSinceDateInSconds = Date().timeIntervalSince(self)
    let secondInDay: TimeInterval = 24 * 60 * 60

    if timeSinceDateInSconds > 7 * secondInDay {
      dateFormatter.dateFormat = "MM/dd/yy"
    } else if timeSinceDateInSconds > secondInDay {
      dateFormatter.dateFormat = "EEEE"
    } else {
      dateFormatter.timeStyle = .short
      dateFormatter.string(from: self)
    }

    return dateFormatter.string(from: self)
  }

    public var dateFormatterSimple: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: self)
    }

}

extension Date {
    public func adding(days: Int) -> Date? {
        var dateComponents = DateComponents()
        dateComponents.day = days

        return NSCalendar.current.date(byAdding: dateComponents, to: self)
    }
}

extension Date {
    public func get(_ components: Calendar.Component..., calendar: Calendar = Calendar.current) -> DateComponents {
        return calendar.dateComponents(Set(components), from: self)
    }

    public func get(_ component: Calendar.Component, calendar: Calendar = Calendar.current) -> Int {
        return calendar.component(component, from: self)
    }
}

extension Date {
    public func toLocalTime() -> Date {
        let timezone    = TimeZone.current
        let seconds     = TimeInterval(timezone.secondsFromGMT(for: self))
        return Date(timeInterval: seconds, since: self)
    }
}

extension Date {
    public func minutesCount(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.minute], from: date, to: self).minute ?? 0)
    }

    public func daysCount(from date: Date) -> Int {
        return abs(Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0)
    }
}

extension Date {
    /// Returns a Date with the specified amount of components added to the one it is called with
    public func add(years: Int = 0, months: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
        let components = DateComponents(year: years, month: months, day: days, hour: hours, minute: minutes, second: seconds)
        return Calendar.current.date(byAdding: components, to: self)
    }

    /// Returns a Date with the specified amount of components subtracted from the one it is called with
    public func subtract(years: Int = 0, months: Int = 0, days: Int = 0, hours: Int = 0, minutes: Int = 0, seconds: Int = 0) -> Date? {
        return add(years: -years, months: -months, days: -days, hours: -hours, minutes: -minutes, seconds: -seconds)
    }
}
