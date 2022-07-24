//
//  NSAttributedString+Extensions.swift
//  RNShareMenu
//
//  Created by Carl G on 7/24/22.
//

import Foundation

public extension NSAttributedString {
  func toHtml() throws -> String {
    let htmlData = try self.data(from: NSRange(location: 0, length: self.length), documentAttributes:[.documentType: NSAttributedString.DocumentType.html]);
    return String.init(data: htmlData, encoding: String.Encoding.utf8)!
  }
}
