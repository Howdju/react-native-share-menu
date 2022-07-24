//
//  ShareMenuReactView.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 28/07/2020.
//

import OSLog
import MobileCoreServices

struct MimeValue {
  let value: String
  let mimeType: String
  
  init(_ value: String, mimeType: String) {
    self.value = value
    self.mimeType = mimeType
  }
}

struct ProviderLoadError: Error {
  let message: String
}

@objc(ShareMenuReactView)
public class ShareMenuReactView: NSObject {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: ShareMenuReactView.self)
  )
  
  static var viewDelegate: ReactShareViewDelegate?
  
  @objc
  static public func requiresMainQueueSetup() -> Bool {
    return false
  }
  
  public static func attachViewDelegate(_ delegate: ReactShareViewDelegate!) {
    guard (ShareMenuReactView.viewDelegate == nil) else {
      Self.logger.warning("Attempting to set view delegate when it is already set.")
      return
    }
    
    ShareMenuReactView.viewDelegate = delegate
  }
  
  public static func detachViewDelegate() {
    ShareMenuReactView.viewDelegate = nil
  }
  
  @objc(dismissExtension:)
  func dismissExtension(_ errorMessage: String?) {
    guard let viewDelegate = Self.viewDelegate else {
      Self.logger.error("dismissExtension had no viewDelegate")
      return
    }
    viewDelegate.dismissExtension(errorMessage)
  }
  
  @objc
  func openApp() {
    guard let viewDelegate = Self.viewDelegate else {
      Self.logger.error("continueInApp had no viewDelegate")
      return
    }
    
    viewDelegate.openApp()
  }
  
  @objc(continueInApp:)
  func continueInApp(_ extraData: [String:Any]?) {
    guard let viewDelegate = Self.viewDelegate else {
      Self.logger.error("continueInApp had no viewDelegate")
      return
    }
    
    viewDelegate.continueInApp(with: extraData)
  }
  
  @objc(data:reject:)
  func data(_
            resolve: @escaping RCTPromiseResolveBlock,
            reject: @escaping RCTPromiseRejectBlock) {
    guard let viewDelegate = Self.viewDelegate else {
      Self.logger.error("data had no viewDelegate")
      return
    }

    viewDelegate.getShareData() { result in
      switch result {
      case .success(let shareData):
        resolve([DATA_KEY: shareData])
      case .failure(let error):
        reject(ERROR_CODE, "Failed to extract share data", error)
      }
    }
  }
}

