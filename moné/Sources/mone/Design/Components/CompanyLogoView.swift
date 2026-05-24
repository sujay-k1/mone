import SwiftUI
import UIKit
import WebKit

struct CompanyLogo: Equatable {
    let url: URL
    let fileName: String

    var isSVG: Bool {
        url.pathExtension.lowercased() == "svg"
    }
}

enum CompanyLogoResolver {
    private static let commonTokens: Set<String> = [
        "logo", "logos", "icon", "app", "main", "mark", "symbol", "standalone",
        "vector", "full", "color", "with", "text", "transparent", "transperant",
        "new", "old", "rounded", "black", "white"
    ]

    private static let queryAliases: [String: [String]] = [
        "gpay": ["Google Pay"],
        "googlepay": ["Google Pay"],
        "amazonpay": ["Amazon Pay"],
        "bhim": ["BHIM"],
        "phonepe": ["PhonePe"],
        "paytmmp": ["Paytm"],
        "hdfc": ["HDFC Bank"],
        "hdfcbank": ["HDFC Bank"],
        "hdfcmutualfund": ["HDFC", "HDFC Bank"],
        "hdfccredila": ["HDFC", "HDFC Bank"],
        "icici": ["ICICI Bank"],
        "icicibank": ["ICICI Bank"],
        "iciciprudentialmf": ["ICICI Prudential Mutual Fund", "ICICI Bank"],
        "axismaxlife": ["Axis Max Life Insurance"],
        "carehealth": ["Care Health Insurance"],
        "npsprotean": ["NPS"],
        "bom": ["Bank of Maharashtra"]
    ]

    fileprivate static let supportedExtensions: Set<String> = ["svg", "png", "jpg", "jpeg"]

    static func logo(for query: String, aliases: [String] = []) -> CompanyLogo? {
        shared.logo(for: query, aliases: aliases)
    }

    private static let shared = CompanyLogoResolverStore()

    fileprivate static func normalized(_ value: String) -> String {
        let decoded = value.removingPercentEncoding ?? value
        let withoutExtension = (decoded as NSString).deletingPathExtension
        let scalars = withoutExtension.unicodeScalars.map { scalar -> Character in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }
        return String(scalars).lowercased()
            .replacingOccurrences(of: "&", with: " and ")
            .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate static func tokens(for value: String) -> [String] {
        normalized(value)
            .split(separator: " ")
            .map(String.init)
            .filter { token in
                token.count > 1 && !commonTokens.contains(token) && Int(token) == nil
            }
    }

    fileprivate static func expandedQueries(for query: String, aliases: [String]) -> [String] {
        let base = [query] + aliases
        let aliasMatches = base.flatMap { value in
            queryAliases[normalized(value).replacingOccurrences(of: " ", with: "")] ?? []
        }
        return Array(Set(base + aliasMatches)).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

private final class CompanyLogoResolverStore {
    private struct IndexedLogo {
        let logo: CompanyLogo
        let normalizedName: String
        let tokens: Set<String>
    }

    private let logos: [IndexedLogo]

    init(bundle: Bundle = .main) {
        self.logos = Self.loadLogos(bundle: bundle)
    }

    func logo(for query: String, aliases: [String]) -> CompanyLogo? {
        let queries = CompanyLogoResolver.expandedQueries(for: query, aliases: aliases)
        let matches = logos.compactMap { indexedLogo -> (logo: CompanyLogo, score: Int)? in
            let matchScore = queries.map { score(indexedLogo, query: $0) }.max() ?? 0
            return matchScore > 0 ? (indexedLogo.logo, matchScore) : nil
        }

        return matches
            .sorted { lhs, rhs in
                if lhs.score != rhs.score { return lhs.score > rhs.score }
                return lhs.logo.fileName.count < rhs.logo.fileName.count
            }
            .first?.logo
    }

    private func score(_ logo: IndexedLogo, query: String) -> Int {
        let normalizedQuery = CompanyLogoResolver.normalized(query)
        let queryTokens = Set(CompanyLogoResolver.tokens(for: query))
        guard !normalizedQuery.isEmpty, !queryTokens.isEmpty else { return 0 }

        var score = logo.tokens.intersection(queryTokens).count * 20

        if logo.normalizedName == normalizedQuery {
            score += 120
        } else if logo.normalizedName.contains(normalizedQuery) {
            score += 80
        } else if normalizedQuery.contains(logo.normalizedName) {
            score += 50
        }

        if queryTokens.isSubset(of: logo.tokens) {
            score += 60
        }

        if logo.logo.url.pathExtension.lowercased() == "png" {
            score += 4
        }

        return score
    }

    private static func loadLogos(bundle: Bundle) -> [IndexedLogo] {
        let urls = logoFileURLs(bundle: bundle)
        var seenPaths: Set<String> = []

        return urls
            .filter { CompanyLogoResolver.supportedExtensions.contains($0.pathExtension.lowercased()) }
            .filter { seenPaths.insert($0.path).inserted }
            .map { url in
                let fileName = url.deletingPathExtension().lastPathComponent
                return IndexedLogo(
                    logo: CompanyLogo(url: url, fileName: fileName),
                    normalizedName: CompanyLogoResolver.normalized(fileName),
                    tokens: Set(CompanyLogoResolver.tokens(for: fileName))
                )
            }
    }

    private static func logoFileURLs(bundle: Bundle) -> [URL] {
        var urls: [URL] = []
        let fileManager = FileManager.default

        for subdirectory in ["company-logos", "Resources/company-logos"] {
            if let folderURL = bundle.url(forResource: subdirectory, withExtension: nil),
               let folderURLs = try? fileManager.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
               ) {
                urls.append(contentsOf: folderURLs)
            }

            for ext in CompanyLogoResolver.supportedExtensions {
                urls.append(contentsOf: bundle.urls(forResourcesWithExtension: ext, subdirectory: subdirectory) ?? [])
            }
        }

        for ext in CompanyLogoResolver.supportedExtensions {
            urls.append(contentsOf: bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? [])
        }

        return urls
    }
}

struct CompanyLogoView: View {
    let query: String
    var aliases: [String] = []
    var fallbackSystemName: String
    var contentMode: ContentMode = .fit
    var padding: CGFloat = 0

    var body: some View {
        Group {
            if let logo = CompanyLogoResolver.logo(for: query, aliases: aliases) {
                logoImage(logo)
            } else {
                Image(systemName: fallbackSystemName)
                    .resizable()
                    .scaledToFit()
            }
        }
        .padding(padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityLabel(Text(query))
    }

    @ViewBuilder
    private func logoImage(_ logo: CompanyLogo) -> some View {
        if logo.isSVG {
            SVGLogoView(url: logo.url)
        } else if let image = UIImage(contentsOfFile: logo.url.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else {
            Image(systemName: fallbackSystemName)
                .resizable()
                .scaledToFit()
        }
    }
}

private struct SVGLogoView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.allowsBackForwardNavigationGestures = false
        webView.isUserInteractionEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        context.coordinator.loadedURL = url

        guard let svg = try? String(contentsOf: url, encoding: .utf8) else {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
            return
        }

        let encodedSVG = Data(svg.utf8).base64EncodedString()
        let html = """
        <!doctype html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: transparent; overflow: hidden; }
                body { display: flex; align-items: center; justify-content: center; }
                img { display: block; width: 100%; height: 100%; object-fit: contain; }
            </style>
        </head>
        <body><img src="data:image/svg+xml;base64,\(encodedSVG)" /></body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}
