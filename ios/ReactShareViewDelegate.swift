//
//  ReactShareViewDelegate.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 29/07/2020.
//

public protocol ReactShareViewDelegate {
  func dismissExtension(_ errorMessage: String?)

  func openApp()

  func continueInApp(with extraData: [String:Any]?)
  
  func getShareData(_ completion: @escaping (Result<ShareData, Error>) -> Void)
}
