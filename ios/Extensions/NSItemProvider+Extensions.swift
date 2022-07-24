//
//  NSItemProvider+Extensions.swift
//  RNShareMenu
//
//  Created by Gustavo Parreira on 29/07/2020.
//

import MobileCoreServices

public extension NSItemProvider {
    var hasText: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypeText as String)
    }

    var hasImage: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypeImage as String)
    }

    var hasData: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypeData as String)
    }

    var hasUrl: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypeURL as String) && !hasFileUrl
    }

    var hasFileUrl: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypeFileURL as String)
    }
    
    var hasPropertyList: Bool {
        return hasItemConformingToTypeIdentifier(kUTTypePropertyList as String)
    }
}
