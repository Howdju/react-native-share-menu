
import MobileCoreServices
import OSLog

// Static utilities for extracting ShareData from an NSExtensionContext
public struct ShareDataExtractor {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: ShareDataExtractor.self)
  )

  public static func extractShareData(_ extensionItems: [NSExtensionItem]) async throws -> ShareData {
    var items = [ShareDataItem]()
    var itemGroup = 1
    for extensionItem in extensionItems {
      let mimeValues = try await getAttachmentValues(extensionItem)
      for mimeValue in mimeValues {
        items.append(ShareDataItem(mimeValue.value, mimeValue.mimeType, "ItemGroup \(itemGroup)"))
      }
      itemGroup += 1
    }
    
    return ShareData(items: items)
  }
  
  // Async alternative of extractShareDataInGroupContainer for callers that can't use async.
  //
  // See https://www.avanderlee.com/swift/async-await/#add-async-alternative
  @available(*, renamed: "extractShareDataInGroupContainer()")
  public static func extractShareDataInGroupContainer(_ extensionItems: [NSExtensionItem], _ appGroupId: String, completion: @escaping (Result<ShareData, Error>) -> Void) {
    Task {
      do {
        let result = try await extractShareDataInGroupContainer(extensionItems, appGroupId)
        completion(.success(result))
      } catch {
        completion(.failure(error))
      }
    }
  }
  
  public static func extractShareDataInGroupContainer(_ extensionItems: [NSExtensionItem], _ appGroupId: String) async throws -> ShareData {
    let shareData = try await extractShareData(extensionItems)
    return try await copyFilesToGroupContainer(shareData, appGroupId)
  }
  
  static func copyFilesToGroupContainer(_ shareData: ShareData, _ appGroupId: String) async throws -> ShareData {
    var items = [ShareDataItem]()
    for item in shareData.items {
      if item.mimeType.starts(with: "text/") {
        items.append(item)
      } else {
        guard let url = URL(string: item.value) else {
          throw RNSMError("Item with file MIME type did not contain a valid URL (\(item))")
        }
        let newUrl = try copyFileToGroupContainer(from: url, into: appGroupId)
        items.append(ShareDataItem(newUrl.absoluteString, item.mimeType))
      }
    }
    
    if items.isEmpty {
      logger.error("Share data items are empty")
    }
    
    return ShareData(items: items)
  }

  // Returns the URL of the copy made inside the group container
  static func copyFileToGroupContainer(from url: URL, into appGroupId: String) throws -> URL {
    guard let applicationGroupContainerUrl = FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: "group.\(appGroupId)")
    else {
      throw RNSMError("Unable to get container URL for app group ID: \(appGroupId)")
    }
    
    let fileName = UUID().uuidString
    let newUrl = applicationGroupContainerUrl.appendingPathComponent("\(fileName).\(url.pathExtension)")
    
    do {
      try copyFile(from: url, to: newUrl)
    } catch {
      throw RNSMError("Failed to copy file from \(url) to \(newUrl): \(error)")
    }
    
    return newUrl
  }
  
  static func copyFile(from srcUrl: URL, to destUrl: URL) throws {
    if FileManager.default.fileExists(atPath: destUrl.path) {
      logger.warning("Overwriting file \(destUrl)")
      try FileManager.default.removeItem(at: destUrl)
    }
    try FileManager.default.copyItem(at: srcUrl, to: destUrl)
  }
  
  static func getAttachmentValues(_ extensionItem: NSExtensionItem) async throws -> [MimeValue] {
    var mimeValues = [MimeValue]()
    
    guard let providers = extensionItem.attachments else {
      logger.error("Extension item had no attachments \(extensionItem)")
      return mimeValues
    }
    
    for provider in providers {
      if provider.hasUrl {
        mimeValues.append(try await getUrl(from: provider))
      }
      if provider.hasFileUrl {
        mimeValues.append(try await getUrl(from: provider))
      }
      if provider.hasImage {
        mimeValues.append(try await getImage(from: provider))
      }
      if provider.hasText {
        mimeValues.append(try await getText(from: provider))
      }
      if provider.hasData {
        if let mimeValue = try await getData(from: provider) {
          mimeValues.append(mimeValue)
        }
      }
      if provider.hasPropertyList {
        mimeValues.append(try await getPropertyList(from: provider))
      }
    }
    
    if mimeValues.isEmpty {
      throw RNSMError("Recognized no providers from share input attachments.")
    }
    
    return mimeValues
  }
  
  static func getUrl(from provider: NSItemProvider) async throws -> MimeValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil)
    guard let url = item as? URL else {
      throw RNSMError("URL provider did not provide a URL.")
    }
    return MimeValue(url.absoluteString, mimeType: "text/uri-list")
  }
  
  static func getImage(from provider: NSItemProvider) async throws -> MimeValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil)
    if let imageUrl: URL = item as? URL {
      // Ensure the image has data
      guard (try? Data(contentsOf: imageUrl)) != nil else {
        throw RNSMError("Could not load contents of image URL.")
      }
      let mimeType = self.extractMimeType(from: imageUrl)
      return MimeValue(imageUrl.absoluteString, mimeType: mimeType)
    }
    
    if let image = item as? UIImage {
      let imageData: Data! = image.pngData();
      
      // Create a temporary URL for image data (UIImage)
      guard let imageUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RNShareMenuTempImage.png") else {
        throw RNSMError("Failed to create temporary image file.")
      }
      
      try imageData.write(to: imageUrl)
      return MimeValue(imageUrl.absoluteString, mimeType: "image/png")
    }
    
    throw RNSMError("Unsupported image provider item type: \(String(describing: item))")
  }
  
  static func getText(from provider: NSItemProvider) async throws -> MimeValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil)
    guard let textValue = item as? String else {
      throw RNSMError("Text representation faild to coerce to text.")
    }
    return MimeValue(textValue, mimeType: "text/plain")
  }
  
  static func getData(from provider: NSItemProvider) async throws -> MimeValue? {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil)
    if let string = item as? String {
      return MimeValue(string, mimeType: "text/plain")
    }
    if let url = item as? URL {
      let mimeType = self.extractMimeType(from: url)
      return MimeValue(url.absoluteString, mimeType: mimeType)
    }
    if let dictionary = item as? NSDictionary {
      guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
        throw RNSMError("Dictionary data value missing Javascript preprocessing results")
      }
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: results)
        let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
        return MimeValue(jsonString, mimeType: "text/json")
      } catch {
        throw RNSMError("Failed to decode Javascript preprocessing result JSON: \(error)");
      }
    }
    
    // Add additional recognized types here.
    
    if let data = item as? Data {
      Self.logger.info("Ignoring provider data that lacked more specific type: \(String(describing: data))")
      return nil
    }
    
