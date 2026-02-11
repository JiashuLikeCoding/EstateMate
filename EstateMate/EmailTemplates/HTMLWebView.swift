import SwiftUI
import WebKit

struct HTMLWebView: UIViewRepresentable {
    let html: String
    var baseURL: URL? = nil

    func makeUIView(context: Context) -> WKWebView {
        let v = WKWebView(frame: .zero)
        v.isOpaque = false
        v.backgroundColor = .clear
        v.scrollView.backgroundColor = .clear
        v.scrollView.contentInsetAdjustmentBehavior = .never
        return v
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(html, baseURL: baseURL)
    }
}
