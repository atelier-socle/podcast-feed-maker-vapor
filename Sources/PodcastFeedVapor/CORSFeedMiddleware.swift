// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2026 Atelier Socle SAS
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Vapor

/// CORS middleware for podcast feed endpoints.
///
/// Configures Cross-Origin Resource Sharing headers for feed API endpoints.
/// This is useful when feeds are consumed by web-based podcast players or
/// third-party applications via JavaScript.
///
/// ```swift
/// // Allow all origins (development)
/// app.middleware.use(CORSFeedMiddleware())
///
/// // Restrict to specific origins (production)
/// app.middleware.use(CORSFeedMiddleware(
///     allowedOrigins: ["https://myapp.com", "https://player.myapp.com"],
///     allowedMethods: [.GET, .HEAD, .OPTIONS]
/// ))
/// ```
public struct CORSFeedMiddleware: AsyncMiddleware, Sendable {
    /// Allowed origins. Use `["*"]` for wildcard (allow all).
    private let allowedOrigins: [String]

    /// Allowed HTTP methods.
    private let allowedMethods: [HTTPMethod]

    /// Allowed headers in requests.
    private let allowedHeaders: [String]

    /// Whether to include credentials (cookies, auth headers).
    private let allowCredentials: Bool

    /// Max age for preflight cache (seconds).
    private let maxAge: Int

    /// Creates a new CORS middleware for feed endpoints.
    ///
    /// - Parameters:
    ///   - allowedOrigins: Origins to allow. Defaults to `["*"]` (all origins).
    ///   - allowedMethods: HTTP methods to allow. Defaults to GET, HEAD, OPTIONS.
    ///   - allowedHeaders: Headers to allow. Defaults to Accept, Content-Type, If-None-Match, If-Modified-Since.
    ///   - allowCredentials: Whether to allow credentials. Defaults to `false`.
    ///   - maxAge: Preflight cache duration in seconds. Defaults to 86400 (24h).
    public init(
        allowedOrigins: [String] = ["*"],
        allowedMethods: [HTTPMethod] = [.GET, .HEAD, .OPTIONS],
        allowedHeaders: [String] = ["Accept", "Content-Type", "If-None-Match", "If-Modified-Since"],
        allowCredentials: Bool = false,
        maxAge: Int = 86400
    ) {
        self.allowedOrigins = allowedOrigins
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.allowCredentials = allowCredentials
        self.maxAge = maxAge
    }

    /// Processes the request, adding CORS headers and handling preflight requests.
    ///
    /// - Parameters:
    ///   - request: The incoming request.
    ///   - next: The next responder in the chain.
    /// - Returns: The response with CORS headers.
    public func respond(to request: Request, chainingTo next: any AsyncResponder) async throws -> Response {
        if request.method == .OPTIONS {
            let response = Response(status: .noContent)
            addCORSHeaders(to: response, for: request)
            return response
        }

        let response = try await next.respond(to: request)
        addCORSHeaders(to: response, for: request)
        return response
    }

    /// Adds CORS headers to a response based on the request's origin.
    ///
    /// - Parameters:
    ///   - response: The response to modify.
    ///   - request: The incoming request containing the Origin header.
    private func addCORSHeaders(to response: Response, for request: Request) {
        let origin = request.headers.first(name: .origin) ?? "*"

        if allowedOrigins.contains("*") {
            response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: "*")
        } else if allowedOrigins.contains(origin) {
            response.headers.replaceOrAdd(name: .accessControlAllowOrigin, value: origin)
            response.headers.add(name: "Vary", value: "Origin")
        }

        let methods = allowedMethods.map(\.rawValue).joined(separator: ", ")
        response.headers.replaceOrAdd(name: .accessControlAllowMethods, value: methods)

        let headers = allowedHeaders.joined(separator: ", ")
        response.headers.replaceOrAdd(name: .accessControlAllowHeaders, value: headers)

        if allowCredentials {
            response.headers.replaceOrAdd(
                name: .accessControlAllowCredentials,
                value: "true"
            )
        }

        response.headers.replaceOrAdd(name: .accessControlMaxAge, value: "\(maxAge)")
    }
}
