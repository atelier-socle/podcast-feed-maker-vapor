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
