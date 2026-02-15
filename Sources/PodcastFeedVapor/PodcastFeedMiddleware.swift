import Vapor

/// Middleware that adds podcast feed headers to responses.
///
/// When registered globally, this middleware adds the `X-Generator` header
/// and ensures proper cache headers on all responses that have an RSS content type.
///
/// ```swift
/// app.middleware.use(PodcastFeedMiddleware())
/// ```
public struct PodcastFeedMiddleware: AsyncMiddleware, Sendable {

    /// Creates a new podcast feed middleware.
    public init() {}

    /// Processes the request through the middleware chain, adding feed headers to RSS responses.
    ///
    /// - Parameters:
    ///   - request: The incoming request.
    ///   - next: The next responder in the chain.
    /// - Returns: The response, potentially with added feed headers.
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        let response = try await next.respond(to: request)
        let config = request.application.feedConfiguration

        guard let contentType = response.headers.contentType,
            contentType.subType.contains("rss") || contentType.subType.contains("xml")
        else {
            return response
        }

        if let generatorName = config.generatorHeader,
            !response.headers.contains(name: "X-Generator")
        {
            response.headers.add(name: "X-Generator", value: generatorName)
        }

        return response
    }
}
