
import MobileCoreServices
import OSLog

struct ExtractedValue {
  let value: String
  let mimeType: String
  let role: String
  
  init(_ value: String, mimeType: String, role: String) {
    self.value = value
    self.mimeType = mimeType
    self.role = role
  }
}

// Static utilities for extracting ShareData from an NSExtensionContext
public struct ShareDataExtractor {
  private static let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier!,
    category: String(describing: ShareDataExtractor.self)
  )

  public static func extractShareData(_ extensionItems: [NSExtensionItem]) async throws -> ShareData {
    var items = [ShareDataItem]()
    var groupNumber = 1
    for extensionItem in extensionItems {
      let itemGroup = "ItemGroup \(groupNumber)"

      if let title = extensionItem.attributedTitle {
        items.append(ShareDataItem(title.string, "text/plain", itemGroup, role: "title/text"))
        if let html = try? title.toHtml() {
          items.append(ShareDataItem(html, "text/html", itemGroup, role: "title/html"))
        }
      }

      if let contentText = extensionItem.attributedContentText {
        items.append(ShareDataItem(contentText.string, "text/plain", itemGroup, role: "content/text"))
        if let contentHtml = try? contentText.toHtml() {
          items.append(ShareDataItem(contentHtml, "text/html", itemGroup, role: "content/html"))
        }
      }
      
      for value in try await getAttachmentValues(extensionItem) {
        items.append(ShareDataItem(value.value, value.mimeType, itemGroup, role: value.role))
      }
      groupNumber += 1
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
        items.append(ShareDataItem(newUrl.absoluteString, item.mimeType, item.itemGroup, role: item.role))
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
      .containerURL(forSecurityApplicationGroupIdentifier: "\(appGroupId)")
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
  
  static func getAttachmentValues(_ extensionItem: NSExtensionItem) async throws -> [ExtractedValue] {
    var extractedValues = [ExtractedValue]()
    
    guard let providers = extensionItem.attachments else {
      logger.error("Extension item had no attachments \(extensionItem)")
      return extractedValues
    }
    
    for provider in providers {
      if provider.hasUrl {
        extractedValues.append(try await getUrl(from: provider))
      }
      if provider.hasFileUrl {
        extractedValues.append(try await getFileUrl(from: provider))
      }
      if provider.hasImage {
        extractedValues.append(try await getImage(from: provider))
      }
      if provider.hasText {
        extractedValues.append(try await getText(from: provider))
      }
      if provider.hasData {
        if let mimeValue = try await getData(from: provider) {
          extractedValues.append(mimeValue)
        }
      }
      if provider.hasPropertyList {
        extractedValues.append(try await getPropertyList(from: provider))
      }
    }
    
    if extractedValues.isEmpty {
      throw RNSMError("Recognized no providers from share input attachments.")
    }
    
    return extractedValues
  }
  
  static func getUrl(from provider: NSItemProvider) async throws -> ExtractedValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil)
    guard let url = item as? URL else {
      throw RNSMError("URL provider did not provide a URL.")
    }
    return ExtractedValue(url.absoluteString, mimeType: "text/uri-list", role: "provider/url")
  }
  
  static func getFileUrl(from provider: NSItemProvider) async throws -> ExtractedValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeFileURL as String, options: nil)
    guard let url = item as? URL else {
      throw RNSMError("File URL provider did not provide a URL.")
    }
    let mimeType = self.extractMimeType(from: url)
    return ExtractedValue(url.absoluteString, mimeType: mimeType, role: "provider/file-url")
  }
  
  static func getImage(from provider: NSItemProvider) async throws -> ExtractedValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil)
    if let imageUrl: URL = item as? URL {
      // Ensure the image has data
      guard (try? Data(contentsOf: imageUrl)) != nil else {
        throw RNSMError("Could not load contents of image URL.")
      }
      let mimeType = self.extractMimeType(from: imageUrl)
      return ExtractedValue(imageUrl.absoluteString, mimeType: mimeType, role: "provider/image/url")
    }
    
    if let image = item as? UIImage {
      let imageData: Data! = image.pngData();
      
      // Create a temporary URL for image data (UIImage)
      guard let imageUrl = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RNShareMenuTempImage.png") else {
        throw RNSMError("Failed to create temporary image file.")
      }
      
      try imageData.write(to: imageUrl)
      return ExtractedValue(imageUrl.absoluteString, mimeType: "image/png", role: "provider/image/data")
    }
    
    throw RNSMError("Unsupported image provider item type: \(String(describing: item))")
  }
  
  static func getText(from provider: NSItemProvider) async throws -> ExtractedValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil)
    guard let textValue = item as? String else {
      throw RNSMError("Text representation faild to coerce to text.")
    }
    return ExtractedValue(textValue, mimeType: "text/plain", role: "provider/text")
  }
  
  static func getData(from provider: NSItemProvider) async throws -> ExtractedValue? {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil)
    if let string = item as? String {
      return ExtractedValue(string, mimeType: "text/plain", role: "provider/data/string")
    }
    if let url = item as? URL {
      let mimeType = self.extractMimeType(from: url)
      return ExtractedValue(url.absoluteString, mimeType: mimeType, role: "provider/data/url")
    }
    if let dictionary = item as? NSDictionary {
      guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
        throw RNSMError("Dictionary data value missing Javascript preprocessing results")
      }
      do {
        let jsonData = try JSONSerialization.data(withJSONObject: results)
        let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
        return ExtractedValue(jsonString, mimeType: "text/json", role: "provider/data/javascript-preprocessing")
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
  
  static func getPropertyList(from provider: NSItemProvider) async throws -> ExtractedValue {
    let item = try await provider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil)
    guard let dictionary = item as? NSDictionary else {
      throw RNSMError("Property list provider did not provide a dictionary.")
    }
    guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
      throw RNSMError("Property list provider dictionary was missing Javascript preprocessing results")
    }
    return ExtractedValue(results.description, mimeType: "text/plain", role: "provider/property-list/javascript-preprocessing")
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

