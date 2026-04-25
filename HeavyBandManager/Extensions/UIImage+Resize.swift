import UIKit

extension UIImage {
    func resized(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        guard max(size.width, size.height) > maxDimension else { return self }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}
