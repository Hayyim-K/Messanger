//
//  Extensions.swift
//  Messenger
//
//  Created by vitasiy on 21/08/2023.
//

import UIKit

extension UIView {
    
    public var width: CGFloat {
        self.frame.size.width
    }
    
    public var height: CGFloat {
        self.frame.size.height
    }
    
    public var top: CGFloat {
        self.frame.origin.y
    }
    
    public var bottom: CGFloat {
        self.frame.origin.y + height
    }
    
    public var left: CGFloat {
        self.frame.origin.x
    }
    
    public var right: CGFloat {
        width + left
    }
    
}
