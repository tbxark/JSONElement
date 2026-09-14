import XCTest

#if !canImport(ObjectiveC)
    public func allTests() -> [XCTestCaseEntry] {
        return [
            testCase(JSONElementTests.allTests),
            testCase(ReviewRegressionTests.allTests),
        ]
    }
#endif
