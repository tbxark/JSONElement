//
//  JsonMapper.swift
//  JsonMapper
//
//  Created by Tbxark on 08/11/2016.
//  Copyright © 2016 Tbxark. All rights reserved.
//
import Foundation

// MARK: - JSONMapper
@dynamicMemberLookup
public struct JSONMapper {

    private var originData: Any?

    // MARK: init
    public init(rawJSON: String) {
        guard let data = rawJSON.data(using: String.Encoding.utf8),
            let obj = try? JSONSerialization.jsonObject(with: data, options: .allowFragments)
        else {
            self.originData = nil
            return
        }
        self.originData = obj
    }

    public init(rawJSON: Data) {
        guard let obj = try? JSONSerialization.jsonObject(with: rawJSON, options: .allowFragments)
        else {
            self.originData = nil
            return
        }
        self.originData = obj
    }

    public init(_ raw: Any?) {
        self.originData = raw
    }

    // MARK: transform
    public func `as`<T: Decodable>(
        _ type: T.Type = T.self, jsonEncoder: JSONEncoder = JSONEncoder(),
        jsonDecoder: JSONDecoder = JSONDecoder()
    ) -> T? {
        guard let value = originData else {
            return nil
        }
        if let v = value as? T {
            return v
        } else if let json = try? JSONElement(unknownValue: value, jsonDecoder: jsonDecoder) {
            return try? json.as(T.self, jsonEncoder: jsonEncoder, jsonDecoder: jsonDecoder)
        } else {
            return nil
        }
    }

    // MARK: subscript
    public subscript(key: String) -> JSONMapper {
        return JSONMapper((originData as? [String: Any])?[key])
    }

    public subscript(index: Int) -> JSONMapper {
        guard let array = originData as? [Any],
            array.indices.contains(index)
        else {
            return JSONMapper(nil)
        }
        return JSONMapper(array[index])
    }

    /// Splits `path` on `.` and walks the result, descending into objects by key and arrays by
    /// integer index. Any missing key, non-container value, or out-of-range/negative index
    /// collapses to an empty `JSONMapper`.
    public subscript(keyPath path: String) -> JSONMapper {
        var current = self
        for key in path.split(separator: ".") {
            guard let v = current.originData else {
                return JSONMapper(nil)
            }
            if let dict = v as? [String: Any] {
                current = JSONMapper(dict[String(key)])
            } else if let array = v as? [Any], let index = Int(key), array.indices.contains(index) {
                current = JSONMapper(array[index])
            } else {
                return JSONMapper(nil)
            }
        }
        return current
    }

    public subscript(dynamicMember member: String) -> JSONMapper {
        guard let v = self.originData,
            let dict = v as? [String: Any]
        else {
            return JSONMapper(nil)
        }
        return JSONMapper(dict[member])
    }

    // MARK: getter
    public var boolValue: Bool? {
        return originData as? Bool ?? numValue?.boolValue
    }

    public var stringValue: String? {
        return originData as? String
    }

    public var numValue: NSNumber? {
        return originData as? NSNumber
    }

    public var int8Value: Int8? {
        return numValue?.int8Value
    }

    public var uint8Value: UInt8? {
        return numValue?.uint8Value
    }

    public var int16Value: Int16? {
        return numValue?.int16Value
    }

    public var uint16Value: UInt16? {
        return numValue?.uint16Value
    }

    public var int32Value: Int32? {
        return numValue?.int32Value
    }

    public var uint32Value: UInt32? {
        return numValue?.uint32Value
    }

    public var int64Value: Int64? {
        return numValue?.int64Value
    }

    public var uint64Value: UInt64? {
        return numValue?.uint64Value
    }

    public var floatValue: Float? {
        return numValue?.floatValue
    }

    public var doubleValue: Double? {
        return numValue?.doubleValue
    }

    public var intValue: Int? {
        return numValue?.intValue
    }

    public var uintValue: UInt? {
        return numValue?.uintValue
    }
}

// MARK: - Codable
extension JSONDecoder {
    public func decodeJSONStringToModel<T: Decodable>(json: String) throws -> T {
        guard let data = json.data(using: String.Encoding.utf8) else {
            throw NSError(
                domain: "org.swift.JSONEncoder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Can not convert string to data"])
        }
        let model = try decode(T.self, from: data)
        return model
    }
}

extension JSONEncoder {

    public func encodeModelToJSONObj<T: Encodable>(value: T) throws -> Any {
        let data = try self.encode(value)
        let json = try JSONSerialization.jsonObject(with: data, options: [])
        return json
    }

    public func encodeModelToJSONString<T: Codable>(value: T) throws -> String {
        let data = try encode(value)
        guard let json = String(bytes: data, encoding: String.Encoding.utf8) else {
            throw NSError(
                domain: "org.swift.JSONEncoder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Can not convert data to string"])
        }
        return json
    }

}

extension JSONDecoder {
    public convenience init(
        date: JSONDecoder.DateDecodingStrategy = JSONDecoder.DateDecodingStrategy.deferredToDate,
        data: JSONDecoder.DataDecodingStrategy = JSONDecoder.DataDecodingStrategy.base64,
        nonConformingFloat: JSONDecoder.NonConformingFloatDecodingStrategy = JSONDecoder
            .NonConformingFloatDecodingStrategy.throw,
        key: JSONDecoder.KeyDecodingStrategy = JSONDecoder.KeyDecodingStrategy.useDefaultKeys
    ) {
        self.init()
        self.dateDecodingStrategy = date
        self.dataDecodingStrategy = data
        self.nonConformingFloatDecodingStrategy = nonConformingFloat
        self.keyDecodingStrategy = key
    }
}

extension JSONEncoder {
    public convenience init(
        date: JSONEncoder.DateEncodingStrategy = JSONEncoder.DateEncodingStrategy.deferredToDate,
        data: JSONEncoder.DataEncodingStrategy = JSONEncoder.DataEncodingStrategy.base64,
        nonConformingFloat: JSONEncoder.NonConformingFloatEncodingStrategy = JSONEncoder
            .NonConformingFloatEncodingStrategy.throw,
        key: JSONEncoder.KeyEncodingStrategy = JSONEncoder.KeyEncodingStrategy.useDefaultKeys
    ) {
        self.init()
        self.dateEncodingStrategy = date
        self.dataEncodingStrategy = data
        self.nonConformingFloatEncodingStrategy = nonConformingFloat
        self.keyEncodingStrategy = key
    }
}

extension Encodable {
    public func encodeToJsonData(using encoder: JSONEncoder = JSONEncoder()) throws -> Data {
        return try encoder.encode(self)
    }

    public func encodeToJsonString(using encoder: JSONEncoder = JSONEncoder()) throws -> String {
        let data = try encoder.encode(self)
        guard let json = String(data: data, encoding: .utf8) else {
            throw NSError(
                domain: "org.swift.JSONEncoder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Can not convert data to string"])
        }
        return json
    }
}
