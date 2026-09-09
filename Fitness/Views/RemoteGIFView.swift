import SwiftUI
import UIKit
import ImageIO

struct RemoteGIFView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.clipsToBounds = true
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        context.coordinator.load(url, into: view)
    }

    static func dismantleUIView(_ view: UIImageView, coordinator: Coordinator) {
        coordinator.task?.cancel()
    }

    final class Coordinator {
        static let cache = NSCache<NSURL, UIImage>()
        var currentURL: URL?
        var task: Task<Void, Never>?

        @MainActor
        func load(_ url: URL, into view: UIImageView) {
            guard currentURL != url else { return }
            currentURL = url
            task?.cancel()
            view.image = nil

            if let cached = Self.cache.object(forKey: url as NSURL) {
                view.image = cached
                return
            }

            task = Task { @MainActor in
                do {
                    var request = URLRequest(url: url)
                    request.cachePolicy = .returnCacheDataElseLoad
                    request.timeoutInterval = 20
                    let (data, response) = try await URLSession.shared.data(for: request)
                    guard !Task.isCancelled,
                          let http = response as? HTTPURLResponse,
                          (200...299).contains(http.statusCode),
                          let image = Self.animatedImage(data: data) else { return }
                    Self.cache.setObject(image, forKey: url as NSURL)
                    view.image = image
                } catch {
                    // The surrounding card keeps a clear fallback when the external source is unavailable.
                }
            }
        }

        private static func animatedImage(data: Data) -> UIImage? {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
            let count = CGImageSourceGetCount(source)
            guard count > 1 else { return UIImage(data: data) }
            var images: [UIImage] = []
            var duration = 0.0
            for index in 0..<count {
                guard let frame = CGImageSourceCreateImageAtIndex(source, index, nil) else { continue }
                images.append(UIImage(cgImage: frame))
                let properties = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [String: Any]
                let gif = properties?[kCGImagePropertyGIFDictionary as String] as? [String: Any]
                let delay = gif?[kCGImagePropertyGIFUnclampedDelayTime as String] as? Double
                    ?? gif?[kCGImagePropertyGIFDelayTime as String] as? Double
                    ?? 0.1
                duration += max(0.02, delay)
            }
            return images.isEmpty ? nil : UIImage.animatedImage(with: images, duration: duration)
        }
    }
}

struct GIFDemoCard: View {
    let url: URL

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(Palette.accent.opacity(0.06))
            ProgressView().tint(Palette.accent)
            RemoteGIFView(url: url).padding(8)
        }
        .frame(maxWidth: .infinity, minHeight: 230, maxHeight: 260)
        .overlay(alignment: .topTrailing) {
            Text("联网演示")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 9).padding(.vertical, 6)
                .foregroundStyle(Palette.accent)
                .background(.regularMaterial, in: Capsule())
                .padding(10)
        }
        .accessibilityLabel("动作 GIF 联网演示")
    }
}
