#if canImport(UIKit) && canImport(WebKit)
import SwiftUI
import UIKit
import WebKit
import UniformTypeIdentifiers
import SBJLocalization

public struct SBJHTMLHelpPresenter: SBJHelpContentPresenter {
    public let contentType: UTType = .html

    public init() {}

    @MainActor
    public func makeView(source: String) -> AnyView {
        AnyView(SBJHTMLHelpPresentation(html: source))
    }
}

private enum SBJHelpScrollState {
    case none
    case atTop
    case atBottom
    case scrolling
}

@MainActor
private final class SBJHelpWebViewScroller {
    private(set) weak var webView: WKWebView?

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    func scrollPage(down: Bool) {
        guard let scrollView = webView?.scrollView else { return }
        let pageHeight = scrollView.frame.height
        let maximumY = max(0, scrollView.contentSize.height - scrollView.frame.height)
        let y = down ? min(scrollView.contentOffset.y + pageHeight, maximumY) : 0
        scrollView.setContentOffset(CGPoint(x: 0, y: y), animated: true)
    }
}

@MainActor
private struct SBJHTMLHelpPresentation: View {
    let html: String

    @State private var scrollState: SBJHelpScrollState = .none
    @State private var scroller = SBJHelpWebViewScroller()

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            SBJHTMLHelpView(
                html: html,
                scrollState: $scrollState,
                scroller: scroller
            )

            if scrollState != .none {
                Button {
                    scroller.scrollPage(down: scrollState != .atBottom)
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Color.primary.opacity(0.5))
                            .frame(width: 32, height: 32)
                        Image(symbol: scrollState == .atBottom ? SBJSymbology.scrollToTop : SBJSymbology.scrollPageDown)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.primary.opacity(0.5))
                    }
                    .shadow(radius: 1)
                    .padding(12)
                }
                .accessibilityLabel(scrollState == .atBottom ? "Scroll to top" : "Scroll down one page")
            }
        }
    }
}

private struct SBJHTMLHelpView: UIViewRepresentable {
    let html: String
    @Binding var scrollState: SBJHelpScrollState
    let scroller: SBJHelpWebViewScroller

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastHTML: String?
        var parent: SBJHTMLHelpView

        init(parent: SBJHTMLHelpView) {
            self.parent = parent
        }

		func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
			guard
				navigationAction.navigationType == .linkActivated,
				let url = navigationAction.request.url
			else {
				decisionHandler(.allow)
				return
			}

			switch url.scheme?.lowercased() {
			case "http", "https", "mailto":
				url.open()
				decisionHandler(.cancel)

			default:
				decisionHandler(.allow)
			}
		}

        override func observeValue(
            forKeyPath keyPath: String?,
            of object: Any?,
            change: [NSKeyValueChangeKey: Any]?,
            context: UnsafeMutableRawPointer?
        ) {
            guard
                (keyPath == "contentSize" || keyPath == "frame" || keyPath == "contentOffset"),
                let scrollView = object as? UIScrollView
            else { return }

            DispatchQueue.main.async {
                let offset = scrollView.contentOffset.y
                let height = scrollView.frame.height
                let contentHeight = scrollView.contentSize.height
                let state: SBJHelpScrollState

                if contentHeight <= height + 1 {
                    state = .none
                } else if offset + height >= contentHeight - 1 {
                    state = .atBottom
                } else if offset <= 1 {
                    state = .atTop
                } else {
                    state = .scrolling
                }

                if self.parent.scrollState != state {
                    self.parent.scrollState = state
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.scrollView.addObserver(
            context.coordinator,
            forKeyPath: "contentSize",
            options: [.new, .initial],
            context: nil
        )
        webView.scrollView.addObserver(
            context.coordinator,
            forKeyPath: "frame",
            options: [.new, .initial],
            context: nil
        )
        webView.scrollView.addObserver(
            context.coordinator,
            forKeyPath: "contentOffset",
            options: [.new, .initial],
            context: nil
        )
        scroller.setWebView(webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastHTML != html else { return }
        webView.loadHTMLString(html, baseURL: nil)
        context.coordinator.lastHTML = html
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            webView.scrollView.flashScrollIndicators()
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.scrollView.removeObserver(coordinator, forKeyPath: "contentSize")
        webView.scrollView.removeObserver(coordinator, forKeyPath: "frame")
        webView.scrollView.removeObserver(coordinator, forKeyPath: "contentOffset")
    }
}
#endif
