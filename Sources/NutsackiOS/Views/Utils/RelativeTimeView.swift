import SwiftUI

struct RelativeTimeView: View {
    let date: Date
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var relativeTimeString: String {
        let interval = currentTime.timeIntervalSince(date)
        
        if interval < 30 {
            return "just now"
        } else if interval < 60 {
            return "\(Int(interval)) seconds ago"
        } else if interval < 120 {
            return "1 minute ago"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) minutes ago"
        } else if interval < 7200 {
            return "1 hour ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hours ago"
        } else if interval < 172800 {
            return "1 day ago"
        } else {
            let days = Int(interval / 86400)
            if days < 30 {
                return "\(days) days ago"
            } else if days < 60 {
                return "1 month ago"
            } else if days < 365 {
                let months = days / 30
                return "\(months) months ago"
            } else {
                let years = days / 365
                return years == 1 ? "1 year ago" : "\(years) years ago"
            }
        }
    }
    
    private var updateInterval: TimeInterval {
        let interval = currentTime.timeIntervalSince(date)
        
        if interval < 60 {
            return 1
        } else if interval < 3600 {
            return 60
        } else if interval < 86400 {
            return 3600
        } else {
            return 86400
        }
    }
    
    var body: some View {
        Text(relativeTimeString)
            .onReceive(timer) { _ in
                let newTime = Date()
                let oldInterval = currentTime.timeIntervalSince(date)
                let newInterval = newTime.timeIntervalSince(date)
                
                let shouldUpdate: Bool
                if oldInterval < 60 && newInterval < 60 {
                    shouldUpdate = true
                } else if oldInterval < 3600 && newInterval < 3600 {
                    shouldUpdate = Int(oldInterval / 60) != Int(newInterval / 60)
                } else if oldInterval < 86400 && newInterval < 86400 {
                    shouldUpdate = Int(oldInterval / 3600) != Int(newInterval / 3600)
                } else {
                    shouldUpdate = Int(oldInterval / 86400) != Int(newInterval / 86400)
                }
                
                if shouldUpdate {
                    currentTime = newTime
                }
            }
            .onAppear {
                currentTime = Date()
            }
    }
}