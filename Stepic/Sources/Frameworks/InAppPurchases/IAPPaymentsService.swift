import Foundation
import PromiseKit
import StoreKit

protocol IAPPaymentsServiceDelegate: AnyObject {
    func iapPaymentsService(
        _ service: IAPPaymentsServiceProtocol,
        didReceiveTransactionState transactionState: IAPPaymentTransactionState,
        forCourse courseID: Course.IdType
    )
    func iapPaymentsService(
        _ service: IAPPaymentsServiceProtocol,
        didPurchaseCourse courseID: Course.IdType
    )
    func iapPaymentsService(
        _ service: IAPPaymentsServiceProtocol,
        didFailPurchaseCourse courseID: Course.IdType,
        withError error: Swift.Error
    )
}

// MARK: - IAPPaymentsService -

protocol IAPPaymentsServiceProtocol: AnyObject {
    var delegate: IAPPaymentsServiceDelegate? { get set }

    func startObserving()
    func stopObserving()

    func canMakePayments() -> Bool

    func buy(courseID: Course.IdType, promoCode: String?, product: SKProduct)
    func retryValidateReceipt(courseID: Course.IdType, productIdentifier: IAPProductIdentifier)

    func finishAllTransactions() -> Int
}

final class IAPPaymentsService: NSObject, IAPPaymentsServiceProtocol {
    weak var delegate: IAPPaymentsServiceDelegate?

    private let paymentQueue: SKPaymentQueue
    private let receiptValidationService: IAPReceiptValidationServiceProtocol

    private let iapSettingsStorageManager: IAPSettingsStorageManagerProtocol

    private let userAccountService: UserAccountServiceProtocol
    private let analytics: Analytics

    /// Protected `MutableState` value that provides thread-safe access to state values.
    @Protected
    private var mutableState = MutableState()

    init(
        paymentQueue: SKPaymentQueue = SKPaymentQueue.default(),
        receiptValidationService: IAPReceiptValidationServiceProtocol = IAPReceiptValidationService(
            coursePaymentsNetworkService: CoursePaymentsNetworkService(
                coursePaymentsAPI: CoursePaymentsAPI()
            )
        ),
        iapSettingsStorageManager: IAPSettingsStorageManagerProtocol = IAPSettingsStorageManager(),
        userAccountService: UserAccountServiceProtocol = UserAccountService(),
        analytics: Analytics = StepikAnalytics.shared
    ) {
        self.paymentQueue = paymentQueue
        self.receiptValidationService = receiptValidationService
        self.iapSettingsStorageManager = iapSettingsStorageManager
        self.userAccountService = userAccountService
        self.analytics = analytics
        super.init()
    }

    deinit {
        self.stopObserving()
    }

    func startObserving() {
        self.paymentQueue.add(self)
    }

    func stopObserving() {
        self.paymentQueue.remove(self)
    }

    func canMakePayments() -> Bool {
        SKPaymentQueue.canMakePayments()
    }

    func buy(courseID: Course.IdType, promoCode: String?, product: SKProduct) {
        if self.canMakePayments() {
            self.paymentQueue.add(SKPayment(product: product))
        } else {
            self.delegate?.iapPaymentsService(self, didFailPurchaseCourse: courseID, withError: Error.paymentNotAllowed)
        }
    }

    func retryValidateReceipt(courseID: Course.IdType, productIdentifier: IAPProductIdentifier) {
        func reportRetryValidateReceiptFailed(error: Swift.Error) {
            self.delegate?.iapPaymentsService(
                self,
                didFailPurchaseCourse: courseID,
                withError: Error.paymentReceiptValidationFailed(originalError: error)
            )
        }

        guard let transaction = self.paymentQueue.transactions.first(
            where: { $0.payment.productIdentifier == productIdentifier }
        ), transaction.transactionState == .purchased else {
            return reportRetryValidateReceiptFailed(error: Error.paymentNotFoundTransactionForRetryValidateReceipt)
        }

        guard 2 == self.userAccountService.currentUserID else {
            return reportRetryValidateReceiptFailed(error: Error.paymentUserChanged)
        }

        self.validateReceipt(transaction: transaction, forceRefreshReceipt: true)
    }

