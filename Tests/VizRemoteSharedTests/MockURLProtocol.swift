import Foundation

/// Intercepts every request made through a `URLSession` configured with this protocol,
/// so `RealSmartCastClient`'s actual HTTP request shape (method, path, JSON body) and
/// response-parsing logic can be verified without ever touching a real TV.
final class MockURLProtocol: URLProtocol {
    struct StubResponse {
        let statusCode: Int
        let jsonBody: [String: Any]?
        let rawBody: Data?

        static func json(_ body: [String: Any], statusCode: Int = 200) -> StubResponse {
            StubResponse(statusCode: statusCode, jsonBody: body, rawBody: nil)
        }
        static func raw(_ statusCode: Int, _ data: Data) -> StubResponse {
            StubResponse(statusCode: statusCode, jsonBody: nil, rawBody: data)
        }
    }

    /// One request/response the queue expects next, plus what was actually sent — so
    /// tests can assert on method/path/body after the call completes.
    struct RecordedRequest {
        let method: String
        let path: String
        let bodyJSON: [String: Any]?
    }

    nonisolated(unsafe) static var responseQueue: [StubResponse] = []
    nonisolated(unsafe) static var recordedRequests: [RecordedRequest] = []

    static func reset() {
        responseQueue = []
        recordedRequests = []
    }

    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        var bodyJSON: [String: Any]?
        if let bodyData = request.httpBody ?? request.httpBodyStream.flatMap({ stream -> Data? in
            stream.open()
            defer { stream.close() }
            var data = Data()
            let bufferSize = 4096
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: bufferSize)
                if read > 0 { data.append(buffer, count: read) }
            }
            return data
        }) {
            bodyJSON = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        }

        Self.recordedRequests.append(RecordedRequest(
            method: request.httpMethod ?? "",
            path: request.url?.path ?? "",
            bodyJSON: bodyJSON
        ))

        guard !Self.responseQueue.isEmpty else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        let stub = Self.responseQueue.removeFirst()

        let response = HTTPURLResponse(url: request.url!, statusCode: stub.statusCode, httpVersion: "HTTP/1.1", headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)

        let data = stub.rawBody ?? (stub.jsonBody.map { try! JSONSerialization.data(withJSONObject: $0) }) ?? Data()
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
