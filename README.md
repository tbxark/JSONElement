# JSONElement

`JSONElement` is a simple, fast and secure way to access Json.

Because `Any` can't be used in `Codable`, it can be replaced with `JSONElement` for properties of type `Any`.



## Installation

### Swift Package Manager

Add the dependency in your `Package.swift` file:

```swift
let package = Package(
    name: "myproject",
    dependencies: [
        .package(url: "https://github.com/TBXark/JSONElement.git", .upToNextMajor(from: "1.4.0"))
        ],
    targets: [
        .target(
            name: "myproject",
            dependencies: ["JSONElement"]),
        ]
)
```

### Carthage

Add the dependency in your `Cartfile` file:

```bash
github "TBXark/JSONElement" ~> 1.4.0.
```

### CocoaPods

Add the dependency in your `Podfile` file:

```ruby
pod 'JSONElement'
```

# Example

```swift

final class JSONElementTests: XCTestCase {
    struct Human: Codable {
        let age: Int
        let name: String
        let height: Double
        let extra: JSONElement // Any?
    }
    
    let dict = ["data": ["man": ["age": 10, "name": "Peter", "height": 180.0, "extra": [123, "123", [123], ["123": 123], true]]]]

    
    func testJSONElement() throws {

        let json = try JSONElement(rawJSON: dict)
        // 使用dynamicMemberLookup直接获取
        XCTAssertEqual(json.data.man.age.intValue, 10)

        // 使用Key获取
        XCTAssertEqual(json["data"]["man"]["height"].decimalValue, 180.0)

        // 使用Keypath获取
        XCTAssertEqual(json[keyPath: "data.man.name"].stringValue, "Peter")
        
        // 将不确定类型对象解析为JSONElement
        XCTAssertEqual(json.data.man.extra.arrayValue?.first?.intValue , 123)
        XCTAssertEqual(try? json.data.man.extra.arrayValue?.last?.as(Bool.self), true)

    }


    func testJSONMapper() throws {

        let json = JSONMapper(dict)

        // 使用 dynamicMemberLookup 获取
        XCTAssertEqual(json.data.man.height.as(Double.self), 180.0)

        // 使用Key获取
        XCTAssertEqual(json["data"]["man"]["age"].intValue, 10)
        XCTAssertEqual(json["data"]["man"]["height"].as(Double.self), 180.0)

        // 使用Keypath获取
        XCTAssertEqual(json[keyPath: "data.man.name"].as(String.self), "Peter")

        // 将不确定类型对象解析为JSONElement
        XCTAssertEqual(try? json[keyPath: "data.man.extra"].as(JSONElement.self)?.arrayValue?.last?.as(Bool.self), true)

    }

    static var allTests = [
        ("testJSONElement", testJSONElement),
        ("testJSONMapper", testJSONMapper),
    ]
}

```

## Notes and limitations

- **Index access is bounds-safe.** Out-of-range and negative indices (through `[Int]`, `["-1"]`,
  `keyPath:` or `dynamicMemberLookup`) return `JSONElement.null` / an empty `JSONMapper` rather than
  trapping.
- **Booleans stay booleans.** Values produced by `JSONSerialization` (where a boolean is an
  `NSNumber`) are recognised before the integer casts, so a JSON `true` is a `JSONElement.bool`, not
  `.int(1)`. Prefer `boolValue` over `intValue` for boolean fields.
- **Numbers carry their shortest description.** Floating-point values are stored as `Decimal` parsed
  from the value's shortest round-tripping description, so `0.1` is stored as `0.1` rather than the
  full binary expansion.
- **`int` and `decimal` compare numerically.** `JSONElement.int(1) == JSONElement.decimal(1)` and
  they hash equally, even though the enum keeps them as separate cases. Whole-valued numbers decode
  as `.int`, so a `.decimal` whole number round-trips to an equal `.int` value.
- **Key paths collapse nulls.** A key path returns `.null` for a missing key, a type mismatch, and an
  explicitly `null` intermediate alike; callers cannot distinguish "present but null" from "absent".
