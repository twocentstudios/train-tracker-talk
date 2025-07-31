import CoreMotion
import Foundation
import SwiftUI

enum MotionActivityFormatters {
    static func confidenceText(_ confidence: MotionActivityConfidence) -> String {
        switch confidence {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }

    static func activityTypes(_ activity: MotionActivity) -> AttributedString {
        var items: [(String, Color)] = []
        if activity.stationary { items.append(("Stationary", .red)) }
        if activity.walking { items.append(("Walking", .green)) }
        if activity.running { items.append(("Running", .orange)) }
        if activity.automotive { items.append(("Automotive", .blue)) }
        if activity.cycling { items.append(("Cycling", .purple)) }
        if activity.unknown { items.append(("Unknown", .yellow)) }
        if items.isEmpty { items = [("None", .secondary)] }

        var result = AttributedString()
        for (index, item) in items.enumerated() {
            var attr = AttributedString(item.0)
            attr.foregroundColor = item.1
            result += attr
            if index < items.count - 1 {
                result += AttributedString(", ")
            }
        }
        return result
    }

    static func colorForActivityType(_ type: String) -> Color {
        switch type {
        case "Stationary": .red
        case "Walking": .green
        case "Running": .orange
        case "Automotive": .blue
        case "Cycling": .purple
        case "Unknown": .yellow
        default: .secondary
        }
    }

    static func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    static func formatTimeRange(start: Date, end: Date) -> String {
        let formatter = DateFormatter()

        // Check if dates are on the same day
        if Calendar.current.isDate(start, inSameDayAs: end) {
            formatter.dateFormat = "MMM d, h:mm a"
            let startString = formatter.string(from: start)
            formatter.dateFormat = "h:mm a"
            let endString = formatter.string(from: end)
            return "\(startString) - \(endString)"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
            let startString = formatter.string(from: start)
            let endString = formatter.string(from: end)
            return "\(startString) - \(endString)"
        }
    }
}
