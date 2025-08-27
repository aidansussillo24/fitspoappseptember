//
//  ZoomableAsyncImage.swift
//  FitSpo
//
//  Pinch‑to‑zoom image view used in PostDetailView.
//

import SwiftUI
import UIKit

struct ZoomableAsyncImage: UIViewRepresentable {
    let url: URL
    @Binding var aspectRatio: CGFloat?      // kept for API compatibility, no longer used for constraints

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate                        = context.coordinator
        scroll.maximumZoomScale                = 4
        scroll.minimumZoomScale                = 1
        scroll.bouncesZoom                     = true
        scroll.showsHorizontalScrollIndicator  = false
        scroll.showsVerticalScrollIndicator    = false
        scroll.clipsToBounds                   = true

        // AsyncImage hosted inside the scroll‑view
        let host = UIHostingController(rootView:
            AsyncImage(url: url) { phase in
                switch phase {
                case .empty:
                    ZStack { Color.gray.opacity(0.2); ProgressView() }
                case .success(let img):
                    img.resizable().scaledToFill()  // fill the container; container size is fixed by parent
                default:
                    ZStack {
                        Color.gray.opacity(0.2)
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        )
        host.view.backgroundColor              = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(host.view)

        // Pin to scroll bounds; width and height follow scroll bounds (no dynamic ratio)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scroll.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scroll.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scroll.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scroll.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scroll.widthAnchor),
            host.view.heightAnchor.constraint(equalTo: scroll.heightAnchor)
        ])

        context.coordinator.zoomView = host.view
        return scroll
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {}

    // MARK: – Coordinator --------------------------------------------------
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableAsyncImage
        weak var zoomView: UIView?

        init(_ parent: ZoomableAsyncImage) { self.parent = parent }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { zoomView }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            guard let v = zoomView else { return }
            let b = scrollView.bounds.size
            var f = v.frame
            f.origin.x = f.width  < b.width  ? (b.width  - f.width ) / 2 : 0
            f.origin.y = f.height < b.height ? (b.height - f.height) / 2 : 0
            v.frame = f
        }
    }
}
