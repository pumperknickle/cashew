import Testing
import Foundation
import ArrayTrie
@testable import cashew

@Suite("Complex Transform Tests")
struct ComplexTransformTests {
    
    @Test("Multiple simultaneous operations - comprehensive")
    func testMultipleSimultaneousOperationsComprehensive() throws {
        // Create a rich dataset
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "name", value: "Alice")
            .inserting(key: "email", value: "alice@example.com")
            .inserting(key: "age", value: "28")
            .inserting(key: "city", value: "Boston")
            .inserting(key: "country", value: "USA")
            .inserting(key: "status", value: "active")
            .inserting(key: "role", value: "engineer")
            .inserting(key: "salary", value: "75000")
            .inserting(key: "department", value: "backend")
            .inserting(key: "manager", value: "Bob")
            .inserting(key: "startDate", value: "2022-01-15")
            .inserting(key: "lastReview", value: "2023-12-01")
        
        // Apply comprehensive transforms
        var transforms = ArrayTrie<Transform>()
        
        // Profile updates
        transforms.set(["name"], value: .update("Alice Johnson"))
        transforms.set(["email"], value: .update("alice.johnson@company.com"))
        transforms.set(["age"], value: .update("29"))
        transforms.set(["city"], value: .update("San Francisco"))
        
        // Job changes
        transforms.set(["role"], value: .update("senior_engineer"))
        transforms.set(["salary"], value: .update("95000"))
        transforms.set(["department"], value: .update("frontend"))
        transforms.set(["manager"], value: .update("Carol"))
        
        // Add new fields
        transforms.set(["phone"], value: .insert("555-0123"))
        transforms.set(["linkedin"], value: .insert("linkedin.com/in/alice"))
        transforms.set(["skills"], value: .insert("Swift,TypeScript,React"))
        transforms.set(["promotion"], value: .insert("2024-01-15"))
        transforms.set(["newSalaryEffective"], value: .insert("2024-02-01"))
        
        // Remove obsolete fields
        transforms.set(["country"], value: .delete)
        transforms.set(["lastReview"], value: .delete)
        
        let result = try dict.transform(transforms: transforms)
        
        // Cross-verify with manual operations
        let manualResult = try dict
            .mutating(key: ArraySlice("name"), value: "Alice Johnson")
            .mutating(key: ArraySlice("email"), value: "alice.johnson@company.com")
            .mutating(key: ArraySlice("age"), value: "29")
            .mutating(key: ArraySlice("city"), value: "San Francisco")
            .mutating(key: ArraySlice("role"), value: "senior_engineer")
            .mutating(key: ArraySlice("salary"), value: "95000")
            .mutating(key: ArraySlice("department"), value: "frontend")
            .mutating(key: ArraySlice("manager"), value: "Carol")
            .inserting(key: "phone", value: "555-0123")
            .inserting(key: "linkedin", value: "linkedin.com/in/alice")
            .inserting(key: "skills", value: "Swift,TypeScript,React")
            .inserting(key: "promotion", value: "2024-01-15")
            .inserting(key: "newSalaryEffective", value: "2024-02-01")
            .deleting(key: "country")
            .deleting(key: "lastReview")
        
        // Verify both approaches give identical results
        #expect(result.count == manualResult.count)
        
        // Verify all updates
        #expect(try result.get(key: "name") == "Alice Johnson")
        #expect(try manualResult.get(key: "name") == "Alice Johnson")
        #expect(try result.get(key: "email") == "alice.johnson@company.com")
        #expect(try manualResult.get(key: "email") == "alice.johnson@company.com")
        #expect(try result.get(key: "role") == "senior_engineer")
        #expect(try manualResult.get(key: "role") == "senior_engineer")
        
        // Verify all insertions
        #expect(try result.get(key: "phone") == "555-0123")
        #expect(try manualResult.get(key: "phone") == "555-0123")
        #expect(try result.get(key: "skills") == "Swift,TypeScript,React")
        #expect(try manualResult.get(key: "skills") == "Swift,TypeScript,React")
        
        // Verify all deletions
        #expect(try result.get(key: "country") == nil)
        #expect(try manualResult.get(key: "country") == nil)
        #expect(try result.get(key: "lastReview") == nil)
        #expect(try manualResult.get(key: "lastReview") == nil)
        
        // Verify unchanged data
        #expect(try result.get(key: "status") == "active")
        #expect(try manualResult.get(key: "status") == "active")
        #expect(try result.get(key: "startDate") == "2022-01-15")
        #expect(try manualResult.get(key: "startDate") == "2022-01-15")
        
