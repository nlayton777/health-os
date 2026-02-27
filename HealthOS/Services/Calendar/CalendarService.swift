import Foundation
import EventKit

// MARK: - Protocol

protocol CalendarServiceProtocol {
    /// Request EventKit authorization.
    func requestAuthorization() async throws -> Bool

    /// Current EventKit authorization status.
    var isAuthorized: Bool { get }

    /// Fetch calendar events for a given date.
    func fetchEvents(for date: Date) async throws -> [CalendarEvent]

    /// Detect free windows between wakeTime and sleepTime on a given date,
    /// excluding calendar events.
    func fetchFreeWindows(for date: Date, wakeTime: Date, sleepTime: Date) async throws -> [TimeWindow]
}

// MARK: - Value Types

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let calendarName: String
}

struct TimeWindow: Identifiable {
    let id: String
    let startDate: Date
    let endDate: Date
    let durationMinutes: Int
}

// MARK: - Implementation

@Observable
final class CalendarService: CalendarServiceProtocol {

    static let shared = CalendarService()

    private let store = EKEventStore()
    private(set) var isAuthorized = false

    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async throws -> Bool {
        if #available(iOS 17.0, *) {
            let granted = try await store.requestFullAccessToEvents()
            isAuthorized = granted
            return granted
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                store.requestAccess(to: .event) { [weak self] granted, error in
                    if let error { continuation.resume(throwing: error); return }
                    self?.isAuthorized = granted
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    // MARK: - Fetch Events

    func fetchEvents(for date: Date) async throws -> [CalendarEvent] {
        guard isAuthorized else { throw CalendarServiceError.notAuthorized }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents
            .filter { !$0.isDeclined }
            .map { event in
                CalendarEvent(
                    id: event.eventIdentifier ?? UUID().uuidString,
                    title: event.title ?? "Untitled",
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    calendarName: event.calendar?.title ?? "Unknown"
                )
            }
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Fetch Free Windows

    func fetchFreeWindows(for date: Date, wakeTime: Date, sleepTime: Date) async throws -> [TimeWindow] {
        let events = try await fetchEvents(for: date)

        // Build busy intervals from non-all-day events
        let busyIntervals = events
            .filter { !$0.isAllDay }
            .map { ($0.startDate, $0.endDate) }
            .sorted { $0.0 < $1.0 }

        var windows: [TimeWindow] = []
        var cursor = wakeTime

        for (busyStart, busyEnd) in busyIntervals {
            // Clamp to the wake–sleep range
            guard busyStart < sleepTime, busyEnd > wakeTime else { continue }
            let clampedStart = max(busyStart, wakeTime)

            if cursor < clampedStart {
                let windowEnd = min(clampedStart, sleepTime)
                let duration = Int(windowEnd.timeIntervalSince(cursor) / 60)
                if duration > 0 {
                    windows.append(TimeWindow(
                        id: UUID().uuidString,
                        startDate: cursor,
                        endDate: windowEnd,
                        durationMinutes: duration
                    ))
                }
            }
            cursor = max(cursor, min(busyEnd, sleepTime))
        }

        // Remaining window after the last event
        if cursor < sleepTime {
            let duration = Int(sleepTime.timeIntervalSince(cursor) / 60)
            if duration > 0 {
                windows.append(TimeWindow(
                    id: UUID().uuidString,
                    startDate: cursor,
                    endDate: sleepTime,
                    durationMinutes: duration
                ))
            }
        }

        return windows
    }
}

// MARK: - EKEvent Helpers

private extension EKEvent {
    var isDeclined: Bool {
        guard let attendees = attendees else { return false }
        return attendees.contains {
            $0.isCurrentUser && $0.participantStatus == .declined
        }
    }
}

// MARK: - Errors

enum CalendarServiceError: LocalizedError {
    case notAuthorized

    var errorDescription: String? {
        switch self {
        case .notAuthorized: return "Calendar access has not been granted."
        }
    }
}
