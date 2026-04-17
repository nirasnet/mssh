import StoreKit
import Observation

/// StoreKit 2 tip jar — consumable IAPs for user donations.
/// Product IDs must be created in App Store Connect to match.
@Observable
@MainActor
final class TipJarService {
    static let shared = TipJarService()

    /// Product IDs — create these as **Consumable** IAPs in App Store Connect.
    static let productIDs: [String] = [
        "com.m4ck.mssh.tip.coffee",   // $0.99
        "com.m4ck.mssh.tip.lunch",    // $4.99
        "com.m4ck.mssh.tip.dinner"    // $9.99
    ]

    var products: [Product] = []
    var purchaseMessage: String?
    var isLoading = false

    private init() {}

    /// Load available tip products from App Store.
    func loadProducts() async {
        guard products.isEmpty else { return }
        isLoading = true
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("[mSSH] Failed to load tip products: \(error)")
        }
        isLoading = false
    }

    /// Purchase a tip. Consumables are finished immediately.
    func purchase(_ product: Product) async {
        isLoading = true
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                purchaseMessage = "Thank you for your support! Your \(product.displayName) tip means a lot."
            case .userCancelled:
                break
            case .pending:
                purchaseMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            purchaseMessage = "Purchase failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.unverified
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: LocalizedError {
        case unverified
        var errorDescription: String? { "Transaction verification failed." }
    }
}

// MARK: - Tip display helpers

extension TipJarService {
    /// Emoji + label for each tier based on price.
    static func tierInfo(for product: Product) -> (emoji: String, subtitle: String) {
        switch product.id {
        case "com.m4ck.mssh.tip.coffee":
            return ("☕", "Buy me a coffee")
        case "com.m4ck.mssh.tip.lunch":
            return ("🍱", "Buy me lunch")
        case "com.m4ck.mssh.tip.dinner":
            return ("🍽️", "Buy me dinner")
        default:
            return ("💝", "Leave a tip")
        }
    }
}
