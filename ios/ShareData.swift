public struct ShareData: Codable, Dictable {
    var items: [ShareDataItem]
}

public struct ShareDataItem: Codable {
  // The MIME type of the value. In Android, this might be a wildcard MIME type
  // that was meant to cover all the possible values appearing in this share.
  // In that case, the recipent must infer the meaning of the values somehow.
  let mimeType: String
  // The value of the item encoded as a String. Consumers must infer the meaning
  // of the value based on mimeType and possibly the contents.
  let value: String
  // In iOS, a share can include multiple items each having multiple representations.
  // If itemGroup is set, then each of the values having the same itemGroup are
  // representations of the same item.
  let itemGroup: String?
  // An optional string indicating the role of the item.
  //
  // In iOS, share data can come from multiple sources, such as the attributedTitle, attributedContent,
  // and NSExtensionItem.attachments. Since these data sources may be redundant, we record
  // their source as a 'role' in order to help select preferred representations of share data.
  //
  // Instead of calling this 'source', which would not be cross-platform since different platforms
  // could have different sources, we call it 'role' to try and allow for different cross-platform
  // sources contributing to the same role.
  let role: String?

  init(_ value: String, _ mimeType: String) {
    self.value = value
    self.mimeType = mimeType
    self.itemGroup = nil
    self.role = nil
  }

  init(_ value: String, _ mimeType: String, _ itemGroup: String?) {
    self.value = value
    self.mimeType = mimeType
    self.itemGroup = itemGroup
    self.role = nil
  }
  
  init(_ value: String, _ mimeType: String, _ itemGroup: String?, role: String?) {
    self.value = value
    self.mimeType = mimeType
    self.itemGroup = itemGroup
    self.role = role
  }
}
