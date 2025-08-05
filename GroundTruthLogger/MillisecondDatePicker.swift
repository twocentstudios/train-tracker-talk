import SwiftUI

struct MillisecondDatePicker: View {
    @Binding var date: Date

    @State private var baseDate: Date
    @State private var seconds: Int = 0
    @State private var milliseconds: Int = 0

    init(date: Binding<Date>) {
        _date = date
        _baseDate = State(initialValue: date.wrappedValue)

        let calendar = Calendar.current
        let components = calendar.dateComponents([.nanosecond], from: date.wrappedValue)
        let totalMilliseconds = (components.nanosecond ?? 0) / 1_000_000

        _seconds = State(initialValue: calendar.component(.second, from: date.wrappedValue))
        _milliseconds = State(initialValue: totalMilliseconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DatePicker(
                "Date and Time",
                selection: $baseDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)
            .onChange(of: baseDate) { _, newValue in
                updateDate()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Seconds and Milliseconds")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 4) {
                    Picker("Seconds", selection: $seconds) {
                        ForEach(0 ..< 60) { second in
                            Text(String(format: "%02d", second))
                                .tag(second)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80)
                    .clipped()

                    Text(".")
                        .font(.system(.title3, design: .monospaced))

                    Picker("Milliseconds", selection: $milliseconds) {
                        ForEach(0 ..< 1000) { ms in
                            Text(String(format: "%03d", ms))
                                .tag(ms)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 100)
                    .clipped()
                }
                .onChange(of: seconds) { _, _ in
                    updateDate()
                }
                .onChange(of: milliseconds) { _, _ in
                    updateDate()
                }
            }

            Text("Current: \(date.groundTruthFormatted)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func updateDate() {
        let calendar = Calendar.current
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: baseDate
        )
        components.second = seconds
        components.nanosecond = milliseconds * 1_000_000

        if let newDate = calendar.date(from: components) {
            date = newDate
        }
    }
}
