// Marker protocol for classes that can be converted into dictionaries
public protocol Dictable : Encodable {}

public extension Dictable {
  func toDict() throws -> [String: Any] {
    let data = try JSONEncoder().encode(self)
    return try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
  }
}
