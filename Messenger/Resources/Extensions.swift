//
//  Extensions.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit

extension UIView {
    
    public var width: CGFloat {
        frame.size.width
    }
    
    public var height: CGFloat {
        frame.size.height
    }
    
    public var top: CGFloat {
        frame.origin.y
    }
    
    public var bottom: CGFloat {
        frame.origin.y + height
    }
    
    public var left: CGFloat {
        frame.origin.x
    }
    
    public var right: CGFloat {
        width + left
    }
    
}

extension Notification.Name {
    static let didLogInNotification = Notification.Name("didLogInNotification")
}
