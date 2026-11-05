import Foundation
import Observation
import StoreKit

/// A one-time tip for the developer, sold as a consumable in-app purchase.
/// Nothing in the app depends on it: no feature is locked, and there is nothing to
/// restore, so the app never asks whether a tip was made.
@Observable
@MainActor
final class TipJar {
    static let shared = TipJar()

    enum State: Equatable {
        case loading
        /// No product (not set up in App Store Connect yet, or the store can't be reached).
        case unavailable
        case ready
        case purchasing
        case thanked
        case failed(String)
    }

    private(set) var state: State = .loading
    private(set) var product: Product?
    let productID: String
    @ObservationIgnored private var updates: Task<Void, Never>?

    /// The product is named after the app's own bundle ID, so a fork with a bundle ID of
    /// its own sets up its own product (see the README).
    nonisolated static func productID(bundleID: String?) -> String { (bundleID ?? "ElmScanner") + ".tip" }

    init(productID: String = TipJar.productID(bundleID: Bundle.main.bundleIdentifier)) {
        self.productID = productID
    }

    /// Call once at launch: finishes any purchase left unfinished (a crash mid-purchase, or one
    /// approved later through Ask to Buy) and looks up the product's price.
    func start() {
        guard updates == nil else { return }
        updates = Task {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result { await transaction.finish() }
            }
        }
        Task { await load() }
    }

    func load() async {
        state = .loading
        do {
            product = try await Product.products(for: [productID]).first
            state = product == nil ? .unavailable : .ready
        } catch {
            state = .unavailable
        }
    }

    /// `purchase` is SwiftUI's `PurchaseAction`, which shows the confirmation over the right window.
    func buy(using purchase: (Product) async throws -> Product.PurchaseResult) async {
        guard let product, state != .purchasing else { return }
        state = .purchasing
        do {
            switch try await purchase(product) {
            case .success(.verified(let transaction)):
                await transaction.finish()
                state = .thanked
            case .success(.unverified):
                state = .failed("The purchase couldn't be verified, so it wasn't completed.")
            case .userCancelled, .pending:
                state = .ready
            @unknown default:
                state = .ready
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
