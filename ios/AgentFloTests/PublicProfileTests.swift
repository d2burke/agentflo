import XCTest
@testable import AgentFlo

final class PublicProfileTests: XCTestCase {

    private var decoder: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let str = try container.decode(String.self)
            let formatters: [ISO8601DateFormatter] = {
                let f1 = ISO8601DateFormatter()
                f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let f2 = ISO8601DateFormatter()
                f2.formatOptions = [.withInternetDateTime]
                return [f1, f2]
            }()
            for fmt in formatters {
                if let date = fmt.date(from: str) { return date }
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Bad date: \(str)")
        }
        return d
    }

    // MARK: - AppUser New Fields

    func testAppUserDecodeWithProfileFields() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "role": "runner",
            "email": "runner@example.com",
            "full_name": "John Doe",
            "vetting_status": "approved",
            "headline": "Pro photographer in Austin",
            "specialties": ["photography", "inspection"],
            "profile_slug": "john-doe",
            "is_public_profile_enabled": true,
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(AppUser.self, from: json)
        XCTAssertEqual(user.headline, "Pro photographer in Austin")
        XCTAssertEqual(user.specialties, ["photography", "inspection"])
        XCTAssertEqual(user.profileSlug, "john-doe")
        XCTAssertEqual(user.isPublicProfileEnabled, true)
    }

    func testAppUserDecodeWithoutProfileFields() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "role": "agent",
            "email": "agent@example.com",
            "full_name": "Jane Smith",
            "vetting_status": "approved",
            "created_at": "2024-01-15T10:00:00Z",
            "updated_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let user = try decoder.decode(AppUser.self, from: json)
        XCTAssertNil(user.headline)
        XCTAssertNil(user.specialties)
        XCTAssertNil(user.profileSlug)
        XCTAssertNil(user.isPublicProfileEnabled)
    }

    // MARK: - PortfolioImage

    func testPortfolioImageDecoding() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "runner_id": "22222222-2222-2222-2222-222222222222",
            "image_url": "22222222-2222-2222-2222-222222222222/portfolio_0_1704067200.jpg",
            "caption": "Living room staging",
            "sort_order": 0,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let image = try decoder.decode(PortfolioImage.self, from: json)
        XCTAssertEqual(image.runnerId.uuidString.lowercased(), "22222222-2222-2222-2222-222222222222")
        XCTAssertEqual(image.caption, "Living room staging")
        XCTAssertEqual(image.sortOrder, 0)
        XCTAssertTrue(image.imageUrl.contains("portfolio_0"))
    }

    func testPortfolioImageWithoutCaption() throws {
        let json = """
        {
            "id": "11111111-1111-1111-1111-111111111111",
            "runner_id": "22222222-2222-2222-2222-222222222222",
            "image_url": "some/path.jpg",
            "caption": null,
            "sort_order": 3,
            "created_at": "2024-01-15T10:00:00Z"
        }
        """.data(using: .utf8)!

        let image = try decoder.decode(PortfolioImage.self, from: json)
        XCTAssertNil(image.caption)
        XCTAssertEqual(image.sortOrder, 3)
    }

    // MARK: - TaskCategory

    func testTaskCategoryDisplayNames() {
        XCTAssertEqual(TaskCategory.photography.displayName, "Photography")
        XCTAssertEqual(TaskCategory.showing.displayName, "Showing")
        XCTAssertEqual(TaskCategory.staging.displayName, "Staging")
        XCTAssertEqual(TaskCategory.openHouse.displayName, "Open House")
        XCTAssertEqual(TaskCategory.inspection.displayName, "Inspection")
    }

    func testTaskCategoryAllCases() {
        let allCases = TaskCategory.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertTrue(allCases.contains(.photography))
        XCTAssertTrue(allCases.contains(.openHouse))
    }

    // MARK: - Profile Slug Validation

    func testValidSlugs() {
        let regex = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/
        let valid = ["john-doe", "photographer123", "austin-pro", "a1b"]
        for slug in valid {
            XCTAssertNotNil(slug.wholeMatch(of: regex), "'\(slug)' should be valid")
        }
    }

    func testInvalidSlugs() {
        let regex = /^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$/
        let invalid = ["ab", "-start", "end-", "UPPER", "has spaces", "special!char"]
        for slug in invalid {
            XCTAssertNil(slug.wholeMatch(of: regex), "'\(slug)' should be invalid")
        }
    }
}
