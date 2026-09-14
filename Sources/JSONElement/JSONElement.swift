//
//  JSONElement.swift
//  JSONElement
//
//  Created by Tbxark on 08/11/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//
import Foundation

// MARK: - JSONElement
@dynamicMemberLookup
public enum JSONElement: Codable, Equatable, Hashable {

    // MARK: getter
    case null
    public var isNull: Bool {
        if case .null = self {
            return true
        } else {
            return false
        }
    }

    case int(Int)
    public var intValue: Int? {
        if case .int(let value) = self {
            return value
        } else {
            return nil
        }
    }

    case decimal(Decimal)
    public var decimalValue: Decimal? {
        if case .decimal(let value) = self {
            return value
        } else if case .int(let value) = self {
            return Decimal(value)
        } else {
            return nil
        }
    }

    case bool(Bool)
    public var boolValue: Bool? {
        if case .bool(let value) = self {
            return value
        } else {
            return nil
        }
    }

    case string(String)
    public var stringValue: String? {
        if case .string(let value) = self {
            return value
        } else {
            return nil
        }
    }

    indirect case object([String: JSONElement])
    public var objectValue: [String: JSONElement]? {
        if case .object(let value) = self {
            return value
        } else {
            return nil
        }
    }

    indirect case array([JSONElement])
    public var arrayValue: [JSONElement]? {
        if case .array(let value) = self {
            return value
        } else {
            return nil
        }
    }

    public var rawValue: Any? {
        switch self {
        case .null:
            return nil
        case .int(let value):
            return value
        case .decimal(let value):
            return value
        case .bool(let value):
            return value
        case .string(let value):
            return value
        case .object(let value):
            var dict = [String: Any]()
            for (k, v) in value {
                dict[k] = v.rawValue
            }
            return dict
        case .array(let value):
            return value.map({ $0.rawValue })
        }
    }

