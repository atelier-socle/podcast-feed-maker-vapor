import Testing
import VaporTesting

@testable import PodcastFeedVapor

@Suite("Response+XML Extension Tests")
struct ResponseXMLTests {
    @Test("Response.xml creates RSS XML response")
    func xmlResponse() {
        let xml = "<rss><channel><title>Test</title></channel></rss>"
        let response = Response.xml(xml)
        #expect(response.status == .ok)
        let contentType = response.headers.contentType?.serialize() ?? ""
        #expect(contentType.contains("rss+xml"))
        #expect(response.body.string == xml)
    }

    @Test("Response.xml with custom status")
    func xmlResponseCustomStatus() {
        let response = Response.xml("<rss></rss>", status: .notFound)
        #expect(response.status == .notFound)
    }
}
