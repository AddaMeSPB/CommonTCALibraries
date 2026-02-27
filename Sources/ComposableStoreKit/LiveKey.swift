import ComposableArchitecture
import StoreKit
import UIKit

@available(iOSApplicationExtension, unavailable)
extension StoreKitClient: @preconcurrency DependencyKey {
  @MainActor
  public static let liveValue = Self(
    addPayment: { SKPaymentQueue.default().add($0) },
    appStoreReceiptURL: { Bundle.main.appStoreReceiptURL },
    isAuthorizedForPayments: { SKPaymentQueue.canMakePayments() },
    fetchProducts: { products in
      let stream = AsyncThrowingStream<ProductsResponse, Error> { continuation in
        let request = SKProductsRequest(productIdentifiers: products)
        let delegate = ProductRequest(continuation: continuation)
        request.delegate = delegate
        request.start()
        continuation.onTermination = { [request = UncheckedSendable(request), delegate = UncheckedSendable(delegate)] _ in
          request.value.cancel()
          _ = delegate.value
        }
      }
      guard let response = try await stream.first(where: { _ in true })
      else { throw CancellationError() }
      return response
    },
    finishTransaction: { transaction in
      guard let skTransaction = transaction.rawValue else {
        assertionFailure("The rawValue of this transaction should not be nil: \(transaction)")
        return
      }
      SKPaymentQueue.default().finishTransaction(skTransaction)
    },
    observer: {
      AsyncStream { continuation in
        let observer = Observer(continuation: continuation)
        SKPaymentQueue.default().add(observer)
        continuation.onTermination = { [observer = UncheckedSendable(observer)] _ in
          SKPaymentQueue.default().remove(observer.value)
        }
      }
    },
    requestReview: {
      await MainActor.run {
        guard
          let scene = UIApplication.shared.connectedScenes
            .first(where: { $0 is UIWindowScene })
            as? UIWindowScene
        else { return }
        SKStoreReviewController.requestReview(in: scene)
      }
    },
    restoreCompletedTransactions: { SKPaymentQueue.default().restoreCompletedTransactions() }
  )
}

private class ProductRequest: NSObject, SKProductsRequestDelegate {
  let continuation: AsyncThrowingStream<StoreKitClient.ProductsResponse, Error>.Continuation

  init(continuation: AsyncThrowingStream<StoreKitClient.ProductsResponse, Error>.Continuation) {
    self.continuation = continuation
  }

  func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
    self.continuation.yield(
      .init(
        invalidProductIdentifiers: response.invalidProductIdentifiers,
        products: response.products.map(StoreKitClient.Product.init(rawValue:))
      )
    )
    self.continuation.finish()
  }

  func request(_ request: SKRequest, didFailWithError error: Error) {
    self.continuation.finish(throwing: error)
  }
}

private class Observer: NSObject, SKPaymentTransactionObserver {
  let continuation: AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>.Continuation

  init(continuation: AsyncStream<StoreKitClient.PaymentTransactionObserverEvent>.Continuation) {
    self.continuation = continuation
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.continuation.yield(
      .updatedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]
  ) {
    self.continuation.yield(
      .removedTransactions(
        transactions.map(StoreKitClient.PaymentTransaction.init(rawValue:))
      )
    )
  }

  func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
    self.continuation.yield(
      .restoreCompletedTransactionsFinished(
        transactions: queue.transactions.map(StoreKitClient.PaymentTransaction.init)
      )
    )
  }

  func paymentQueue(
    _ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error
  ) {
    self.continuation.yield(.restoreCompletedTransactionsFailed(error))
  }
}
