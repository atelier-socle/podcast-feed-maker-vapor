import Vapor

/// Registers a health check endpoint for monitoring and load balancers.
extension Application {
    /// Registers a `GET /health` endpoint that returns the service status.
    ///
    /// ```swift
    /// app.healthCheck()
    /// ```
    ///
    /// Response:
    /// ```json
    /// {"status": "ok"}
    /// ```
    ///
    /// - Parameter path: The route path for the health endpoint. Defaults to `"health"`.
    public func healthCheck(path: String = "health") {
        self.get(PathComponent(stringLiteral: path)) { _ in
            ["status": "ok"]
        }
    }
}