    // MARK: init
    public init(_ value: Any?) {
        guard let v = value else {
            self = .null
            return
        }
        if let number = v as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
            // `JSONSerialization` represents booleans as `NSNumber` (`__NSCFBoolean`), and such a
            // number also satisfies `as? Int`, so it must be recognised before the numeric casts
            // or a boolean is silently stored as `.int(1)` / `.int(0)`.
            self = .bool(number.boolValue)
        } else if let _v = v as? Int {
            self = .int(_v)
        } else if let _v = v as? Double {
            self = .decimal(JSONElement.decimal(fromDescription: _v.description, fallback: _v))
        } else if let _v = v as? Float {
            self = .decimal(
                JSONElement.decimal(fromDescription: _v.description, fallback: Double(_v)))
        } else if let _v = v as? Bool {
            self = .bool(_v)
        } else if let _v = v as? String {
            self = .string(_v)
        } else if let _v = v as? [String: Any] {
            self = .object(_v.mapValues({ JSONElement($0) }))
        } else if let _v = v as? [Any] {
            self = .array(_v.map({ JSONElement($0) }))
        } else {
            do {
                if let m = v as? Encodable {
                    self = try JSONElement(model: m)
                } else {
                    self = try JSONElement(unknownValue: v)
                }
            } catch {
                self = .null
            }
        }
    }

    /// Builds a `Decimal` from a floating-point value's shortest round-tripping description
    /// instead of `Decimal(_: Double)`, which materialises the full binary value
    /// (`0.12345678901234567` becomes `0.12345678901234569216`). Parsing is pinned to POSIX so a
    /// comma-decimal locale cannot change the result; `fallback` covers descriptions the parser
    /// rejects (for example subnormal values).
    private static func decimal(fromDescription description: String, fallback: Double) -> Decimal {
        let posix = Locale(identifier: "en_US_POSIX")
        return Decimal(string: description, locale: posix) ?? Decimal(fallback)
    }

    public init(
        model: Encodable, jsonDecoder: JSONDecoder = JSONDecoder(),
        jsonEncoder: JSONEncoder = JSONEncoder()
    ) throws {
        let jsonData = try model.encodeToJsonData(using: jsonEncoder)
        self = try jsonDecoder.decode(JSONElement.self, from: jsonData)
    }

    public init(rawJSON: [Any], jsonDecoder: JSONDecoder = JSONDecoder()) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: rawJSON, options: [])
        self = try jsonDecoder.decode(JSONElement.self, from: jsonData)
    }

    public init(rawJSON: [String: Any], jsonDecoder: JSONDecoder = JSONDecoder()) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: rawJSON, options: [])
        self = try jsonDecoder.decode(JSONElement.self, from: jsonData)
    }

    public init(rawJSON: String, jsonDecoder: JSONDecoder = JSONDecoder()) throws {
        let data = rawJSON.data(using: String.Encoding.utf8) ?? Data()
        self = try jsonDecoder.decode(JSONElement.self, from: data)
    }

    public init(rawJSON: Data, jsonDecoder: JSONDecoder = JSONDecoder()) throws {
        self = try jsonDecoder.decode(JSONElement.self, from: rawJSON)
    }

    public init(unknownValue: Any, jsonDecoder: JSONDecoder = JSONDecoder()) throws {
        let jsonData = try JSONSerialization.data(withJSONObject: [unknownValue], options: [])
        self =
            (try jsonDecoder.decode(JSONElement.self, from: jsonData)).arrayValue?.first
            ?? JSONElement.null
    }

    /// Whole-valued numbers decode to `.int` because `Int` is attempted first; fractional values
    /// fall through to `.decimal`. A `.decimal` encoding of a whole number therefore decodes back
    /// as `.int`, which is value-preserving because `==` compares `int` and `decimal` numerically.
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .decimal(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONElement].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONElement].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case .int(let value):
            try container.encode(value)
        case .decimal(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        }
    }

    // MARK: equatable & hashable
    // `int` and `decimal` are distinct cases so that whole numbers keep an exact integer
    // representation, but they denote the same number. Equality and hashing are therefore defined
    // numerically across the two cases; otherwise `JSONElement.int(1) != JSONElement.decimal(1)`
    // even though `decimalValue` reports both as `Decimal(1)`, which makes the type unusable as a
    // `Dictionary`/`Set` key.
    public static func == (lhs: JSONElement, rhs: JSONElement) -> Bool {
        switch (lhs, rhs) {
        case (.null, .null):
            return true
        case (.int(let a), .int(let b)):
            return a == b
        case (.decimal(let a), .decimal(let b)):
            return a == b
        case (.int(let a), .decimal(let b)):
            return Decimal(a) == b
        case (.decimal(let a), .int(let b)):
            return a == Decimal(b)
        case (.bool(let a), .bool(let b)):
            return a == b
        case (.string(let a), .string(let b)):
            return a == b
        case (.object(let a), .object(let b)):
            return a == b
        case (.array(let a), .array(let b)):
            return a == b
        default:
            return false
        }
    }

    public func hash(into hasher: inout Hasher) {
        switch self {
        case .null:
            hasher.combine(0)
        case .bool(let value):
            hasher.combine(1)
            hasher.combine(value)
        case .string(let value):
            hasher.combine(2)
            hasher.combine(value)
        case .object(let value):
            hasher.combine(3)
            hasher.combine(value)
        case .array(let value):
            hasher.combine(4)
            hasher.combine(value)
        case .int(let value):
            // The numeric cases share a hash branch so `int(1)` and `decimal(1)` hash equally,
            // matching the equality above.
            hasher.combine(5)
            hasher.combine(Decimal(value))
        case .decimal(let value):
            hasher.combine(5)
            hasher.combine(value)
        }
    }

    // MARK: transform
    public func `as`<T: Decodable>(
        _ type: T.Type = T.self, jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        let data = try jsonEncoder.encode(self)
        return try jsonDecoder.decode(T.self, from: data)
    }

    // MARK: subscript
    public subscript(key: String) -> JSONElement {
        switch self {
        case .null:
            return .null
        case .object(let value):
            return value[String(key)] ?? .null
        case .array(let value):
            guard let index = Int(key), value.indices.contains(index) else {
                return .null
            }
            return value[index]
        default:
            return .null
        }
    }

    public subscript(index: Int) -> JSONElement {
        switch self {
        case .array(let value):
            guard value.indices.contains(index) else {
                return .null
            }
            return value[index]
        default:
            return JSONElement.null
        }
    }

    public subscript(dynamicMember member: String) -> JSONElement {
        switch self {
        case .object(let value):
            return value[member] ?? .null
        case .array(let value):
            guard let index = Int(member), value.indices.contains(index) else {
                return .null
            }
            return value[index]
        default:
            return .null
        }
    }

    /// Splits `path` on `.` and walks the result. Any missing key, non-container value, or
    /// explicitly `null` intermediate collapses to `.null`, so a present-but-null field is
    /// indistinguishable from an absent one.
    public subscript(keyPath path: String) -> JSONElement {
        var current = self
        for key in path.split(separator: ".").map({ String($0) }) {
            let v = current[key]
            if v.isNull {
                return JSONElement.null
            } else {
                current = v
            }
        }
        return current
    }
}
