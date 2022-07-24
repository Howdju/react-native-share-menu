//
//  RNSMError.swift
//  RNShareMenu
//
//  Created by Carl G on 7/23/22.
//

import Foundation

public struct RNSMError : Error {
  let message: String

  public init(_ message: String){
    self.message = message
  }

  public var localizedDescription: String {
    return message
  }
}