#if DEBUG
    // If possible, add additional types that are discovered here above before the check for Data.

    // I'm not sure it's safe to use Mirror on an NSSecureCoding, so only do it in development
    let mirror = Mirror(reflecting:item)
    Self.logger.error("Unsupported data provider item type: \(String(describing: mirror.subjectType))")
#else
    Self.logger.error("Unsupported data provider item type: \(String(describing: item))")
#endif
    
    return nil
  }
  
  static func getPropertyList(from provider: NSItemProvider) async throws -> MimeValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil)
    guard let dictionary = item as? NSDictionary else {
      throw RNSMError("Property list provider did not provide a dictionary.")
    }
    guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
      throw RNSMError("Property list provider dictionary was missing Javascript preprocessing results")
    }
    return MimeValue(results.description, mimeType: "text/plain")
  }
  
  static func extractMimeType(from url: URL) -> String {
    let fileExtension: CFString = url.pathExtension as CFString
    guard let extUTI = UTTypeCreatePreferredIdentifierForTag(
      kUTTagClassFilenameExtension,
      fileExtension,
      nil
    )?.takeUnretainedValue() else { return "" }
    
    guard let mimeUTI = UTTypeCopyPreferredTagWithClass(extUTI, kUTTagClassMIMEType)
    else { return "" }
    
    return mimeUTI.takeUnretainedValue() as String
  }
}

