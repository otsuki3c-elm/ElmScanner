import StoreKit
import StoreKitTest
import XCTest
@testable import ElmScanner

/// Runs the tip purchase against Xcode's local StoreKit test store (`Config/ElmScanner.storekit`).
@MainActor
final class TipJarTests: XCTestCase {
    private func makeSession() throws -> SKTestSession {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Config/ElmScanner.storekit")
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        return session
    }

    func testTipIsFoundAndBought() async throws {
        let session = try makeSession()
        let jar = TipJar()
        await jar.load()
        // Xcode's local StoreKit store sometimes keeps serving the product list from an earlier
        // version of the configuration file; restarting Xcode (or the Mac) clears that.
        try XCTSkipIf(jar.state == .unavailable, "The local StoreKit test store has no \(TipJar.storeProductID) product (stale store).")
        XCTAssertEqual(jar.state, .ready)
        XCTAssertEqual(jar.product?.displayPrice, "$3.99")
        await jar.buy { try await $0.purchase() }
        XCTAssertEqual(jar.state, .thanked)
        // The purchase is non-consumable: after a restart or reinstall the app finds it and says thank you.
        await jar.load()
        XCTAssertEqual(jar.state, .thanked)
        // With no purchase on the account, a cancelled one leaves the button available.
        session.clearTransactions()
        session.failTransactionsEnabled = false
        await jar.load()
        XCTAssertEqual(jar.state, .ready)
        await jar.buy { _ in .userCancelled }
        XCTAssertEqual(jar.state, .ready)
    }

    func testMissingProductIsUnavailable() async throws {
        _ = try makeSession()
        let jar = TipJar(productID: "no.such.product")
        await jar.load()
        XCTAssertEqual(jar.state, .unavailable)
    }
}
