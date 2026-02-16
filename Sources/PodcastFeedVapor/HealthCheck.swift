import Vapor

/// Health check response payload.
public struct HealthResponse: Content, Sendable {
    /// Service status ("ok" or "degraded").
    public let status: String
    /// Library version.
    public let version: String
    /// Server uptime in seconds.
    public let uptime: Int
}

/// Registers a health check endpoint for monitoring and load balancers.
extension Application {
    /// Registers a health check endpoint that returns service status, version, and uptime.
    ///
    /// ```swift
    /// app.healthCheck()
    /// // GET /health → {"status":"ok","version":"0.2.0","uptime":3600}
    /// ```
    ///
    /// - Parameter path: The route path for the health endpoint. Defaults to `"health"`.
    public func healthCheck(path: String = "health") {
        let startTime = Date()

        self.get(PathComponent(stringLiteral: path)) { _ -> HealthResponse in
            let uptime = Int(Date().timeIntervalSince(startTime))
            return HealthResponse(
                status: "ok",
                version: "0.2.0",
                uptime: uptime
            )
        }
    }
}
