//
//  GCDThings.swift
//  Stepic
//
//  Created by Alexander Karpov on 22.01.16.
//  Copyright © 2016 Alex Karpov. All rights reserved.
//

import Foundation

func delay(delay:Double, closure:()->()) {
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            Int64(delay * Double(NSEC_PER_SEC))
        ),
        dispatch_get_main_queue(), closure)
}