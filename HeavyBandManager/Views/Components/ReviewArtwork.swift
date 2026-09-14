import SwiftUI

/// Local artwork is available only to the opt-in Simulator review build.
/// Original files remain intact; the avatar viewport selects a caption-identified member.
struct ReviewArtwork {
    let image: UIImage
    let region: CGRect?

    static func resolve(_ value: String?) -> ReviewArtwork? {
        #if DEBUG && targetEnvironment(simulator) && AVAILABILITY_TAB_PREVIEW
        guard ProcessInfo.processInfo.arguments.contains("--screenshot-band=minor-threat"),
              let value, let url = URL(string: value), url.scheme == "mock-artwork" else { return nil }
        let file: String
        let region: CGRect?
        switch url.host {
        case "ian": file = "group.jpg"; region = CGRect(x: 605, y: 365, width: 295, height: 295)
        case "lyle": file = "group.jpg"; region = CGRect(x: 145, y: 0, width: 240, height: 240)
        case "brian": file = "porch.png"; region = CGRect(x: 647, y: 341, width: 127, height: 127)
        case "jeff": file = "porch.png"; region = CGRect(x: 307, y: 354, width: 121, height: 121)
        case "logo": file = "logo.png"; region = nil
        default: return nil
        }
        guard let path = Bundle.main.path(forResource: file, ofType: nil, inDirectory: "MockArtwork"),
              let image = UIImage(contentsOfFile: path) else { return nil }
        return ReviewArtwork(image: image, region: region)
        #else
        return nil
        #endif
    }
}

struct ReviewArtworkView: View {
    let artwork: ReviewArtwork
    let size: CGFloat

    var body: some View {
        Group {
            if let region = artwork.region {
                let scale = size / region.width
                Color.clear
                    .overlay(alignment: .topLeading) {
                        Image(uiImage: artwork.image)
                            .resizable()
                            .frame(width: artwork.image.size.width * scale, height: artwork.image.size.height * scale)
                            .offset(x: -region.minX * scale, y: -region.minY * scale)
                    }
            } else {
                Color.white.overlay {
                    Image(uiImage: artwork.image).resizable().scaledToFit().padding(size * 0.12)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(artwork.region == nil ? "Band logo" : "Member photo")
    }
}

struct BandLogoImage: View {
    let url: URL
    var size: CGFloat = 36

    var body: some View {
        if let artwork = ReviewArtwork.resolve(url.absoluteString) {
            ReviewArtworkView(artwork: artwork, size: size)
                .accessibilityIdentifier("band-logo-photo")
        } else {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
        }
    }
}
