import Foundation

public extension Double {
  public func rounded(toPlaces places: Int) -> Double {
    let divisor = pow(10.0, Double(places))
    return (self * divisor).rounded() / divisor
  }
}

// Extend the Double type MOVE to extension
extension Double {

    // Convert Double directly to TimeInterval
    public var timeInterval: TimeInterval {
        return TimeInterval(self)
    }

    // Method to get formatted time string from a TimeInterval in seconds
    public func formattedTime() -> String {
        let totalSeconds = Int(self)

        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
