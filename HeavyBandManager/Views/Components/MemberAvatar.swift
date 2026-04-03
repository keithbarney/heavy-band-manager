import SwiftUI

struct MemberAvatar: View {
    let member: BandMember
    var size: CGFloat = 36

    var body: some View {
        if let urlString = member.avatarUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                default:
                    initialsCircle
                }
            }
        } else {
            initialsCircle
        }
    }

    private var initialsCircle: some View {
        Circle()
            .fill(Color(hex: member.color))
            .frame(width: size, height: size)
            .overlay(
                Text(String(member.name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            )
    }
}
