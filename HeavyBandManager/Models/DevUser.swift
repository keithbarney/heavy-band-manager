import SwiftUI

struct DevUser: Identifiable {
    let id = UUID()
    let email: String
    let password: String
    let name: String
    let instrument: String
    let emoji: String
    let role: String
    let color: Color
}

#if DEBUG
let devUsers: [DevUser] = [
    DevUser(email: "james@18v.test", password: "devpass123", name: "James", instrument: "Vocals", emoji: "🎤", role: "Member", color: .red),
    DevUser(email: "matt@18v.test", password: "devpass123", name: "Matt Horwitz", instrument: "Drums", emoji: "🥁", role: "Member", color: .cyan),
    DevUser(email: "dan@18v.test", password: "devpass123", name: "Dan Smith", instrument: "Bass", emoji: "🎸", role: "Member", color: .yellow),
]
#endif
