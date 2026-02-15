import Vapor

extension Response {
    /// Creates an XML response from raw XML string with RSS content type.
    ///
    /// - Parameters:
    ///   - xml: The XML string.
    ///   - status: HTTP status code. Defaults to `.ok`.
    /// - Returns: A configured `Response` with `application/rss+xml; charset=utf-8` content type.
    public static func xml(_ xml: String, status: HTTPStatus = .ok) -> Response {
        let response = Response(status: status)
        response.headers.contentType = HTTPMediaType(
            type: "application", subType: "rss+xml", parameters: ["charset": "utf-8"]
        )
        response.body = .init(string: xml)
        return response
    }
}
