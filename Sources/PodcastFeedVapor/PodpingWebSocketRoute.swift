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

extension Application {
    /// The Podping WebSocket manager for this application.
    ///
    /// Used to broadcast feed update notifications to connected WebSocket clients.
    ///
    /// ```swift
    /// // Broadcast a feed update
    /// await app.podpingWebSocketManager.broadcast(
    ///     feedURL: "https://example.com/feed.xml",
    ///     reason: .update
    /// )
    /// ```
    public var podpingWebSocketManager: PodpingWebSocketManager {
        get {
            if let existing = self.storage[PodpingWebSocketManagerKey.self] {
                return existing
            }
            let manager = PodpingWebSocketManager()
            self.storage[PodpingWebSocketManagerKey.self] = manager
            return manager
        }
        set { self.storage[PodpingWebSocketManagerKey.self] = newValue }
    }

    private struct PodpingWebSocketManagerKey: StorageKey {
        typealias Value = PodpingWebSocketManager
    }
}

extension Application {
    /// Registers a WebSocket endpoint for real-time Podping notifications.
    ///
    /// Clients connect via WebSocket and receive JSON notifications when
    /// feeds are updated via ``PodpingWebSocketManager/broadcast(feedURL:reason:medium:)``.
    ///
    /// ```swift
    /// // Register endpoint at ws://host/podping
    /// app.podpingWebSocket("podping")
    ///
    /// // Later, broadcast a feed update
    /// await app.podpingWebSocketManager.broadcast(
    ///     feedURL: "https://example.com/feed.xml"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - path: One or more path components for the WebSocket route.
    ///     Defaults to `"podping"`.
    ///   - manager: The WebSocket manager to use. Defaults to the
    ///     application's shared ``podpingWebSocketManager``.
    public func podpingWebSocket(
        _ path: PathComponent...,
        manager: PodpingWebSocketManager? = nil
    ) {
        let resolvedPath = path.isEmpty ? [PathComponent("podping")] : path
        let resolvedManager = manager ?? self.podpingWebSocketManager

        self.webSocket(resolvedPath) { _, ws async in
            await resolvedManager.addConnection(ws)
        }
    }
}
