//
//  ShareMenuReactView.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 28/07/2020.
//

import MobileCoreServices

@objc(ShareMenuReactView)
public class ShareMenuReactView: NSObject {

    static var viewDelegate: ReactShareViewDelegate?

    @objc
    static public func requiresMainQueueSetup() -> Bool {
        return false
    }

    public static func attachViewDelegate(_ delegate: ReactShareViewDelegate!) {
        guard (ShareMenuReactView.viewDelegate == nil) else { return }

        ShareMenuReactView.viewDelegate = delegate
    }

    public static func detachViewDelegate() {
        ShareMenuReactView.viewDelegate = nil
    }

    @objc(dismissExtension:)
    func dismissExtension(_ error: String?) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        if error != nil {
            let exception = NSError(
                domain: Bundle.main.bundleIdentifier!,
                code: DISMISS_SHARE_EXTENSION_WITH_ERROR_CODE,
                userInfo: ["error": error!]
            )
            extensionContext.cancelRequest(withError: exception)
            return
        }

        extensionContext.completeRequest(returningItems: [], completionHandler: nil)
    }

    @objc
    func openApp() {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        viewDelegate.openApp()
    }

    @objc(continueInApp:)
    func continueInApp(_ extraData: [String:Any]?) {
        guard let viewDelegate = ShareMenuReactView.viewDelegate else {
            print("Error: \(NO_DELEGATE_ERROR)")
            return
        }

        let extensionContext = viewDelegate.loadExtensionContext()

        guard let item = extensionContext.inputItems.first as? NSExtensionItem else {
            print("Error: \(COULD_NOT_FIND_ITEM_ERROR)")
            return
        }

        viewDelegate.continueInApp(with: item, and: extraData)
    }

    @objc(data:reject:)
    func data(_
            resolve: @escaping RCTPromiseResolveBlock,
            reject: @escaping RCTPromiseRejectBlock) {
        guard let extensionContext = ShareMenuReactView.viewDelegate?.loadExtensionContext() else {
            print("Error: \(NO_EXTENSION_CONTEXT_ERROR)")
            return
        }

        extractDataFromContext(context: extensionContext) { (data, mimeType, error) in
            guard (error == nil) else {
                reject("error", error?.description, nil)
                return
            }

            resolve([MIME_TYPE_KEY: mimeType, DATA_KEY: data])
        }
    }

    func extractDataFromContext(context: NSExtensionContext, withCallback callback: @escaping (String?, String?, NSException?) -> Void) {
        print("Carl: extensionContext?.inputItems.count: \(context.inputItems.count)")
        let item:NSExtensionItem! = context.inputItems.first as? NSExtensionItem
        print("Carl: item.attachments?.count: \(item.attachments?.count)")
        let attachments:[AnyObject]! = item.attachments

        var urlProvider:NSItemProvider! = nil
        var imageProvider:NSItemProvider! = nil
        var textProvider:NSItemProvider! = nil
        var dataProvider:NSItemProvider! = nil
        var propertyListProvider:NSItemProvider! = nil

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(kUTTypeURL as String) {
                urlProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeText as String) {
                textProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeImage as String) {
                imageProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypeData as String) {
                dataProvider = provider as? NSItemProvider
                break
            } else if provider.hasItemConformingToTypeIdentifier(kUTTypePropertyList as String) {
                propertyListProvider = provider as? NSItemProvider
            }
        }

        if (urlProvider != nil) {
            urlProvider.loadItem(forTypeIdentifier: kUTTypeURL as String, options: nil) { (item, error) in
                let url: URL! = item as? URL

                callback(url.absoluteString, "text/plain", nil)
            }
        } else if (imageProvider != nil) {
            imageProvider.loadItem(forTypeIdentifier: kUTTypeImage as String, options: nil) { (item, error) in
                let imageUrl: URL! = item as? URL

                if (imageUrl != nil) {
                    if let imageData = try? Data(contentsOf: imageUrl) {
                        callback(imageUrl.absoluteString, self.extractMimeType(from: imageUrl), nil)
                    }
                } else {
                    let image: UIImage! = item as? UIImage

                    if (image != nil) {
                        let imageData: Data! = image.pngData();

                        // Creating temporary URL for image data (UIImage)
                        guard let imageURL = NSURL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("TemporaryScreenshot.png") else {
                            return
                        }

                        do {
                            // Writing the image to the URL
                            try imageData.write(to: imageURL)

                            callback(imageURL.absoluteString, imageURL.extractMimeType(), nil)
                        } catch {
                            callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"Can't load image", userInfo:nil))
                        }
                    }
                }
            }
        } else if (textProvider != nil) {
            textProvider.loadItem(forTypeIdentifier: kUTTypeText as String, options: nil) { (item, error) in
                let text:String! = item as? String

                callback(text, "text/plain", nil)
            }
        }  else if (dataProvider != nil) {
            dataProvider.loadItem(forTypeIdentifier: kUTTypeData as String, options: nil) { (item, error) in
                if error != nil {
                    callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"error loading a data", userInfo:nil));
                    return;
                }
                if let url = item as? URL {
                    callback(url.absoluteString, self.extractMimeType(from: url), nil)
                } else if let dictionary = item as? NSDictionary {
                    guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
                        callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"results missing Javascript preprocessing results", userInfo:nil));
                        return;
                    }
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: results)
                        let jsonString = String(data: jsonData, encoding: String.Encoding.utf8)!
                        callback(jsonString, "text/json", nil)
                    } catch {
                        print(error.localizedDescription)
                        callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"failed to JSON serialize dictionary \(error.localizedDescription)", userInfo:nil));
                    }
                } else {
                    callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason: "data wasn't any supported type", userInfo: nil));
                }
            }
        } else if (propertyListProvider != nil) {
            dataProvider.loadItem(forTypeIdentifier: kUTTypePropertyList as String, options: nil, completionHandler: { (decoder, error) in
                if error != nil {
                    callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"error loading a property list", userInfo:nil));
                    return;
                }
                guard let dictionary = decoder as? NSDictionary else {
                    callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"decoder wasn't a dictionary", userInfo:nil));
                    return;
                }
                guard let results = dictionary.value(forKey: NSExtensionJavaScriptPreprocessingResultsKey) as? NSDictionary else {
                    callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"results missing Javascript preprocessing results", userInfo:nil));
                    return;
                }
                callback(results.description, "text/plain", nil)
            })
        } else {
            callback(nil, nil, NSException(name: NSExceptionName(rawValue: "Error"), reason:"couldn't find provider", userInfo:nil))
        }
    }

    func extractMimeType(from url: URL) -> String {
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
