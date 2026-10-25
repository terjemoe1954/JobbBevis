import SwiftUI
import UIKit

struct AsyncManagedImageView: View {
    let relativePath: String
    let maximumPixelSize: Int
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .clipped()
        .task(id: relativePath) {
            guard let data = await PhotoFileStore().thumbnailData(
                relativePath: relativePath,
                maximumPixelSize: maximumPixelSize
            ) else {
                image = nil
                return
            }
            image = UIImage(data: data)
        }
    }
}
