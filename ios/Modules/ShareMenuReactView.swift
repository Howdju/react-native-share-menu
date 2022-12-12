//
//  ShareMenuReactView.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 28/07/2020.
//

import OSLog
import MobileCoreServices

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
      let message = "\(String(describing: Self.self)) had no viewDelegate"
      Self.logger.error("\(message)")
      reject(ERROR_CODE, message, nil)
      return
    }

    viewDelegate.getShareData() { result in
      switch result {
      case .success(let shareData):
        do {
          let shareDataDict = try shareData.toDict()
          resolve(shareDataDict)
        } catch {
          let message = "Failed to convert shareData to dict: \(error)"
          Self.logger.error("\(message)")
          reject(ERROR_CODE, message, error)
        }
      case .failure(let error):
        let errorString = "\(error)"
        Self.logger.error("Failed to get shareData \(errorString)")
        reject(ERROR_CODE, "Failed to extract share data", error)
      }
    }
  }
}
