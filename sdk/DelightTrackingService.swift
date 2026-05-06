import Foundation

enum DelightTrackingService {
    private static let fallbackAPIBaseURL = URL(string: "https://api.rewardsbag.com")!

    struct RewardClaimRequest: Encodable {
        let partnerId: String
        let brandName: String
        let customerEmail: String
        let orderReward: String
        let orderId: String
    }

    struct RewardImpressionRequest: Encodable {
        let hostPartnerId: String
        let rewardId: String
        let impressionCount: Int
    }

    static func trackRewardClaim(
        request: RewardClaimRequest,
        apiBaseURLString: String?,
        partnerIdHeader: String?
    ) async throws {
        try await postWithRetryOnTimeout(
            path: "/campaigns/rewardClaim",
            body: request,
            apiBaseURLString: apiBaseURLString,
            partnerIdHeader: partnerIdHeader,
            timeoutInterval: 5,
            retryCount: 0
        )
    }

    static func trackRewardImpression(
        request: RewardImpressionRequest,
        apiBaseURLString: String?,
        partnerIdHeader: String?
    ) async throws {
        try await post(
            path: "/campaigns/rewardTrackImpression",
            body: request,
            apiBaseURLString: apiBaseURLString,
            partnerIdHeader: partnerIdHeader,
            timeoutInterval: 10
        )
    }

    private static func postWithRetryOnTimeout<T: Encodable>(
        path: String,
        body: T,
        apiBaseURLString: String?,
        partnerIdHeader: String?,
        timeoutInterval: TimeInterval,
        retryCount: Int
    ) async throws {
        do {
            try await post(
                path: path,
                body: body,
                apiBaseURLString: apiBaseURLString,
                partnerIdHeader: partnerIdHeader,
                timeoutInterval: timeoutInterval
            )
        } catch {
            guard retryCount > 0, isTimeout(error) else {
                throw error
            }
            try await postWithRetryOnTimeout(
                path: path,
                body: body,
                apiBaseURLString: apiBaseURLString,
                partnerIdHeader: partnerIdHeader,
                timeoutInterval: timeoutInterval,
                retryCount: retryCount - 1
            )
        }
    }

    private static func post<T: Encodable>(
        path: String,
        body: T,
        apiBaseURLString: String?,
        partnerIdHeader: String?,
        timeoutInterval: TimeInterval
    ) async throws {
        let baseURL = URL(string: apiBaseURLString ?? "") ?? fallbackAPIBaseURL
        let endpoint = baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")))

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutInterval
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let partnerIdHeader, !partnerIdHeader.isEmpty {
            request.setValue(partnerIdHeader, forHTTPHeaderField: "X-Partner-ID")
        }
        request.httpBody = try JSONEncoder().encode(body)

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeoutInterval
        configuration.timeoutIntervalForResource = timeoutInterval
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseText = String(data: data, encoding: .utf8) ?? "<non-utf8 response body>"
            throw NSError(
                domain: "DelightTrackingService",
                code: httpResponse.statusCode,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "HTTP \(httpResponse.statusCode) for \(path). Body: \(responseText)"
                ]
            )
        }
    }

    private static func isTimeout(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            return urlError.code == .timedOut
        }
        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorTimedOut
    }
}

