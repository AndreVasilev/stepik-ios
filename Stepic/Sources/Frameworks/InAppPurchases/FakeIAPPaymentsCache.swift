//
//  FakeIAPPaymentsCache.swift
//  Stepic
//
//  Created by Andrey Vasilev on 14.02.2022.
//  Copyright © 2022 Alex Karpov. All rights reserved.
//

typealias IAPPaymentsCache = FakeIAPPaymentsCache

import Foundation
import StoreKit

class FakeIAPPaymentsCache: IAPPaymentsCacheProtocol {
    static let shared = FakeIAPPaymentsCache()

    func getCoursePayment(for: Any) -> CoursePaymentPayload? {
        nil
    }

    func insertCoursePayment(courseID: Int, promoCode: String?, product: SKProduct) { }

    func removeCoursePayment(for: Any) { }
}

protocol IAPPaymentsCacheProtocol {
    func getCoursePayment(for: Any) -> CoursePaymentPayload?
    func insertCoursePayment(courseID: Int, promoCode: String?, product: SKProduct)
    func removeCoursePayment(for: Any)
}

struct CoursePaymentPayload {
    let productIdentifier: String
    let courseID: Int
    let userID: Int
    let price: Double
    let currencyCode: String?
    let promoCode: String?
}
