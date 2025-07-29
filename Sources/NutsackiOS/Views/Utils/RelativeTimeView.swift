import SwiftUI
import NDKSwift
import NDKSwiftUI

// Use NDKSwiftUI's relative time component
struct RelativeTimeView: View {
    let date: Date

    var body: some View {
        NDKUIRelativeTime(timestamp: Timestamp(date.timeIntervalSince1970))
    }
}
