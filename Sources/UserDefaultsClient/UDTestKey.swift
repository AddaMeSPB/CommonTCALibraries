import Dependencies
import Foundation
import XCTestDynamicOverlay

extension UserDefaultsClient: TestDependencyKey {
  public static let previewValue = Self.noop

  public static let testValue = Self(
    boolForKey: XCTUnimplemented("\(Self.self).boolForKey", placeholder: false),
    dataForKey: XCTUnimplemented("\(Self.self).dataForKey", placeholder: nil),
    doubleForKey: XCTUnimplemented("\(Self.self).doubleForKey", placeholder: 0),
    integerForKey: XCTUnimplemented("\(Self.self).integerForKey", placeholder: 0),
    stringForKey: XCTUnimplemented("\(Self.self).stringForKey", placeholder: ""),
    remove: XCTUnimplemented("\(Self.self).remove"),
    setBool: XCTUnimplemented("\(Self.self).setBool"),
    setData: XCTUnimplemented("\(Self.self).setData"),
    setDouble: XCTUnimplemented("\(Self.self).setDouble"),
    setInteger: XCTUnimplemented("\(Self.self).setInteger"),
    setString: XCTUnimplemented("\(Self.self).setString")
  )
}

extension UserDefaultsClient {
    public static let noop = Self(
        boolForKey: { _ in false },
        dataForKey: { _ in nil },
        doubleForKey: { _ in 0 },
        integerForKey: { _ in 0 },
        stringForKey: { _ in ""},
        remove: { _ in },
        setBool: { _, _ in },
        setData: { _, _ in },
        setDouble: { _, _ in },
        setInteger: { _, _ in },
        setString: { _, _ in }
    )

    public mutating func override(bool: Bool, forKey key: String) {
        self.boolForKey = { [self] in $0 == key ? bool : self.boolForKey(key) }
    }

    public mutating func override(data: Data, forKey key: String) {
        self.dataForKey = { [self] in $0 == key ? data : self.dataForKey(key) }
    }

    public mutating func override(double: Double, forKey key: String) {
        self.doubleForKey = { [self] in $0 == key ? double : self.doubleForKey(key) }
    }

    public mutating func override(integer: Int, forKey key: String) {
        self.integerForKey = { [self] in $0 == key ? integer : self.integerForKey(key) }
    }

    public mutating func override(string: String, forKey key: String) {
      self.stringForKey = { [self] in $0 == key ? string : self.stringForKey(key) }
    }
}
