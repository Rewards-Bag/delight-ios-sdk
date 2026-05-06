import Foundation

enum DelightConfigService {
    static func fetchConfig(
        brandName: String,
        cdnBaseURL: URL
    ) async throws -> DelightConfigDTO {
        let normalizedBrand = brandName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let path = "configs/\(normalizedBrand).json"
        let endpoint = cdnBaseURL.appendingPathComponent(path)
        do {
            var request = URLRequest(url: endpoint)
            request.timeoutInterval = 5
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 5
            configuration.timeoutIntervalForResource = 5
            let session = URLSession(configuration: configuration)
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
#if DEBUG
            print("Delight config source: CDN (\(endpoint.absoluteString)) status=\(httpResponse.statusCode)")
#endif
            return try JSONDecoder().decode(DelightConfigDTO.self, from: data)
        } catch {
#if DEBUG
            print("Delight config CDN fetch failed for \(endpoint.absoluteString): \(error.localizedDescription)")
            print("Delight config source: safe-empty fallback (no render)")
#endif
            throw error
        }
    }

    static func loadBundledConfig() throws -> DelightConfigDTO {
        let candidateBundles = uniqueBundles([
            Bundle(for: DelightBundleToken.self),
            Bundle.main
        ] + Bundle.allFrameworks + Bundle.allBundles)

        for bundle in candidateBundles {
            for ext in ["json", "geojson"] {
                if let url = bundle.url(forResource: "config", withExtension: ext)
                    ?? bundle.url(forResource: "config", withExtension: ext, subdirectory: "sdk")
                    ?? bundle.url(forResource: "sdk/config", withExtension: ext) {
                    let data = try Data(contentsOf: url)
                    return try JSONDecoder().decode(DelightConfigDTO.self, from: data)
                }
            }
        }

        throw URLError(.fileDoesNotExist)
    }

    private static func uniqueBundles(_ bundles: [Bundle]) -> [Bundle] {
        var seenPaths = Set<String>()
        var unique: [Bundle] = []
        for bundle in bundles {
            if seenPaths.insert(bundle.bundlePath).inserted {
                unique.append(bundle)
            }
        }
        return unique
    }
}

private final class DelightBundleToken {}