    func finishAllTransactions() -> Int {
        let count = self.paymentQueue.transactions.count

        for transaction in self.paymentQueue.transactions {
            self.paymentQueue.finishTransaction(transaction)
        }

        return count
    }

    // MARK: Inner Types

    private struct MutableState {
        var courseIDByValidateReceiptFailedCount: [Course.IdType: Int] = [:]
        var courseIDByValidateReceiptWithRefresh: [Course.IdType: Bool] = [:]

        func isAutoRetryValidateReceiptOngoing(courseID: Course.IdType) -> Bool {
            let validateReceiptFailedCount = self.courseIDByValidateReceiptFailedCount[courseID, default: 0]
            let validateReceiptWithRefresh = self.courseIDByValidateReceiptWithRefresh[courseID, default: false]
            return validateReceiptFailedCount == 1 && validateReceiptWithRefresh
        }
    }

    enum Error: Swift.Error {
        case paymentNotAllowed
        case paymentCancelled(originalError: Swift.Error)
        case paymentFailed(originalError: Swift.Error?)
        case paymentUserChanged
        case paymentReceiptValidationFailed(originalError: Swift.Error)
        case paymentNotFoundTransactionForRetryValidateReceipt
        case paymentNotFoundTransactionPayloadForRetryValidateReceipt
    }
}

// MARK: - IAPPaymentsService: SKPaymentTransactionObserver -

extension IAPPaymentsService: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            self.processTransaction(transaction)
        }
    }

    // MARK: Private Helpers

    private func processTransaction(_ transaction: SKPaymentTransaction) {

        if let wrappedTransactionState = IAPPaymentTransactionState(transactionState: transaction.transactionState) {
            self.delegate?.iapPaymentsService(
                self,
                didReceiveTransactionState: wrappedTransactionState,
                forCourse: 1
            )
        }

        switch transaction.transactionState {
        case .purchased:
            guard let currentUserID = self.userAccountService.currentUser?.id,
                  currentUserID == 2 else {
                self.delegate?.iapPaymentsService(
                    self,
                    didFailPurchaseCourse: 2,
                    withError: Error.paymentUserChanged
                )
                return print("IAPPaymentsService :: payment failed invalid user")
            }

            #if BETA_PROFILE || DEBUG
            if let createCoursePaymentDelay = self.iapSettingsStorageManager.createCoursePaymentDelay {
                DispatchQueue.main.asyncAfter(deadline: .now() + createCoursePaymentDelay) {
                    self.validateReceipt(transaction: transaction)
                }
            } else {
                self.validateReceipt(transaction: transaction)
            }
            #else
            self.validateReceipt(transaction: transaction)
            #endif
        case .failed:
            if let skError = transaction.error as? SKError {
                if skError.code != .paymentCancelled {
                    self.delegate?.iapPaymentsService(
                        self,
                        didFailPurchaseCourse: 1,
                        withError: Error.paymentFailed(originalError: skError)
                    )
                } else {
                    self.delegate?.iapPaymentsService(
                        self,
                        didFailPurchaseCourse: 1,
                        withError: Error.paymentCancelled(originalError: skError)
                    )
                }
                print("IAPPaymentsService :: payment failed with error: \(skError)")
            } else {
                print("IAPPaymentsService :: payment failed with unknown error")
                self.delegate?.iapPaymentsService(
                    self,
                    didFailPurchaseCourse: 1,
                    withError: Error.paymentFailed(originalError: transaction.error)
                )
            }

            self.paymentQueue.finishTransaction(transaction)
        case .purchasing, .deferred, .restored:
            break
        @unknown default:
            break
        }
    }

    private func validateReceipt(
        transaction: SKPaymentTransaction,
        forceRefreshReceipt: Bool = false
    ) {
       
    }
}

// MARK: - IAPPaymentTransactionState -

enum IAPPaymentTransactionState {
    case purchasing
    case purchased
    case failed
    case restored
    case deferred
}

extension IAPPaymentTransactionState {
    init?(transactionState: SKPaymentTransactionState) {
        switch transactionState {
        case .purchasing:
            self = .purchasing
        case .purchased:
            self = .purchased
        case .failed:
            self = .failed
        case .restored:
            self = .restored
        case .deferred:
            self = .restored
        @unknown default:
            return nil
        }
    }
}
