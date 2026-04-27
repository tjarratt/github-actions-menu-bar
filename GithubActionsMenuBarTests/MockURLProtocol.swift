import Foundation

/// A URLProtocol subclass that intercepts outgoing requests during tests.
///
/// Configure per-test by assigning `MockURLProtocol.requestHandler` before
/// making any requests, and clear it in `afterEach` to avoid cross-test leakage.
final class MockURLProtocol: URLProtocol {

    /// Called by each test to supply a stubbed response or error.
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

// MARK: - Factory helpers

extension MockURLProtocol {
    /// Returns a URLSession whose requests are handled by `MockURLProtocol`.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    /// Builds a JSON response from an `Encodable` body.
    static func makeResponse<T: Encodable>(
        url: URL = URL(string: "https://api.github.com")!,
        statusCode: Int = 200,
        body: T
    ) throws -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let data = try JSONEncoder().encode(body)
        return (response, data)
    }

    /// Builds an empty response with the given HTTP status code.
    static func makeResponse(
        url: URL = URL(string: "https://api.github.com")!,
        statusCode: Int
    ) -> (HTTPURLResponse, Data) {
        let response = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, Data())
    }
}
