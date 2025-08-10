import AppService
import FunctionalViewComponent
import HexColorMacro
import StateGraph
import SwiftData
import SwiftUI
import SwiftUIPersistentControl
import WebKit
import os.lock

struct WebView: UIViewRepresentable {
  let url: URL

  func makeUIView(context: Context) -> WKWebView {
    return WKWebView()
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    let request = URLRequest(url: url)
    webView.load(request)
  }
}
