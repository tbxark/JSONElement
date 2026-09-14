import XCTest

@testable import JSONElement

final class JSONElementTests: XCTestCase {
    struct Human: Codable {
        let age: Int
        let name: String
        let height: Double
        let extra: JSONElement  // Any?
    }

    let dict = [
        "data": [
            "man": [
                "age": 10, "name": "Peter", "height": 180.0,
                "extra": [123, "123", [123], ["123": 123], true],
            ]
        ]
    ]

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
        XCTAssertEqual(
            try? json[keyPath: "data.man.extra"].as(JSONElement.self)?.arrayValue?.last?.as(
                Bool.self),
            true)

    }

    func testJSONElement() throws {

        let json = try JSONElement(rawJSON: dict)
        // 使用dynamicMemberLookup直接获取
        XCTAssertEqual(json.data.man.age.intValue, 10)

        // 使用Key获取
        XCTAssertEqual(json["data"]["man"]["height"].decimalValue, 180.0)

        // 使用Keypath获取
        XCTAssertEqual(json[keyPath: "data.man.name"].stringValue, "Peter")

        // 将不确定类型对象解析为JSONElement
        XCTAssertEqual(json.data.man.extra.arrayValue?.first?.intValue, 123)
        XCTAssertEqual(try? json.data.man.extra.arrayValue?.last?.as(Bool.self), true)

    }

    static var allTests = [
        ("testJSONMapper", testJSONMapper),
        ("testJSONElement", testJSONElement),
    ]
}
