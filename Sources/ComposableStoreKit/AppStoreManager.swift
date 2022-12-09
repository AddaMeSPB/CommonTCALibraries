//import SwiftUI
//import StoreKit
//import Combine
//import UserDefaultsClient
//import URLRouting
//import NWSharedModels
//import InfoPlist
//
//public class AppStoreManager: NSObject, ObservableObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
//
//    static public let apiClient: URLRoutingClient<SiteRoute> = .live(
//        router: siteRouter.baseRequestData(
//            .init(
//                scheme: EnvironmentKeys.rootURL.scheme,
//                host: EnvironmentKeys.rootURL.host,
//                port: EnvironmentKeys.setPort()
//            )
//        )
//    )
//
//    @Published public var products = [SKProduct]()
//
//    public override init() {
//        super.init()
//
//        SKPaymentQueue.default().add(self)
//    }
//
//    public func getProdcut(indetifiers: [String]) {
//        print("Start requesting products ...")
//        let request = SKProductsRequest(productIdentifiers: Set(indetifiers))
//        request.delegate = self
//        request.start()
//    }
//
//    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
//        print("Did receive response")
//
//        if !response.products.isEmpty {
//            for fetchedProduct in response.products {
//                DispatchQueue.main.async {
//                    self.products.append(fetchedProduct)
//                }
//            }
//        }
//
//        for invalidIdentifier in response.invalidProductIdentifiers {
//            print("Invalid identifiers found: \(invalidIdentifier)")
//        }
//    }
//
//    public func request(_ request: SKRequest, didFailWithError error: Error) {
//        print("Request did fail: \(error)")
//    }
//
//    // Transaction
//
//    @Published public var transactionState: SKPaymentTransactionState?
//
//    public func purchaseProduct(product: SKProduct) {
//        if SKPaymentQueue.canMakePayments() {
//            let payment = SKPayment(product: product)
//            SKPaymentQueue.default().add(payment)
//        } else {
//            print("User can't make payment.")
//        }
//    }
//
//    public struct PaymentReceiptResponseModel: Codable {
//        var status: Int
//        var email: String?
//        var password: String?
//        var message: String?
//    }
//
//    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
//        for transaction in transactions {
//            switch transaction.transactionState {
//            case .purchasing:
//                self.transactionState = .purchasing
//            case .purchased:
//                print("===============Purchased================")
//                UserDefaults.standard.setValue(true, forKey: transaction.payment.productIdentifier)
//                validateReceipt()
//                self.transactionState = .purchased
//            case .restored:
//                UserDefaults.standard.setValue(true, forKey: transaction.payment.productIdentifier)
//                queue.finishTransaction(transaction)
//                print("==================RESTORED State=============")
//                validateReceipt()
//                self.transactionState = .restored
//            case .failed, .deferred:
//                print("Payment Queue Error: \(String(describing: transaction.error))")
//                queue.finishTransaction(transaction)
//                self.transactionState = .failed
//            default:
//                print(">>>> something else")
//                queue.finishTransaction(transaction)
//            }
//        }
//    }
//
//    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
//        print("===============Restored================")
//        validateReceipt()
//        self.transactionState = .purchased
//    }
//
//    public func restorePurchase() {
//        SKPaymentQueue.default().restoreCompletedTransactions()
//    }
//}
//
//
//extension SKProduct {
//    public var localizedPrice: String {
//       let formatter = NumberFormatter()
//       formatter.numberStyle = .currency
//       formatter.locale = priceLocale
//       return formatter.string(from: price)!
//   }
//
//    public var title: String? {
//       switch productIdentifier {
//       case "com.word300.beginner_monthly":
//           return "Monthly"
//       default:
//           return nil
//       }
//   }
//}
//
//extension SKPaymentTransactionState: Equatable {}
//
//func validateReceipt() {
//
//    #if DEBUG
//        let urlString = "https://sandbox.itunes.apple.com/verifyReceipt"
//    #else
//        let urlString = "https://buy.itunes.apple.com/verifyReceipt"
//    #endif
//
//    guard
//        let receiptURL = Bundle.main.appStoreReceiptURL,
//        let receiptString = try? Data(contentsOf: receiptURL).base64EncodedString(),
//        let url = URL(string: urlString)
//    else {
//        print("Couldn't read receipt base64EncodedString data with error: ")
//        return // some error
//    }
//
//    let requestData : [String : Any] = ["receipt-data" : receiptString,
//                                        "password" : "6f2f6b89af3740a1923a48799a26f40f",
//                                        "exclude-old-transactions" : false]
//
////    let input = VerifyReceiptInput(
////        receiptData: receiptString,
////        excludeOldTransactions: false,
////        password: "6f2f6b89af3740a1923a48799a26f40f"
////    )
////
////    do {
////        _ = try await AppStoreManager.apiClient.data(for: .appStore(.verifyReceipt(input: input)))
////    } catch {
////
////    }
//
//    let httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])
//
//    var request = URLRequest(url: url)
//    request.httpMethod = "POST"
//    request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
//    request.httpBody = httpBody
//    URLSession.shared.dataTask(with: request)  { (data, response, error) in
//        // convert data to Dictionary and view purchases
//
//        // ensure there is data returned
//        guard let responseData = data else {
//            print("nil Data received from the server")
//            return
//        }
//
//        do {
//            // create json object from data or use JSONDecoder to convert to Model stuct
//            if let jsonResponse = try JSONSerialization.jsonObject(with: responseData, options: .mutableContainers) as? [String: Any] {
//                print(jsonResponse)
//                // handle json response
//            } else {
//                print("data maybe corrupted or in wrong format")
//                throw URLError(.badServerResponse)
//            }
//        } catch let error {
//            print(error.localizedDescription)
//        }
//
//    }.resume()
//}
