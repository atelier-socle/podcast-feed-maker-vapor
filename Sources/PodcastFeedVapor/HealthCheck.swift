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
