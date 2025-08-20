import Testing
import Foundation
import ArrayTrie
@testable import cashew

@Suite("Transform Tests")  
struct TransformTests {
    
    @Test("ArrayTrie interface verification")
    func testArrayTrieInterface() throws {
        var transforms = ArrayTrie<Transform>()
        transforms.set(["testkey"], value: .insert("testvalue"))
        transforms.set(["updatekey"], value: .update("updatevalue"))  
        transforms.set(["deletekey"], value: .delete)
        
        #expect(transforms.get(["testkey"]) != nil)
        #expect(transforms.get(["updatekey"]) != nil)
        #expect(transforms.get(["deletekey"]) != nil)
        
        // Verify transform types
        if let insertValue = transforms.get(["testkey"]) {
            switch insertValue {
            case .insert(let str):
                #expect(str == "testvalue")
            default:
                #expect(Bool(false), "Wrong transform type for insert")
            }
        }
        
        if let updateValue = transforms.get(["updatekey"]) {
            switch updateValue {
            case .update(let str):
                #expect(str == "updatevalue")
            default:
                #expect(Bool(false), "Wrong transform type for update")
            }
        }
        
        if let deleteValue = transforms.get(["deletekey"]) {
            switch deleteValue {
            case .delete:
                break // Expected
            default:
                #expect(Bool(false), "Wrong transform type for delete")
            }
        }
    }
    
    @Test("MerkleDictionary manual operations verification")
    func testMerkleDictionaryManualOperations() throws {
        let emptyDict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        
        // Test inserting
        let dictWithOne = try emptyDict.inserting(key: "key1", value: "value1")
        #expect(dictWithOne.count == 1)
        #expect(try dictWithOne.get(key: "key1") == "value1")
        
        // Test inserting another
        let dictWithTwo = try dictWithOne.inserting(key: "key2", value: "value2")
        #expect(dictWithTwo.count == 2)
        #expect(try dictWithTwo.get(key: "key1") == "value1")
        #expect(try dictWithTwo.get(key: "key2") == "value2")
        
        // Test deleting
        let dictWithOneDeleted = try dictWithTwo.deleting(key: "key1")
        #expect(dictWithOneDeleted.count == 1)
        #expect(try dictWithOneDeleted.get(key: "key1") == nil)
        #expect(try dictWithOneDeleted.get(key: "key2") == "value2")
        
        // Test mutating
        let dictWithMutated = try dictWithTwo.mutating(key: ArraySlice("key1"), value: "mutated_value1")
        #expect(dictWithMutated.count == 2)
        #expect(try dictWithMutated.get(key: "key1") == "mutated_value1")
        #expect(try dictWithMutated.get(key: "key2") == "value2")
    }
    
    @Test("Simple single insert transform")
    func testSimpleSingleInsertTransform() throws {
        let dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        
        var transforms = ArrayTrie<Transform>()
        transforms.set(["newkey"], value: .insert("newvalue"))
        
        let result = try dict.transform(transforms: transforms)
        
        #expect(result.count == 1)
        #expect(try result.get(key: "newkey") == "newvalue")
    }
    
    @Test("Simple single delete transform") 
    func testSimpleSingleDeleteTransform() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "keyToDelete", value: "valueToDelete")
        
        var transforms = ArrayTrie<Transform>()
        transforms.set(["keyToDelete"], value: .delete)
        
        let result = try dict.transform(transforms: transforms)
        
        #expect(result.count == 0)
        #expect(try result.get(key: "keyToDelete") == nil)
    }
    
    @Test("Simple single update transform")
    func testSimpleSingleUpdateTransform() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "keyToUpdate", value: "oldValue")
        
        var transforms = ArrayTrie<Transform>()
        transforms.set(["keyToUpdate"], value: .update("newValue"))
        
        let result = try dict.transform(transforms: transforms)
        
        #expect(result.count == 1)
        #expect(try result.get(key: "keyToUpdate") == "newValue")
    }
    
    @Test("Transform vs manual - insert comparison")
    func testTransformVsManualInsert() throws {
        let dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        
        // ArrayTrie transform
        var transforms = ArrayTrie<Transform>()
        transforms.set(["key1"], value: .insert("value1"))
        let transformResult = try dict.transform(transforms: transforms)
        
        // Manual operation
        let manualResult = try dict.inserting(key: "key1", value: "value1")
        
        // Both should have the same result
        #expect(transformResult.count == manualResult.count)
        let transformValue = try transformResult.get(key: "key1")
        let manualValue = try manualResult.get(key: "key1")
        #expect(transformValue == manualValue)
    }
    
    @Test("Transform vs manual - delete comparison") 
    func testTransformVsManualDelete() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "key1", value: "value1")
            .inserting(key: "key2", value: "value2")
        
        // ArrayTrie transform
        var transforms = ArrayTrie<Transform>()
        transforms.set(["key1"], value: .delete)
        let transformResult = try dict.transform(transforms: transforms)
        
        // Manual operation
        let manualResult = try dict.deleting(key: "key1")
        
        // Both should have the same result
        #expect(transformResult.count == manualResult.count)
        let transformValue1 = try transformResult.get(key: "key1")
        let manualValue1 = try manualResult.get(key: "key1")
        #expect(transformValue1 == manualValue1)
        let transformValue2 = try transformResult.get(key: "key2")
        let manualValue2 = try manualResult.get(key: "key2")
        #expect(transformValue2 == manualValue2)
    }
    
    @Test("Transform vs manual - update comparison")
    func testTransformVsManualUpdate() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "key1", value: "oldValue")
        
        // ArrayTrie transform
        var transforms = ArrayTrie<Transform>()
        transforms.set(["key1"], value: .update("newValue"))
        let transformResult = try dict.transform(transforms: transforms)
        
        // Manual operation
        let manualResult = try dict.mutating(key: ArraySlice("key1"), value: "newValue")
        
        // Both should have the same result
        #expect(transformResult.count == manualResult.count)
        let transformValue = try transformResult.get(key: "key1")
        let manualValue = try manualResult.get(key: "key1")
        #expect(transformValue == manualValue)
    }
    
    @Test("Empty transform preserves data")
    func testEmptyTransformPreservesData() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "key1", value: "value1")
        
        let emptyTransforms = ArrayTrie<Transform>()
        let result = try dict.transform(transforms: emptyTransforms)
        
        #expect(result.count == dict.count)
        let resultValue = try result.get(key: "key1")
        let dictValue = try dict.get(key: "key1")
        #expect(resultValue == dictValue)
    }
}

// Extension to existing MockNode to add transform functionality
extension MockNode {
    func transform(transforms: ArrayTrie<Transform>) throws -> Self? {
        var newData = data
        
        // Handle direct single-level paths
        for key in transforms.getAllChildCharacters() {
            let pathKey = String(key)
            if let directValue = transforms.get([pathKey]) {
                switch directValue {
                case .insert(let value):
                    newData[pathKey] = value
                case .update(let value):
                    if data.keys.contains(pathKey) {
                        newData[pathKey] = value
                    }
                case .delete:
                    newData.removeValue(forKey: pathKey)
                }
            }
        }
        
        return MockNode(id: id, data: newData)
    }
}