        #expect(result.count == 15) // 12 original - 2 deleted + 5 inserted
    }
    
    @Test("Sequential state machine-like transforms")
    func testSequentialStateMachineTransforms() throws {
        // Simulate a state machine workflow
        let initialState = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "state", value: "pending")
            .inserting(key: "submittedAt", value: "2024-01-10T10:00:00Z")
            .inserting(key: "submittedBy", value: "alice")
            .inserting(key: "priority", value: "medium")
            .inserting(key: "assignedTo", value: "unassigned")
        
        // Step 1: Assign and start processing
        var step1Transforms = ArrayTrie<Transform>()
        step1Transforms.set(["state"], value: .update("in_progress"))
        step1Transforms.set(["assignedTo"], value: .update("bob"))
        step1Transforms.set(["startedAt"], value: .insert("2024-01-10T14:30:00Z"))
        step1Transforms.set(["estimatedCompletion"], value: .insert("2024-01-12T17:00:00Z"))
        
        let afterStep1 = try initialState.transform(transforms: step1Transforms)
        
        // Step 2: Add progress updates
        var step2Transforms = ArrayTrie<Transform>()
        step2Transforms.set(["progress"], value: .insert("25"))
        step2Transforms.set(["lastUpdate"], value: .insert("2024-01-11T09:15:00Z"))
        step2Transforms.set(["notes"], value: .insert("Initial analysis completed"))
        step2Transforms.set(["estimatedCompletion"], value: .update("2024-01-13T12:00:00Z")) // Revised estimate
        
        let afterStep2 = try afterStep1.transform(transforms: step2Transforms)
        
        // Step 3: Complete the work
        var step3Transforms = ArrayTrie<Transform>()
        step3Transforms.set(["state"], value: .update("completed"))
        step3Transforms.set(["progress"], value: .update("100"))
        step3Transforms.set(["completedAt"], value: .insert("2024-01-12T16:45:00Z"))
        step3Transforms.set(["lastUpdate"], value: .update("2024-01-12T16:45:00Z"))
        step3Transforms.set(["notes"], value: .update("Work completed successfully"))
        step3Transforms.set(["estimatedCompletion"], value: .delete) // No longer needed
        
        let finalState = try afterStep2.transform(transforms: step3Transforms)
        
        // Cross-verify with equivalent manual operations
        let manualResult = try initialState
            // Step 1
            .mutating(key: ArraySlice("state"), value: "in_progress")
            .mutating(key: ArraySlice("assignedTo"), value: "bob")
            .inserting(key: "startedAt", value: "2024-01-10T14:30:00Z")
            .inserting(key: "estimatedCompletion", value: "2024-01-12T17:00:00Z")
            // Step 2  
            .inserting(key: "progress", value: "25")
            .inserting(key: "lastUpdate", value: "2024-01-11T09:15:00Z")
            .inserting(key: "notes", value: "Initial analysis completed")
            .mutating(key: ArraySlice("estimatedCompletion"), value: "2024-01-13T12:00:00Z")
            // Step 3
            .mutating(key: ArraySlice("state"), value: "completed")
            .mutating(key: ArraySlice("progress"), value: "100")
            .inserting(key: "completedAt", value: "2024-01-12T16:45:00Z")
            .mutating(key: ArraySlice("lastUpdate"), value: "2024-01-12T16:45:00Z")
            .mutating(key: ArraySlice("notes"), value: "Work completed successfully")
            .deleting(key: "estimatedCompletion")
        
        #expect(finalState.count == manualResult.count)
        
        // Verify final state
        #expect(try finalState.get(key: "state") == "completed")
        #expect(try manualResult.get(key: "state") == "completed")
        #expect(try finalState.get(key: "progress") == "100")
        #expect(try manualResult.get(key: "progress") == "100")
        #expect(try finalState.get(key: "assignedTo") == "bob")
        #expect(try manualResult.get(key: "assignedTo") == "bob")
        #expect(try finalState.get(key: "completedAt") == "2024-01-12T16:45:00Z")
        #expect(try manualResult.get(key: "completedAt") == "2024-01-12T16:45:00Z")
        #expect(try finalState.get(key: "estimatedCompletion") == nil)
        #expect(try manualResult.get(key: "estimatedCompletion") == nil)
        
        // Verify preserved original data
        #expect(try finalState.get(key: "submittedAt") == "2024-01-10T10:00:00Z")
        #expect(try manualResult.get(key: "submittedAt") == "2024-01-10T10:00:00Z")
        #expect(try finalState.get(key: "submittedBy") == "alice")
        #expect(try manualResult.get(key: "submittedBy") == "alice")
    }
    
    @Test("Bulk operations with systematic patterns")
    func testBulkOperationsWithSystematicPatterns() throws {
        // Create a moderate-sized dataset
        var dict = MerkleDictionaryImpl<String>(children: [:], count: 0)
        
        // Add 30 items with systematic naming
        for i in 1...30 {
            dict = try dict
                .inserting(key: "item\(i)", value: "value\(i)")
                .inserting(key: "type\(i)", value: i <= 15 ? "typeA" : "typeB")
        }
        
        // Add some metadata
        dict = try dict
            .inserting(key: "totalCount", value: "30")
            .inserting(key: "version", value: "1.0")
        
        // Apply systematic transforms using ArrayTrie
        var transforms = ArrayTrie<Transform>()
        
        // Update all typeA items (1-15)
        for i in 1...15 {
            transforms.set(["item\(i)"], value: .update("updatedValueA\(i)"))
        }
        
        // Delete every 5th item
        for i in [5, 10, 15, 20, 25, 30] {
            transforms.set(["item\(i)"], value: .delete)
            transforms.set(["type\(i)"], value: .delete)
        }
        
        // Add new items
        for i in 31...35 {
            transforms.set(["item\(i)"], value: .insert("newValue\(i)"))
            transforms.set(["type\(i)"], value: .insert("typeC"))
        }
        
        // Update metadata
        transforms.set(["totalCount"], value: .update("29")) // 30 - 6 deleted + 5 added
        transforms.set(["version"], value: .update("2.0"))
        transforms.set(["lastModified"], value: .insert("2024-01-15"))
        
        let result = try dict.transform(transforms: transforms)
        
        // Verify systematic updates
        #expect(try result.get(key: "item1") == "updatedValueA1")
        #expect(try result.get(key: "item14") == "updatedValueA14")
        
        // Verify deletions
        #expect(try result.get(key: "item5") == nil)
        #expect(try result.get(key: "item10") == nil)
        #expect(try result.get(key: "type20") == nil)
        
        // Verify unchanged typeB items
        #expect(try result.get(key: "item16") == "value16")
        #expect(try result.get(key: "item19") == "value19")
        #expect(try result.get(key: "type16") == "typeB")
        
        // Verify new additions
        #expect(try result.get(key: "item33") == "newValue33")
        #expect(try result.get(key: "type35") == "typeC")
        
        // Verify metadata
        #expect(try result.get(key: "totalCount") == "29")
        #expect(try result.get(key: "version") == "2.0")
        #expect(try result.get(key: "lastModified") == "2024-01-15")
        
        let expectedCount = 62 - 12 + 11 // 62 original - 12 deleted + 11 new
        #expect(result.count == expectedCount)
    }
    
    @Test("Complex data with special characters and edge cases")
    func testComplexDataWithSpecialCharacters() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "simpleText", value: "Hello World")
            .inserting(key: "emptyValue", value: "")
            .inserting(key: "numbersOnly", value: "12345")
            .inserting(key: "unicodeText", value: "Hello 世界 🌍")
            .inserting(key: "jsonLike", value: "{\"name\":\"value\"}")
            .inserting(key: "withSpaces", value: "  spaced text  ")
            .inserting(key: "multiline", value: "line1\nline2\nline3")
            .inserting(key: "specialChars", value: "!@#$%^&*()")
        
        var transforms = ArrayTrie<Transform>()
        
        // Update with various complex values
        transforms.set(["simpleText"], value: .update("Goodbye World"))
        transforms.set(["emptyValue"], value: .update("now has content"))
        transforms.set(["numbersOnly"], value: .update("67890"))
        transforms.set(["unicodeText"], value: .update("Bonjour 🇫🇷 Monde!"))
        transforms.set(["jsonLike"], value: .update("{\"updated\": true, \"timestamp\": \"2024-01-15\"}"))
        
        // Delete some items
        transforms.set(["withSpaces"], value: .delete)
        transforms.set(["specialChars"], value: .delete)
        
        // Add new complex values
        transforms.set(["xmlLike"], value: .insert("<root><item>test</item></root>"))
        transforms.set(["quotesAndEscapes"], value: .insert("He said \"Hello!\" and she replied: 'Hi!'"))
        transforms.set(["tabsAndNewlines"], value: .insert("col1\tcol2\tcol3\nrow1\tdata1\tdata2"))
        transforms.set(["veryLongText"], value: .insert(String(repeating: "Lorem ipsum ", count: 100)))
        
        let result = try dict.transform(transforms: transforms)
        
        // Cross-verify with manual operations
        let manualResult = try dict
            .mutating(key: ArraySlice("simpleText"), value: "Goodbye World")
            .mutating(key: ArraySlice("emptyValue"), value: "now has content")
            .mutating(key: ArraySlice("numbersOnly"), value: "67890")
            .mutating(key: ArraySlice("unicodeText"), value: "Bonjour 🇫🇷 Monde!")
            .mutating(key: ArraySlice("jsonLike"), value: "{\"updated\": true, \"timestamp\": \"2024-01-15\"}")
            .deleting(key: "withSpaces")
            .deleting(key: "specialChars")
            .inserting(key: "xmlLike", value: "<root><item>test</item></root>")
            .inserting(key: "quotesAndEscapes", value: "He said \"Hello!\" and she replied: 'Hi!'")
            .inserting(key: "tabsAndNewlines", value: "col1\tcol2\tcol3\nrow1\tdata1\tdata2")
            .inserting(key: "veryLongText", value: String(repeating: "Lorem ipsum ", count: 100))
        
        #expect(result.count == manualResult.count)
        
        // Verify complex updates
        #expect(try result.get(key: "unicodeText") == "Bonjour 🇫🇷 Monde!")
        #expect(try manualResult.get(key: "unicodeText") == "Bonjour 🇫🇷 Monde!")
        #expect(try result.get(key: "jsonLike") == "{\"updated\": true, \"timestamp\": \"2024-01-15\"}")
        #expect(try manualResult.get(key: "jsonLike") == "{\"updated\": true, \"timestamp\": \"2024-01-15\"}")
        
        // Verify complex insertions
        #expect(try result.get(key: "xmlLike") == "<root><item>test</item></root>")
        #expect(try manualResult.get(key: "xmlLike") == "<root><item>test</item></root>")
        #expect(try result.get(key: "quotesAndEscapes") == "He said \"Hello!\" and she replied: 'Hi!'")
        #expect(try manualResult.get(key: "quotesAndEscapes") == "He said \"Hello!\" and she replied: 'Hi!'")
        
        // Verify deletions
        #expect(try result.get(key: "withSpaces") == nil)
        #expect(try manualResult.get(key: "withSpaces") == nil)
        #expect(try result.get(key: "specialChars") == nil)
        #expect(try manualResult.get(key: "specialChars") == nil)
        
        // Verify preserved data
        #expect(try result.get(key: "multiline") == "line1\nline2\nline3")
        #expect(try manualResult.get(key: "multiline") == "line1\nline2\nline3")
        
        #expect(result.count == 10) // 8 original - 2 deleted + 4 inserted
    }
    
    @Test("Mixed operations with overlapping keys showing ArrayTrie behavior")
    func testMixedOperationsWithOverlappingKeys() throws {
        let dict = try MerkleDictionaryImpl<String>(children: [:], count: 0)
            .inserting(key: "key1", value: "original1")
            .inserting(key: "key2", value: "original2")
            .inserting(key: "key3", value: "original3")
            .inserting(key: "key4", value: "original4")
        
        var transforms = ArrayTrie<Transform>()
        
        // Apply multiple operations to the same key to test ArrayTrie behavior
        transforms.set(["key1"], value: .update("first_update"))
        transforms.set(["key1"], value: .update("second_update"))
        transforms.set(["key1"], value: .update("final_update")) // Should win
        
        // Mix operations on another key
        transforms.set(["key2"], value: .update("updated"))
        transforms.set(["key2"], value: .delete) // Delete should override
        
        // Standard operations
        transforms.set(["key3"], value: .update("updated3"))
        transforms.set(["key4"], value: .delete)
        
        // New keys
        transforms.set(["key5"], value: .insert("new5"))
        transforms.set(["key6"], value: .insert("new6"))
        
        let result = try dict.transform(transforms: transforms)
        
        // Verify ArrayTrie conflict resolution behavior
        #expect(try result.get(key: "key1") == "final_update")
        #expect(try result.get(key: "key2") == nil) // Delete wins
        #expect(try result.get(key: "key3") == "updated3")
        #expect(try result.get(key: "key4") == nil)
        #expect(try result.get(key: "key5") == "new5")
        #expect(try result.get(key: "key6") == "new6")
        
        #expect(result.count == 4) // 4 original - 2 deleted + 2 inserted
    }
}