import SwiftUI

extension Font {
    // Display — greeting name
    static let display = Font.custom("DMSans-ExtraBold", size: 30, relativeTo: .largeTitle)
    // Title Large — detail headers
    static let titleLG = Font.custom("DMSans-ExtraBold", size: 26, relativeTo: .title)
    // Title — section headers
    static let titleMD = Font.custom("DMSans-Bold", size: 20, relativeTo: .headline)
    // Body — emphasized text
    static let bodyEmphasis = Font.custom("DMSans-SemiBold", size: 17, relativeTo: .body)
    // Body SM — inputs, descriptions
    static let bodySM = Font.custom("DMSans-Medium", size: 16, relativeTo: .subheadline)
    // Caption — addresses, timestamps
    static let caption = Font.custom("DMSans-Medium", size: 15, relativeTo: .caption)
    // Caption SM — badges, helper text
    static let captionSM = Font.custom("DMSans-SemiBold", size: 15, relativeTo: .caption2)
    // Micro — tab bar labels
    static let micro = Font.custom("DMSans-SemiBold", size: 12, relativeTo: .caption2)
    // Price Large — task payout
    static let priceLG = Font.custom("DMSans-ExtraBold", size: 40, relativeTo: .largeTitle)
    // Price — earnings summary
    static let priceMD = Font.custom("DMSans-ExtraBold", size: 36, relativeTo: .largeTitle)
    // Price Small — inline task price
    static let priceSM = Font.custom("DMSans-ExtraBold", size: 20, relativeTo: .headline)

    // Task Detail — card title
    static let taskName = Font.custom("DMSans-ExtraBold", size: 17, relativeTo: .body)
    // Task Detail — field labels (uppercase)
    static let detailLabel = Font.custom("DMSans-Bold", size: 9, relativeTo: .caption2)
    // Task Detail — field values
    static let detailValue = Font.custom("DMSans-SemiBold", size: 12, relativeTo: .caption2)
    // Task Detail — stat chip value
    static let chipValue = Font.custom("DMSans-ExtraBold", size: 15, relativeTo: .caption)
    // Task Detail — stat chip label
    static let chipLabel = Font.custom("DMSans-SemiBold", size: 9, relativeTo: .caption2)
    // Task Detail — payment section label (uppercase)
    static let payLabel = Font.custom("DMSans-Bold", size: 9.5, relativeTo: .caption2)
    // Task Detail — payment amount
    static let payAmount = Font.custom("DMSans-Bold", size: 12, relativeTo: .caption2)
    // Task Detail — payment total
    static let payTotal = Font.custom("DMSans-ExtraBold", size: 17, relativeTo: .body)
    // Task Detail — runner name
    static let runnerName = Font.custom("DMSans-Bold", size: 13, relativeTo: .caption)
    // Task Detail — runner timestamp
    static let runnerTime = Font.custom("DMSans-Medium", size: 10.5, relativeTo: .caption2)
    // Task Detail — live counter number
    static let liveCount = Font.custom("DMSans-ExtraBold", size: 32, relativeTo: .largeTitle)
    // Task Detail — price in hero card
    static let priceHero = Font.custom("DMSans-ExtraBold", size: 19, relativeTo: .headline)
}

// Fallback: use system font if DM Sans not available
extension Font {
    static let displayFallback = Font.system(size: 30, weight: .heavy)
    static let titleLGFallback = Font.system(size: 26, weight: .heavy)
    static let titleMDFallback = Font.system(size: 20, weight: .bold)
    static let bodyEmphasisFallback = Font.system(size: 17, weight: .semibold)
    static let bodySMFallback = Font.system(size: 16, weight: .medium)
}
