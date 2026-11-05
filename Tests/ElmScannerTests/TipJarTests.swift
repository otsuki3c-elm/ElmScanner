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
        let jar = TipJar(productID: "com.otsuki.elmscanner.ElmScanner.tip")
        await jar.load()
        XCTAssertEqual(jar.state, .ready)
        XCTAssertEqual(jar.product?.displayPrice, "$0.99")
        await jar.buy { try await $0.purchase() }
        XCTAssertEqual(jar.state, .thanked)
        // A consumable can be bought again: a second tip goes through too.
        await jar.load()
        XCTAssertEqual(jar.state, .ready)
        await jar.buy { try await $0.purchase() }
        XCTAssertEqual(jar.state, .thanked)
        // A cancelled purchase leaves the button available.
        session.failTransactionsEnabled = false
        await jar.load()
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
