//
//  ShareViewController.swift
//  RNShareMenu
//
//  DO NOT EDIT THIS FILE. IT WILL BE OVERRIDEN BY NPM OR YARN.
//
//  Created by Gustavo Parreira on 26/07/2020.
//

import RNShareMenu

import MobileCoreServices
import UIKit
import Social
import OSLog

class ShareViewController: SLComposeServiceViewController {
  private static let logger = Logger(
      subsystem: Bundle.main.bundleIdentifier!,
      category: String(describing: ShareViewController.self)
  )

  // The App Group ID to use for UserDefaults and file containers
  var appGroupId: String?
  // The host app's URL scheme.
  var hostAppUrl: URL?

  override func viewDidLoad() {
    super.viewDidLoad()

    guard let hostAppId = Bundle.main.object(forInfoDictionaryKey: HOST_APP_IDENTIFIER_INFO_PLIST_KEY) as? String else {
      Self.logger.error("Required bundle key missing: \(HOST_APP_IDENTIFIER_INFO_PLIST_KEY, privacy: .public)")
      return
    }
    self.appGroupId = "group.\(hostAppId)"

    guard let hostAppUrlScheme = Bundle.main.object(forInfoDictionaryKey: HOST_URL_SCHEME_INFO_PLIST_KEY) as? String else {
      Self.logger.error("Required bundle key missing: \(HOST_URL_SCHEME_INFO_PLIST_KEY, privacy: .public)")
      return
    }
    guard let hostAppUrl = URL(string: hostAppUrlScheme) else {
      Self.logger.error("Host app URL scheme must form a valid URL: \(hostAppUrlScheme, privacy: .public)")
      return
    }
    self.hostAppUrl = hostAppUrl
  }

   override func isContentValid() -> Bool {
     return true
   }

  override func didSelectPost() {
    guard let appGroupId = self.appGroupId else {
      failRequest("appGroupId was not initialized.")
      return
    }
    guard extensionContext != nil else {
      failRequest("didSelectPost had no extension context.")
      return
    }
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      failRequest("didSelectPost had no extension items.")
      return
    }

    ShareDataExtractor.extractShareDataInGroupContainer(extensionItems, appGroupId) { result in
      switch result {
      case .success(let shareData):
        do {
          try self.store(shareData)
        } catch {
          self.failRequest(error)
          return
        }
        self.openHostApp()
      case .failure(let error):
        self.failRequest(error)
      }
    }
  }

  override func configurationItems() -> [Any]! {
    // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
    return []
  }

  func handlePost(with extraData: [String: Any]? = nil) {
    guard let appGroupId = self.appGroupId else {
      failRequest("appGroupId is not initialized.")
      return
    }
    guard extensionContext != nil else {
      failRequest("handlePost had no extension context.")
      return
    }
    guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem] else {
      failRequest("handlePost had no extension items.")
      return
    }

    if extraData?.isEmpty ?? true {
      do {
        try removeExtraData()
      } catch {
        self.failRequest(error)
        return
      }
    } else {
      do {
        try storeExtraData(extraData!)
      } catch {
        self.failRequest(error)
        return
      }
    }

    ShareDataExtractor.extractShareDataInGroupContainer(extensionItems, appGroupId) { result in
      switch result {
      case .success(let shareData):
        do {
          try self.store(shareData)
        } catch {
          self.failRequest(RNSMError("Failed to store share data: \(error.localizedDescription)"))
          return
        }
        self.openHostApp()
      case .failure(let error):
        Self.logger.error("\(error.localizedDescription, privacy: .public)")
        do {
          try self.removeExtraData()
        } catch {
          Self.logger.error("Failed to remove extra data: \(error.localizedDescription)")
        }
        self.failRequest(error)
        return
      }
    }
  }

  func storeExtraData(_ data: [String: Any]) throws {
    try storeUserDefault(data, key: USER_DEFAULTS_EXTRA_DATA_KEY)
  }

  func storeUserDefault(_ data: [String: Any], key: String) throws {
    guard let appGroupId = self.appGroupId else {
      failRequest("appGroupId is not initialized.")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
      throw RNSMError("Unable to init UserDefaults for App Group ID: \(appGroupId)")
    }
    userDefaults.set(data, forKey: key)
    userDefaults.synchronize()
  }

  func removeExtraData() throws {
    guard let appGroupId = self.appGroupId else {
      failRequest("appGroupId is not initialized.")
      return
    }
    guard let userDefaults = UserDefaults(suiteName: appGroupId) else {
      throw RNSMError("Unable to init UserDefaults for App Group ID: \(appGroupId)")
    }
    userDefaults.removeObject(forKey: USER_DEFAULTS_EXTRA_DATA_KEY)
    userDefaults.synchronize()
  }

  func store(_ shareData: ShareData) throws {
    var shareDataJsonString: String
    do {
      let shareDataJsonData = try JSONSerialization.data(withJSONObject: shareData)
      shareDataJsonString = String(data: shareDataJsonData, encoding: String.Encoding.utf8)!
    } catch {
      throw RNSMError("Failed to serialize share data: \(error)")
    }

    try storeUserDefault([DATA_KEY: shareDataJsonString, MIME_TYPE_KEY: "text/json"], key: USER_DEFAULTS_KEY)
  }

  internal func openHostApp() {
    guard let hostAppUrl = self.hostAppUrl else {
      failRequest("Cannot openHostApp because hostAppUrl was not initialized.")
      return
    }
    guard let extensionContext = self.extensionContext else {
      failRequest("Unable to open host app because there is no extension context.")
      return
    }
    extensionContext.open(hostAppUrl)
    completeRequest()
  }

  func completeRequest() {
    // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
    extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
  }

  // Log the error and cancel the request
  private func failRequest(_ error: Error) {
    let message = "\(error)"
    Self.logger.error("\(message)")
    cancelRequest(message)
  }

  // Log the error and cancel the request
  private func failRequest(_ reason: String) {
    Self.logger.error("\(reason)")
    cancelRequest(reason)
  }

  // Cancel the share extension request
  func cancelRequest(_ reason: String) {
    extensionContext!.cancelRequest(withError: RNSMError(reason))
  }
}
