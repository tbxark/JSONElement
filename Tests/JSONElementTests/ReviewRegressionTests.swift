import Foundation
import XCTest

@testable import JSONElement

/// Regression tests for the findings in `code_review/json-element-core/deepseek.md`.
final class ReviewRegressionTests: XCTestCase {

    private let jsonObject: [String: Any] = [
        "flag_true": true,
        "flag_false": false,
        "integer": 7,
        "double": 0.1,
        "array": [10, 20, 30],
    ]

    private func serialized() throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        return try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
    }

    // MARK: RF-001 — negative and out-of-range indices must not trap

    func testJSONElementNegativeIndicesReturnNull() {
        let array = JSONElement([10, 20, 30])
        XCTAssertEqual(array[-1], .null)
        XCTAssertEqual(array["-1"], .null)
        XCTAssertEqual(array[keyPath: "-1"], .null)
        XCTAssertEqual(array[-100], .null)
    }

    func testJSONElementPositiveOutOfRangeStillReturnsNull() {
        let array = JSONElement([10, 20, 30])
        XCTAssertEqual(array[3], .null)
        XCTAssertEqual(array["3"], .null)
        // Boundaries must keep working.
        XCTAssertEqual(array[0], .int(10))
        XCTAssertEqual(array[2], .int(30))
    }

    func testJSONMapperNegativeIndicesReturnEmpty() {
        let mapper = JSONMapper([10, 20, 30])
        XCTAssertNil(mapper[-1].intValue)
        XCTAssertNil(mapper[keyPath: "-1"].intValue)
        XCTAssertNil(mapper[keyPath: "-100"].intValue)
        // Boundaries must keep working.
        XCTAssertEqual(mapper[0].intValue, 10)
        XCTAssertEqual(mapper[2].intValue, 30)
    }

    func testJSONMapperNegativeIndexInsideNestedKeyPath() {
        let mapper = JSONMapper(["list": [1, 2, 3]])
        XCTAssertNil(mapper[keyPath: "list.-1"].intValue)
        XCTAssertEqual(mapper[keyPath: "list.1"].intValue, 2)
    }

    // MARK: RF-002 — JSONSerialization booleans must stay booleans

    func testSerializedBooleansAreNotCoercedToInt() throws {
        let element = JSONElement(try serialized())
        XCTAssertEqual(element["flag_true"], .bool(true))
        XCTAssertEqual(element["flag_false"], .bool(false))
        XCTAssertEqual(element["flag_true"].boolValue, true)
        XCTAssertEqual(element["flag_false"].boolValue, false)
        // The bug produced `.int(1)` / `.int(0)` here.
        XCTAssertNil(element["flag_true"].intValue)
        XCTAssertNil(element["flag_false"].intValue)
    }

    func testNativeBooleansStillClassifyAsBool() {
        let element = JSONElement(["flag": true] as [String: Any])
        XCTAssertEqual(element["flag"], .bool(true))
        XCTAssertNil(element["flag"].intValue)
    }

    func testNativeNumbersStillClassifyCorrectly() {
        let element = JSONElement(["i": 7, "d": 0.5] as [String: Any])
        XCTAssertEqual(element["i"], .int(7))
        XCTAssertEqual(element["d"].decimalValue, Decimal(string: "0.5"))
    }

    // MARK: RF-003 — floating-point values must not gain binary expansion noise

    func testDecimalKeepsShortestDoubleDescription() {
        let value = 123456789.123456789
        let element = JSONElement(["d": value] as [String: Any])
        XCTAssertEqual(element["d"].decimalValue, Decimal(string: value.description))
        // Old `Decimal(Double)` produced the full binary expansion instead.
        XCTAssertNotEqual(element["d"].decimalValue, Decimal(string: "123456789.12345679872"))
    }

    func testDecimalKeepsShortestFloatDescription() {
        let value: Float = 0.1
        let element = JSONElement(["f": value] as [String: Any])
        XCTAssertEqual(element["f"].decimalValue, Decimal(string: value.description))
    }

    func testSerializedDoubleKeepsShortestDescription() throws {
        let element = JSONElement(try serialized())
        let expected = Decimal(string: (0.1 as Double).description)
        XCTAssertEqual(element["double"].decimalValue, expected)
    }

    // MARK: RF-004 — int and decimal describing the same number must compare and hash equally

    func testIntAndDecimalAreNumericallyEqual() {
        XCTAssertEqual(JSONElement.int(1), JSONElement.decimal(1))
        XCTAssertEqual(JSONElement.decimal(1), JSONElement.int(1))
        XCTAssertEqual(JSONElement.int(2), JSONElement.decimal(Decimal(string: "2.00")!))
        XCTAssertNotEqual(JSONElement.int(1), JSONElement.decimal(Decimal(string: "1.5")!))
    }

    func testIntAndDecimalHashConsistently() {
        var lhs = Hasher()
        JSONElement.int(1).hash(into: &lhs)
        var rhs = Hasher()
        JSONElement.decimal(1).hash(into: &rhs)
        XCTAssertEqual(lhs.finalize(), rhs.finalize())

        let set: Set<JSONElement> = [.int(1), .decimal(1)]
        XCTAssertEqual(set.count, 1)
    }

    func testWholeValuedDecimalRoundTripsToEqualValue() throws {
        let original = JSONElement.decimal(1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(JSONElement.self, from: data)
        // The case is not preserved (whole values decode as `.int`) but the value is.
        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.decimalValue, Decimal(1))
    }

    func testBooleanAndStringHashDistinctlyFromNumbers() {
        XCTAssertNotEqual(JSONElement.bool(true), JSONElement.int(1))
        XCTAssertNotEqual(JSONElement.string("1"), JSONElement.int(1))
    }

    // MARK: RF-005 — key path null/absent semantics are pinned

    func testKeyPathCollapsesPresentNullAndAbsent() {
        let element = JSONElement(["a": ["b": JSONElement.null]] as [String: Any])
        XCTAssertEqual(element[keyPath: "a.b"], .null)
        XCTAssertEqual(element[keyPath: "a.missing"], .null)
        let empty = JSONElement([:] as [String: Any])
        XCTAssertEqual(empty[keyPath: "a.b"], .null)
    }

    // MARK: RF-006 / RF-007 — accessor visibility and availability

    func testDoubleValueIsAccessible() {
        let mapper = JSONMapper(["d": 0.25])
        XCTAssertEqual(mapper["d"].doubleValue, 0.25)
        XCTAssertEqual(JSONMapper(0.25).doubleValue, 0.25)
    }

    func testIntAndUintValuesAccessible() {
        let mapper = JSONMapper(["i": 9])
        XCTAssertEqual(mapper["i"].intValue, 9)
        XCTAssertEqual(mapper["i"].uintValue, 9)
    }

    // MARK: RF-008 — encodeToJsonString must throw rather than force-unwrap

    func testEncodeToJsonStringReturnsValue() throws {
        struct Model: Codable, Equatable {
            let name: String
            let count: Int
        }
        let json = try Model(name: "Peter", count: 3).encodeToJsonString()
        let decoded = try JSONDecoder().decode(Model.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(decoded, Model(name: "Peter", count: 3))
    }

    static var allTests = [
        ("testJSONElementNegativeIndicesReturnNull", testJSONElementNegativeIndicesReturnNull),
        (
            "testJSONElementPositiveOutOfRangeStillReturnsNull",
            testJSONElementPositiveOutOfRangeStillReturnsNull
        ),
        ("testJSONMapperNegativeIndicesReturnEmpty", testJSONMapperNegativeIndicesReturnEmpty),
        (
            "testJSONMapperNegativeIndexInsideNestedKeyPath",
            testJSONMapperNegativeIndexInsideNestedKeyPath
        ),
        ("testSerializedBooleansAreNotCoercedToInt", testSerializedBooleansAreNotCoercedToInt),
        ("testNativeBooleansStillClassifyAsBool", testNativeBooleansStillClassifyAsBool),
        ("testNativeNumbersStillClassifyCorrectly", testNativeNumbersStillClassifyCorrectly),
        ("testDecimalKeepsShortestDoubleDescription", testDecimalKeepsShortestDoubleDescription),
        ("testDecimalKeepsShortestFloatDescription", testDecimalKeepsShortestFloatDescription),
        (
            "testSerializedDoubleKeepsShortestDescription",
            testSerializedDoubleKeepsShortestDescription
        ),
        ("testIntAndDecimalAreNumericallyEqual", testIntAndDecimalAreNumericallyEqual),
        ("testIntAndDecimalHashConsistently", testIntAndDecimalHashConsistently),
        (
            "testWholeValuedDecimalRoundTripsToEqualValue",
            testWholeValuedDecimalRoundTripsToEqualValue
        ),
        (
            "testBooleanAndStringHashDistinctlyFromNumbers",
            testBooleanAndStringHashDistinctlyFromNumbers
        ),
        ("testKeyPathCollapsesPresentNullAndAbsent", testKeyPathCollapsesPresentNullAndAbsent),
        ("testDoubleValueIsAccessible", testDoubleValueIsAccessible),
        ("testIntAndUintValuesAccessible", testIntAndUintValuesAccessible),
        ("testEncodeToJsonStringReturnsValue", testEncodeToJsonStringReturnsValue),
    ]
}
