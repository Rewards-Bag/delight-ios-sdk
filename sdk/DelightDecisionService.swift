import Foundation

enum DelightDecisionService {
    static func fetchDecision(
        configuration: DelightConfiguration,
        payload: DelightRequestPayload
    ) async throws -> DelightDecisionResponse {
        let endpoint = configuration.apiBaseURL.appendingPathComponent("/sdk/v1/decision")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(configuration.clientId, forHTTPHeaderField: "X-Client-Id")
        request.setValue(configuration.apiKey, forHTTPHeaderField: "X-Api-Key")
        request.httpBody = try JSONEncoder().encode(
            DelightDecisionRequest(
                orderId: payload.orderId,
                email: payload.email,
                firstName: payload.firstName,
                lastName: payload.lastName
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(DelightDecisionResponse.self, from: data)
    }
}
