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

import PodcastFeedMaker
import Vapor

/// Registers a batch audit endpoint that scores multiple feeds in parallel.
///
/// ```swift
/// app.batchAudit("feeds", "audit")
///
/// // GET /feeds/audit?urls=https://a.com/feed.xml,https://b.com/feed.xml
/// // Returns JSON array of audit results with scores, grades, and recommendations
/// ```
extension RoutesBuilder {

    /// Registers a GET endpoint for batch feed auditing.
    ///
    /// Accepts a `urls` query parameter with comma-separated feed URLs.
    /// Each feed is fetched, parsed, and audited in parallel using `FeedAuditor`.
    /// A maximum of 20 URLs can be audited per request.
    ///
    /// - Parameter path: Path components for the endpoint.
    /// - Returns: The registered route.
    @discardableResult
    public func batchAudit(_ path: PathComponent...) -> Route {
        self.on(.GET, path) { request async throws -> [BatchAuditResult] in
            guard let urlsParam: String = request.query["urls"] else {
                throw Abort(.badRequest, reason: "Missing 'urls' query parameter")
            }

            let urls = urlsParam.split(separator: ",").map(String.init)

            guard !urls.isEmpty else {
                throw Abort(.badRequest, reason: "No URLs provided")
            }

            let maxURLs = 20
            let limitedURLs = Array(urls.prefix(maxURLs))

            return try await withThrowingTaskGroup(
                of: BatchAuditResult.self,
                returning: [BatchAuditResult].self
            ) { group in
                for url in limitedURLs {
                    group.addTask {
                        await auditFeed(url: url, client: request.client)
                    }
                }

                var results: [BatchAuditResult] = []
                for try await result in group {
                    results.append(result)
                }
                return results
            }
        }
    }
}

/// Fetches and audits a single feed URL.
///
/// - Parameters:
///   - url: The feed URL to audit.
///   - client: The HTTP client to use for fetching.
/// - Returns: The audit result, or a failure result if fetching/parsing fails.
private func auditFeed(url: String, client: any Client) async -> BatchAuditResult {
    do {
        let response = try await client.get(URI(string: url))

        guard let body = response.body else {
            return .failure(url: url, error: "Empty response body")
        }

        let xmlString = String(buffer: body)
        let parser = FeedParser()
        let feed = try parser.parse(xmlString)
        let auditor = FeedAuditor()
        let report = auditor.audit(feed)

        return BatchAuditResult(
            url: url,
            score: report.score,
            grade: report.grade.rawValue,
            recommendationCount: report.recommendations.count
        )
    } catch {
        return .failure(url: url, error: error.localizedDescription)
    }
}

/// Result of auditing a single feed in a batch operation.
public struct BatchAuditResult: Content, Sendable {
    /// The feed URL that was audited.
    public let url: String

    /// The overall audit score (0-100).
    public let score: Int

    /// The letter grade (A+ to F).
    public let grade: String

    /// Number of recommendations.
    public let recommendationCount: Int

    /// Error message if the feed could not be audited.
    public let error: String?

    /// Creates a new audit result.
    ///
    /// - Parameters:
    ///   - url: The feed URL that was audited.
    ///   - score: The overall audit score (0-100).
    ///   - grade: The letter grade (A+ to F).
    ///   - recommendationCount: Number of recommendations.
    ///   - error: Error message if the feed could not be audited.
    public init(url: String, score: Int, grade: String, recommendationCount: Int, error: String? = nil) {
        self.url = url
        self.score = score
        self.grade = grade
        self.recommendationCount = recommendationCount
        self.error = error
    }

    /// Creates an error result for a feed that could not be audited.
    ///
    /// - Parameters:
    ///   - url: The feed URL that failed.
    ///   - error: Description of the error.
    /// - Returns: A `BatchAuditResult` with score 0 and grade F.
    public static func failure(url: String, error: String) -> BatchAuditResult {
        BatchAuditResult(url: url, score: 0, grade: "F", recommendationCount: 0, error: error)
    }
}
