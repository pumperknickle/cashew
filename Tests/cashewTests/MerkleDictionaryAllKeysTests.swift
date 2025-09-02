import Testing
import Foundation
@testable import cashew

@Suite("MerkleDictionary AllKeys Tests")
struct MerkleDictionaryAllKeysTests {
    struct TestValue: Scalar {
        let val: Int
        
        init(val: Int) {
            self.val = val
        }
    }
    
    @Test("MerkleDictionary allKeys returns all inserted keys")
    func testMerkleDictionaryAllKeys() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let testValue1 = TestValue(val: 1)
        let testValue2 = TestValue(val: 2)
        let testValue3 = TestValue(val: 3)
        let testValue4 = TestValue(val: 4)
        
        let header1 = HeaderImpl(node: testValue1)
        let header2 = HeaderImpl(node: testValue2)
        let header3 = HeaderImpl(node: testValue3)
        let header4 = HeaderImpl(node: testValue4)
        
        // Create dictionary with various keys
        let dictionary = try TestDictionaryType()
            .inserting(key: "foo", value: header1)
            .inserting(key: "bar", value: header2)
            .inserting(key: "foobar", value: header3)
            .inserting(key: "baz", value: header4)
        
        let allKeys = try dictionary.allKeys()
        
        #expect(allKeys.count == 4)
        #expect(allKeys.contains("foo"))
        #expect(allKeys.contains("bar"))
        #expect(allKeys.contains("foobar"))
        #expect(allKeys.contains("baz"))
    }
    
    @Test("MerkleDictionary allKeys works with empty dictionary")
    func testMerkleDictionaryAllKeysEmpty() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let emptyDictionary = TestDictionaryType()
        let allKeys = try emptyDictionary.allKeys()
        
        #expect(allKeys.isEmpty)
    }
    
    @Test("MerkleDictionary allKeys works with single key")
    func testMerkleDictionaryAllKeysSingle() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let testValue = TestValue(val: 42)
        let header = HeaderImpl(node: testValue)
        
        let dictionary = try TestDictionaryType().inserting(key: "single", value: header)
        let allKeys = try dictionary.allKeys()
        
        #expect(allKeys.count == 1)
        #expect(allKeys.contains("single"))
    }
    
    @Test("MerkleDictionary allKeysAndValues returns all key-value pairs")
    func testMerkleDictionaryAllKeysAndValues() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let testValue1 = TestValue(val: 100)
        let testValue2 = TestValue(val: 200)
        let testValue3 = TestValue(val: 300)
        let testValue4 = TestValue(val: 400)
        
        let header1 = HeaderImpl(node: testValue1)
        let header2 = HeaderImpl(node: testValue2)
        let header3 = HeaderImpl(node: testValue3)
        let header4 = HeaderImpl(node: testValue4)
        
        // Create dictionary with various keys
        let dictionary = try TestDictionaryType()
            .inserting(key: "alpha", value: header1)
            .inserting(key: "beta", value: header2)
            .inserting(key: "gamma", value: header3)
            .inserting(key: "delta", value: header4)
        
        let allKeysAndValues = try dictionary.allKeysAndValues()
        
        #expect(allKeysAndValues.count == 4)
        #expect(allKeysAndValues["alpha"]?.node?.val == 100)
        #expect(allKeysAndValues["beta"]?.node?.val == 200)
        #expect(allKeysAndValues["gamma"]?.node?.val == 300)
        #expect(allKeysAndValues["delta"]?.node?.val == 400)
    }
    
    @Test("MerkleDictionary allKeysAndValues works with empty dictionary")
    func testMerkleDictionaryAllKeysAndValuesEmpty() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let emptyDictionary = TestDictionaryType()
        let allKeysAndValues = try emptyDictionary.allKeysAndValues()
        
        #expect(allKeysAndValues.isEmpty)
    }
    
    @Test("MerkleDictionary allKeysAndValues works with single key-value pair")
    func testMerkleDictionaryAllKeysAndValuesSingle() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let testValue = TestValue(val: 999)
        let header = HeaderImpl(node: testValue)
        
        let dictionary = try TestDictionaryType().inserting(key: "only", value: header)
        let allKeysAndValues = try dictionary.allKeysAndValues()
        
        #expect(allKeysAndValues.count == 1)
        #expect(allKeysAndValues["only"]?.node?.val == 999)
    }
    
    @Test("MerkleDictionary allKeysAndValues handles keys with common prefixes")
    func testMerkleDictionaryAllKeysAndValuesCommonPrefixes() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        
        let testValue1 = TestValue(val: 10)
        let testValue2 = TestValue(val: 20)
        let testValue3 = TestValue(val: 30)
        
        let header1 = HeaderImpl(node: testValue1)
        let header2 = HeaderImpl(node: testValue2)
        let header3 = HeaderImpl(node: testValue3)
        
        // Create keys with common prefixes to test radix compression
        let dictionary = try TestDictionaryType()
            .inserting(key: "test", value: header1)
            .inserting(key: "testing", value: header2)
            .inserting(key: "tester", value: header3)
        
        let allKeysAndValues = try dictionary.allKeysAndValues()
        
        #expect(allKeysAndValues.count == 3)
        #expect(allKeysAndValues["test"]?.node?.val == 10)
        #expect(allKeysAndValues["testing"]?.node?.val == 20)
        #expect(allKeysAndValues["tester"]?.node?.val == 30)
    }
    
    @Test("MerkleDictionary allKeys throws nodeNotAvailable for unpopulated headers")
    func testMerkleDictionaryAllKeysThrowsForUnpopulatedNodes() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        typealias TestHeaderType = HeaderImpl<TestValue>
        
        // Create a dictionary with an unpopulated header (node = nil)
        let unpopulatedHeader = TestHeaderType(rawCID: "test_cid")
        var dictionary = TestDictionaryType()
        dictionary = TestDictionaryType(children: ["a": RadixHeaderImpl(rawCID: unpopulatedHeader.rawCID)], count: 1)
        
        // Should throw DataErrors.nodeNotAvailable
        #expect(throws: DataErrors.nodeNotAvailable) {
            try dictionary.allKeys()
        }
    }
    
    @Test("MerkleDictionary allKeysAndValues throws nodeNotAvailable for unpopulated headers")
    func testMerkleDictionaryAllKeysAndValuesThrowsForUnpopulatedNodes() throws {
        typealias TestDictionaryType = MerkleDictionaryImpl<HeaderImpl<TestValue>>
        typealias TestHeaderType = HeaderImpl<TestValue>
        
        // Create a dictionary with an unpopulated header (node = nil)
        let unpopulatedHeader = TestHeaderType(rawCID: "test_cid")
        var dictionary = TestDictionaryType()
        dictionary = TestDictionaryType(children: ["b": RadixHeaderImpl(rawCID: unpopulatedHeader.rawCID)], count: 1)
        
        // Should throw DataErrors.nodeNotAvailable
        #expect(throws: DataErrors.nodeNotAvailable) {
            try dictionary.allKeysAndValues()
        }
    }
}