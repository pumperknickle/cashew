import Testing
import Foundation
import ArrayTrie
import Crypto
@preconcurrency import Multicodec
@testable import cashew

@Suite("Encryption Acceptance Tests")
struct EncryptionAcceptanceTests {

    struct TestScalar: Scalar {
        let val: Int
        init(val: Int) { self.val = val }
    }

    typealias ScalarHeader = HeaderImpl<TestScalar>
    typealias ScalarDict = MerkleDictionaryImpl<ScalarHeader>
    typealias InnerDict = MerkleDictionaryImpl<String>
    typealias OuterDict = MerkleDictionaryImpl<HeaderImpl<InnerDict>>

    // MARK: - Multi-tenant encrypted store

    @Test("Multi-tenant: each tenant's data encrypted with own key, shared store")
    func testMultiTenantIsolation() async throws {
        let aliceKey = SymmetricKey(size: .bits256)
        let bobKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(aliceKey)
        store.registerKey(bobKey)

        let aliceData = try InnerDict()
            .inserting(key: "name", value: "Alice")
            .inserting(key: "email", value: "alice@example.com")
            .inserting(key: "ssn", value: "123-45-6789")
        let bobData = try InnerDict()
            .inserting(key: "name", value: "Bob")
            .inserting(key: "email", value: "bob@example.com")
            .inserting(key: "ssn", value: "987-65-4321")

        let aliceHeader = try HeaderImpl(node: aliceData, key: aliceKey)
        let bobHeader = try HeaderImpl(node: bobData, key: bobKey)

        var tenants = OuterDict()
        tenants = try tenants.inserting(key: "alice", value: aliceHeader)
        tenants = try tenants.inserting(key: "bob", value: bobHeader)
        let root = HeaderImpl(node: tenants)

        try root.storeRecursively(storer: store)

        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)
        let aliceResolved = try await resolved.node!.get(key: "alice")!.resolve(fetcher: store)
        #expect(try aliceResolved.node!.get(key: "ssn") == "123-45-6789")

        let bobResolved = try await resolved.node!.get(key: "bob")!.resolve(fetcher: store)
        #expect(try bobResolved.node!.get(key: "name") == "Bob")

        let aliceKeyData = aliceKey.withUnsafeBytes { Data($0) }
        let bobKeyData = bobKey.withUnsafeBytes { Data($0) }
        let aliceKeyHash = Data(SHA256.hash(data: aliceKeyData)).base64EncodedString()
        let bobKeyHash = Data(SHA256.hash(data: bobKeyData)).base64EncodedString()
        #expect(aliceResolved.encryptionInfo!.keyHash == aliceKeyHash)
        #expect(bobResolved.encryptionInfo!.keyHash == bobKeyHash)
        #expect(aliceResolved.encryptionInfo!.keyHash != bobResolved.encryptionInfo!.keyHash)
    }

    @Test("Multi-tenant: holder of one key cannot decrypt other tenant's data")
    func testMultiTenantKeyIsolation() async throws {
        let aliceKey = SymmetricKey(size: .bits256)
        let bobKey = SymmetricKey(size: .bits256)

        let fullStore = TestKeyProvidingStoreFetcher()
        fullStore.registerKey(aliceKey)
        fullStore.registerKey(bobKey)

        let aliceHeader = try ScalarHeader(node: TestScalar(val: 42), key: aliceKey)
        let bobHeader = try ScalarHeader(node: TestScalar(val: 99), key: bobKey)

        try aliceHeader.storeRecursively(storer: fullStore)
        try bobHeader.storeRecursively(storer: fullStore)

        let aliceOnlyStore = TestKeyProvidingStoreFetcher()
        aliceOnlyStore.registerKey(aliceKey)
        let aliceData = try await fullStore.fetch(rawCid: aliceHeader.rawCID)
        aliceOnlyStore.storeRaw(rawCid: aliceHeader.rawCID, data: aliceData)
        let bobData = try await fullStore.fetch(rawCid: bobHeader.rawCID)
        aliceOnlyStore.storeRaw(rawCid: bobHeader.rawCID, data: bobData)

        let aliceResolved = try await aliceHeader.removingNode().resolve(fetcher: aliceOnlyStore)
        #expect(aliceResolved.node!.val == 42)

        await #expect(throws: (any Error).self) {
            _ = try await bobHeader.removingNode().resolve(fetcher: aliceOnlyStore)
        }
    }

    // MARK: - Selective disclosure: public profile + private details

    @Test("Selective disclosure: public fields readable, private fields encrypted")
    func testSelectiveDisclosure() async throws {
        let privacyKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(privacyKey)

        var userProfile = ScalarDict()
        userProfile = try userProfile.inserting(key: "username", value: ScalarHeader(node: TestScalar(val: 1001)))
        userProfile = try userProfile.inserting(key: "display_name", value: ScalarHeader(node: TestScalar(val: 1002)))
        userProfile = try userProfile.inserting(key: "email", value: ScalarHeader(node: TestScalar(val: 2001)))
        userProfile = try userProfile.inserting(key: "phone", value: ScalarHeader(node: TestScalar(val: 2002)))
        userProfile = try userProfile.inserting(key: "address", value: ScalarHeader(node: TestScalar(val: 2003)))
        let header = HeaderImpl(node: userProfile)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["email"], value: .targeted(privacyKey))
        encryption.set(["phone"], value: .targeted(privacyKey))
        encryption.set(["address"], value: .targeted(privacyKey))
        let encrypted = try header.encrypt(encryption: encryption)

        let publicUsername = try encrypted.node!.get(key: "username")!
        let publicDisplayName = try encrypted.node!.get(key: "display_name")!
        #expect(publicUsername.encryptionInfo == nil)
        #expect(publicDisplayName.encryptionInfo == nil)
        #expect(publicUsername.node!.val == 1001)

        let encEmail = try encrypted.node!.get(key: "email")!
        let encPhone = try encrypted.node!.get(key: "phone")!
        let encAddress = try encrypted.node!.get(key: "address")!
        #expect(encEmail.encryptionInfo != nil)
        #expect(encPhone.encryptionInfo != nil)
        #expect(encAddress.encryptionInfo != nil)

        try encrypted.storeRecursively(storer: store)
        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: store)
        let emailResolved = try await resolved.node!.get(key: "email")!.resolve(fetcher: store)
        #expect(emailResolved.node!.val == 2001)
    }

    // MARK: - Nested encrypted dictionaries (two-level)

    @Test("Two-level nesting: inner values encrypted per-key, store and resolve all")
    func testTwoLevelNestedEncryption() async throws {
        let outerKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(outerKey)

        let departments = try InnerDict()
            .inserting(key: "engineering", value: "50 people")
            .inserting(key: "marketing", value: "20 people")
            .inserting(key: "sales", value: "30 people")
        let departmentHeader = try HeaderImpl(node: departments, key: outerKey)

        let budgets = try InnerDict()
            .inserting(key: "q1", value: "1000000")
            .inserting(key: "q2", value: "1200000")
        let budgetHeader = try HeaderImpl(node: budgets, key: outerKey)

        var company = MerkleDictionaryImpl<HeaderImpl<InnerDict>>()
        company = try company.inserting(key: "departments", value: departmentHeader)
        company = try company.inserting(key: "budgets", value: budgetHeader)
        let root = HeaderImpl(node: company)

        let deptVal = try root.node!.get(key: "departments")!
        #expect(deptVal.encryptionInfo != nil)
        let budgetVal = try root.node!.get(key: "budgets")!
        #expect(budgetVal.encryptionInfo != nil)

        try root.storeRecursively(storer: store)
        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)
        let deptResolved = try await resolved.node!.get(key: "departments")!.resolve(fetcher: store)
        #expect(try deptResolved.node!.get(key: "engineering") == "50 people")
        #expect(try deptResolved.node!.get(key: "sales") == "30 people")

        let budgetResolved = try await resolved.node!.get(key: "budgets")!.resolve(fetcher: store)
        #expect(try budgetResolved.node!.get(key: "q1") == "1000000")
    }

    @Test("Two-level nesting: different keys per branch")
    func testTwoLevelDifferentKeysPerBranch() async throws {
        let publicKey = SymmetricKey(size: .bits256)
        let financeKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(publicKey)
        store.registerKey(financeKey)

        let publicInfo = try InnerDict()
            .inserting(key: "mission", value: "Build great software")
            .inserting(key: "founded", value: "2020")
        let publicHeader = try HeaderImpl(node: publicInfo, key: publicKey)

        let financeInfo = try InnerDict()
            .inserting(key: "revenue", value: "5000000")
            .inserting(key: "burn_rate", value: "200000")
        let financeHeader = try HeaderImpl(node: financeInfo, key: financeKey)

        var company = MerkleDictionaryImpl<HeaderImpl<InnerDict>>()
        company = try company.inserting(key: "public", value: publicHeader)
        company = try company.inserting(key: "finance", value: financeHeader)
        let root = HeaderImpl(node: company)

        let publicKeyData = publicKey.withUnsafeBytes { Data($0) }
        let financeKeyData = financeKey.withUnsafeBytes { Data($0) }
        let publicKeyHash = Data(SHA256.hash(data: publicKeyData)).base64EncodedString()
        let financeKeyHash = Data(SHA256.hash(data: financeKeyData)).base64EncodedString()

        let encPublic = try root.node!.get(key: "public")!
        let encFinance = try root.node!.get(key: "finance")!
        #expect(encPublic.encryptionInfo!.keyHash == publicKeyHash)
        #expect(encFinance.encryptionInfo!.keyHash == financeKeyHash)

        try root.storeRecursively(storer: store)
        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)
        let pubResolved = try await resolved.node!.get(key: "public")!.resolve(fetcher: store)
        #expect(try pubResolved.node!.get(key: "mission") == "Build great software")
        let finResolved = try await resolved.node!.get(key: "finance")!.resolve(fetcher: store)
        #expect(try finResolved.node!.get(key: "revenue") == "5000000")
    }

    // MARK: - Encrypt → Transform → Store → Resolve full lifecycle

    @Test("Full lifecycle: recursive encrypt, delete, store, resolve")
    func testFullLifecycleDeleteFromEncrypted() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "alice", value: ScalarHeader(node: TestScalar(val: 10)))
        dict = try dict.inserting(key: "bob", value: ScalarHeader(node: TestScalar(val: 20)))
        dict = try dict.inserting(key: "charlie", value: ScalarHeader(node: TestScalar(val: 30)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let aliceVal = try encrypted.node!.get(key: "alice")!
        #expect(aliceVal.encryptionInfo != nil)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alice"], value: .delete)
        let transformed = try encrypted.transform(transforms: transforms, keyProvider: store)!

        #expect(transformed.node!.count == 2)
        #expect(try transformed.node!.get(key: "alice") == nil)

        let bobVal = try transformed.node!.get(key: "bob")!
        #expect(bobVal.encryptionInfo != nil)

        try transformed.storeRecursively(storer: store)

        let resolved = try await transformed.removingNode().resolveRecursive(fetcher: store)
        let bobResolved = try await resolved.node!.get(key: "bob")!.resolve(fetcher: store)
        #expect(bobResolved.node!.val == 20)

        let charlieResolved = try await resolved.node!.get(key: "charlie")!.resolve(fetcher: store)
        #expect(charlieResolved.node!.val == 30)
    }

    @Test("Full lifecycle: encrypt values directly, mutate dict, store, resolve")
    func testFullLifecycleDirectMutate() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "counter", value: try ScalarHeader(node: TestScalar(val: 0), key: key))
        dict = try dict.inserting(key: "label", value: try ScalarHeader(node: TestScalar(val: 100), key: key))
        let header = HeaderImpl(node: dict)

        try header.storeRecursively(storer: store)

        let newCounter = try ScalarHeader(node: TestScalar(val: 42), key: key)
        let mutated = try dict.mutating(key: "counter", value: newCounter)
        let mutatedHeader = HeaderImpl(node: mutated)
        try mutatedHeader.storeRecursively(storer: store)

        let resolved = try await mutatedHeader.removingNode().resolveRecursive(fetcher: store)
        let counterResolved = try await resolved.node!.get(key: "counter")!.resolve(fetcher: store)
        #expect(counterResolved.node!.val == 42)

        let labelResolved = try await resolved.node!.get(key: "label")!.resolve(fetcher: store)
        #expect(labelResolved.node!.val == 100)
    }

    @Test("Full lifecycle: encrypt, insert new encrypted value, store, resolve")
    func testFullLifecycleInsertEncryptedValue() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "existing", value: try ScalarHeader(node: TestScalar(val: 1), key: key))
        let header = HeaderImpl(node: dict)

        let newVal = try ScalarHeader(node: TestScalar(val: 99), key: key)
        let withInsert = try dict.inserting(key: "added", value: newVal)
        let insertedHeader = HeaderImpl(node: withInsert)

        let addedVal = try insertedHeader.node!.get(key: "added")!
        #expect(addedVal.encryptionInfo != nil)

        try insertedHeader.storeRecursively(storer: store)
        let resolved = try await insertedHeader.removingNode().resolveRecursive(fetcher: store)
        let addedResolved = try await resolved.node!.get(key: "added")!.resolve(fetcher: store)
        #expect(addedResolved.node!.val == 99)

        let existingResolved = try await resolved.node!.get(key: "existing")!.resolve(fetcher: store)
        #expect(existingResolved.node!.val == 1)
    }

    // MARK: - Repeated transforms on encrypted data

    @Test("Multiple sequential transforms preserve encryption on values")
    func testRepeatedTransformsPreserveEncryption() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        for i in 1...5 {
            dict = try dict.inserting(key: "item\(i)", value: ScalarHeader(node: TestScalar(val: i)))
        }
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        var current = try header.encrypt(encryption: encryption)

        for (_, child) in current.node!.children {
            #expect(child.encryptionInfo != nil)
        }

        var transforms1 = ArrayTrie<Transform>()
        transforms1.set(["item1"], value: .delete)
        current = try current.transform(transforms: transforms1, keyProvider: store)!
        #expect(current.node!.count == 4)
        let item2After1 = try current.node!.get(key: "item2")!
        #expect(item2After1.encryptionInfo != nil)

        let newItem3 = ScalarHeader(node: TestScalar(val: 300))
        try newItem3.storeRecursively(storer: store)
        var transforms2 = ArrayTrie<Transform>()
        transforms2.set(["item3"], value: .update(newItem3.description))
        current = try current.transform(transforms: transforms2, keyProvider: store)!
        #expect(current.node!.count == 4)

        try current.storeRecursively(storer: store)
        let resolved = try await current.removingNode().resolveRecursive(fetcher: store)

        #expect(try resolved.node!.get(key: "item1") == nil)
        let item2 = try await resolved.node!.get(key: "item2")!.resolve(fetcher: store)
        #expect(item2.node!.val == 2)
        let item3 = try await resolved.node!.get(key: "item3")!.resolve(fetcher: store)
        #expect(item3.node!.val == 300)
    }

    // MARK: - Large encrypted dictionary

    @Test("50-key encrypted dictionary: full encrypt, store, resolve cycle")
    func testLargeEncryptedDictionary() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        for i in 0..<50 {
            dict = try dict.inserting(
                key: "record_\(String(format: "%03d", i))",
                value: ScalarHeader(node: TestScalar(val: i * 7))
            )
        }
        #expect(dict.count == 50)
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        try encrypted.storeRecursively(storer: store)

        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: store)
        #expect(resolved.node!.count == 50)

        for i in [0, 10, 25, 40, 49] {
            let k = "record_\(String(format: "%03d", i))"
            let val = try resolved.node!.get(key: k)!
            #expect(val.encryptionInfo != nil)
            let valResolved = try await val.resolve(fetcher: store)
            #expect(valResolved.node!.val == i * 7)
        }
    }

    @Test("50-key encrypted dictionary: delete subset, store, resolve survivors")
    func testLargeEncryptedDictDeleteSubset() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        for i in 0..<50 {
            dict = try dict.inserting(
                key: "r\(String(format: "%03d", i))",
                value: ScalarHeader(node: TestScalar(val: i))
            )
        }
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        var transforms = ArrayTrie<Transform>()
        for i in stride(from: 0, to: 50, by: 5) {
            transforms.set(["r\(String(format: "%03d", i))"], value: .delete)
        }

        let result = try encrypted.transform(transforms: transforms, keyProvider: store)!
        #expect(result.node!.count == 40)

        try result.storeRecursively(storer: store)
        let resolved = try await result.removingNode().resolveRecursive(fetcher: store)

        #expect(try resolved.node!.get(key: "r000") == nil)
        #expect(try resolved.node!.get(key: "r005") == nil)

        let r001 = try await resolved.node!.get(key: "r001")!.resolve(fetcher: store)
        #expect(r001.node!.val == 1)
        let r049 = try await resolved.node!.get(key: "r049")!.resolve(fetcher: store)
        #expect(r049.node!.val == 49)
    }

    // MARK: - Serialization round-trips with encryption

    @Test("Encrypted header description round-trips through store/resolve")
    func testEncryptedDescriptionRoundTrip() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        let scalar = TestScalar(val: 777)
        let encrypted = try ScalarHeader(node: scalar, key: key)
        try encrypted.storeRecursively(storer: store)

        let description = encrypted.description
        #expect(description.hasPrefix("enc:"))

        let restored = ScalarHeader(description)!
        #expect(restored.rawCID == encrypted.rawCID)
        #expect(restored.encryptionInfo == encrypted.encryptionInfo)
        #expect(restored.node == nil)

        let resolved = try await restored.resolve(fetcher: store)
        #expect(resolved.node!.val == 777)
    }

    @Test("Encrypted nested dict headers serialize/deserialize correctly within parent")
    func testEncryptedNestedSerialization() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        let inner = try InnerDict()
            .inserting(key: "a", value: "1")
            .inserting(key: "b", value: "2")
        let innerEncrypted = try HeaderImpl(node: inner, key: key)

        var outer = OuterDict()
        outer = try outer.inserting(key: "encrypted_child", value: innerEncrypted)
        outer = try outer.inserting(key: "plain_child", value: HeaderImpl(node: try InnerDict().inserting(key: "c", value: "3")))
        let root = HeaderImpl(node: outer)

        try root.storeRecursively(storer: store)

        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)

        let encChild = try resolved.node!.get(key: "encrypted_child")!
        #expect(encChild.encryptionInfo != nil)
        let encChildResolved = try await encChild.resolve(fetcher: store)
        #expect(try encChildResolved.node!.get(key: "a") == "1")

        let plainChild = try resolved.node!.get(key: "plain_child")!
        #expect(plainChild.encryptionInfo == nil)
        let plainChildResolved = try await plainChild.resolve(fetcher: store)
        #expect(try plainChildResolved.node!.get(key: "c") == "3")
    }

    // MARK: - Mixed strategies on same tree

    @Test("Mixed strategies: targeted encryption on specific fields, rest plaintext")
    func testMixedStrategiesOnSameTree() async throws {
        let targetKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(targetKey)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "public_a", value: ScalarHeader(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "public_b", value: ScalarHeader(node: TestScalar(val: 2)))
        dict = try dict.inserting(key: "secret_x", value: ScalarHeader(node: TestScalar(val: 100)))
        dict = try dict.inserting(key: "secret_y", value: ScalarHeader(node: TestScalar(val: 200)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["secret_x"], value: .targeted(targetKey))
        encryption.set(["secret_y"], value: .targeted(targetKey))
        let encrypted = try header.encrypt(encryption: encryption)

        let pubA = try encrypted.node!.get(key: "public_a")!
        #expect(pubA.encryptionInfo == nil)
        #expect(pubA.node!.val == 1)

        let secX = try encrypted.node!.get(key: "secret_x")!
        #expect(secX.encryptionInfo != nil)

        try encrypted.storeRecursively(storer: store)
        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: store)
        let secXResolved = try await resolved.node!.get(key: "secret_x")!.resolve(fetcher: store)
        #expect(secXResolved.node!.val == 100)
    }

    // MARK: - Encryption with prefix-sharing keys

    @Test("Encryption preserves correctness with keys sharing common prefixes")
    func testEncryptionWithSharedPrefixKeys() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "user", value: ScalarHeader(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "username", value: ScalarHeader(node: TestScalar(val: 2)))
        dict = try dict.inserting(key: "user_profile", value: ScalarHeader(node: TestScalar(val: 3)))
        dict = try dict.inserting(key: "user_settings", value: ScalarHeader(node: TestScalar(val: 4)))
        dict = try dict.inserting(key: "user_settings_theme", value: ScalarHeader(node: TestScalar(val: 5)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        for k in ["user", "username", "user_profile", "user_settings", "user_settings_theme"] {
            let val = try encrypted.node!.get(key: k)
            #expect(val != nil)
            #expect(val!.encryptionInfo != nil)
        }

        try encrypted.storeRecursively(storer: store)
        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: store)

        for (k, expected) in [("user", 1), ("username", 2), ("user_profile", 3), ("user_settings", 4), ("user_settings_theme", 5)] {
            let val = try await resolved.node!.get(key: k)!.resolve(fetcher: store)
            #expect(val.node!.val == expected)
        }
    }

    // MARK: - Auditability: verify structure without decrypting

    @Test("Auditor can enumerate keys and verify CIDs without decryption (targeted)")
    func testAuditabilityWithoutKeys() throws {
        let key = SymmetricKey(size: .bits256)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "record1", value: ScalarHeader(node: TestScalar(val: 100)))
        dict = try dict.inserting(key: "record2", value: ScalarHeader(node: TestScalar(val: 200)))
        dict = try dict.inserting(key: "record3", value: ScalarHeader(node: TestScalar(val: 300)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["record1"], value: .targeted(key))
        encryption.set(["record2"], value: .targeted(key))
        encryption.set(["record3"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        #expect(encrypted.node!.count == 3)

        let record1 = try encrypted.node!.get(key: "record1")!
        #expect(record1.encryptionInfo != nil)
        #expect(record1.rawCID.isEmpty == false)

        let record2 = try encrypted.node!.get(key: "record2")!
        #expect(record2.rawCID != record1.rawCID)

        let keys = try encrypted.node!.allKeys()
        #expect(keys.count == 3)
        #expect(keys.contains("record1"))
        #expect(keys.contains("record2"))
        #expect(keys.contains("record3"))
    }

    // MARK: - Re-encryption produces new CIDs

    @Test("Re-encrypting same data produces different CIDs (random IV)")
    func testReEncryptionProducesDifferentCIDs() throws {
        let key = SymmetricKey(size: .bits256)
        let scalar = TestScalar(val: 42)

        let enc1 = try ScalarHeader(node: scalar, key: key)
        let enc2 = try ScalarHeader(node: scalar, key: key)

        #expect(enc1.rawCID != enc2.rawCID)
        #expect(enc1.encryptionInfo!.keyHash == enc2.encryptionInfo!.keyHash)
        #expect(enc1.encryptionInfo!.iv != enc2.encryptionInfo!.iv)
    }

    // MARK: - Encryption with single-entry dict edge case

    @Test("Single-entry encrypted dict: delete only entry via recursive encrypt")
    func testSingleEntryEncryptedDelete() throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "only", value: ScalarHeader(node: TestScalar(val: 42)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["only"], value: .delete)
        let result = try encrypted.transform(transforms: transforms, keyProvider: store)!

        #expect(result.node!.count == 0)
    }

    @Test("Single-entry dict: encrypt value directly, mutate, store, resolve")
    func testSingleEntryEncryptedMutateStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "only", value: try ScalarHeader(node: TestScalar(val: 1), key: key))
        let header = HeaderImpl(node: dict)

        let onlyBefore = try header.node!.get(key: "only")!
        #expect(onlyBefore.encryptionInfo != nil)

        let newVal = try ScalarHeader(node: TestScalar(val: 999), key: key)
        let mutated = try dict.mutating(key: "only", value: newVal)
        let mutatedHeader = HeaderImpl(node: mutated)

        try mutatedHeader.storeRecursively(storer: store)

        let resolved = try await mutatedHeader.removingNode().resolveRecursive(fetcher: store)
        let onlyResolved = try await resolved.node!.get(key: "only")!.resolve(fetcher: store)
        #expect(onlyResolved.node!.val == 999)
    }

    // MARK: - Backward compatibility

    @Test("Plaintext operations still work identically without encryption")
    func testPlaintextBackwardCompatibility() async throws {
        let store = TestKeyProvidingStoreFetcher()

        var dict = ScalarDict()
        dict = try dict.inserting(key: "a", value: ScalarHeader(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "b", value: ScalarHeader(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        try header.storeRecursively(storer: store)

        let resolved = try await header.removingNode().resolveRecursive(fetcher: store)
        #expect(resolved.node!.count == 2)
        let aResolved = try await resolved.node!.get(key: "a")!.resolve(fetcher: store)
        #expect(aResolved.node!.val == 1)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["c"], value: .insert(ScalarHeader(node: TestScalar(val: 3)).description))
        let transformed = try header.transform(transforms: transforms)!
        #expect(transformed.encryptionInfo == nil)
        #expect(transformed.node!.count == 3)
    }

    // MARK: - Three-level nested with encryption

    @Test("Three-level nesting: encrypted values at each level, store, resolve all")
    func testThreeLevelNestedEncryption() async throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        let leaf1 = try InnerDict()
            .inserting(key: "color", value: "red")
            .inserting(key: "size", value: "large")
        let leaf2 = try InnerDict()
            .inserting(key: "color", value: "blue")
            .inserting(key: "weight", value: "10kg")

        let mid = try MerkleDictionaryImpl<HeaderImpl<InnerDict>>()
            .inserting(key: "itemA", value: try HeaderImpl(node: leaf1, key: key))
            .inserting(key: "itemB", value: try HeaderImpl(node: leaf2, key: key))

        let top = try MerkleDictionaryImpl<HeaderImpl<MerkleDictionaryImpl<HeaderImpl<InnerDict>>>>()
            .inserting(key: "warehouse", value: try HeaderImpl(node: mid, key: key))

        let root = HeaderImpl(node: top)

        let warehouseVal = try root.node!.get(key: "warehouse")!
        #expect(warehouseVal.encryptionInfo != nil)

        try root.storeRecursively(storer: store)

        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)
        let warehouseResolved = try await resolved.node!.get(key: "warehouse")!.resolve(fetcher: store)
        let itemAResolved = try await warehouseResolved.node!.get(key: "itemA")!.resolve(fetcher: store)
        #expect(try itemAResolved.node!.get(key: "color") == "red")
        #expect(try itemAResolved.node!.get(key: "size") == "large")

        let itemBResolved = try await warehouseResolved.node!.get(key: "itemB")!.resolve(fetcher: store)
        #expect(try itemBResolved.node!.get(key: "weight") == "10kg")
    }

    @Test("Three-level nesting: different keys at different levels")
    func testThreeLevelDifferentKeysPerLevel() async throws {
        let outerKey = SymmetricKey(size: .bits256)
        let leafKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(outerKey)
        store.registerKey(leafKey)

        let leaf = try InnerDict()
            .inserting(key: "secret", value: "classified")

        let mid = try MerkleDictionaryImpl<HeaderImpl<InnerDict>>()
            .inserting(key: "data", value: try HeaderImpl(node: leaf, key: leafKey))

        var outer = MerkleDictionaryImpl<HeaderImpl<MerkleDictionaryImpl<HeaderImpl<InnerDict>>>>()
        outer = try outer.inserting(key: "branch", value: try HeaderImpl(node: mid, key: outerKey))
        let root = HeaderImpl(node: outer)

        let branchVal = try root.node!.get(key: "branch")!
        #expect(branchVal.encryptionInfo != nil)

        let outerKeyData = outerKey.withUnsafeBytes { Data($0) }
        let outerKeyHash = Data(SHA256.hash(data: outerKeyData)).base64EncodedString()
        #expect(branchVal.encryptionInfo!.keyHash == outerKeyHash)

        try root.storeRecursively(storer: store)
        let resolved = try await root.removingNode().resolveRecursive(fetcher: store)
        let branchResolved = try await resolved.node!.get(key: "branch")!.resolve(fetcher: store)
        let dataVal = try branchResolved.node!.get(key: "data")!

        let leafKeyData = leafKey.withUnsafeBytes { Data($0) }
        let leafKeyHash = Data(SHA256.hash(data: leafKeyData)).base64EncodedString()
        #expect(dataVal.encryptionInfo!.keyHash == leafKeyHash)

        let dataResolved = try await dataVal.resolve(fetcher: store)
        #expect(try dataResolved.node!.get(key: "secret") == "classified")
    }

    // MARK: - Recursive encryption with per-user key overrides

    @Test("Recursive encryption with per-user key overrides")
    func testRecursiveWithPerUserOverrides() async throws {
        let teamKey = SymmetricKey(size: .bits256)
        let aliceKey = SymmetricKey(size: .bits256)
        let bobKey = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(teamKey)
        store.registerKey(aliceKey)
        store.registerKey(bobKey)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "alice", value: ScalarHeader(node: TestScalar(val: 10)))
        dict = try dict.inserting(key: "bob", value: ScalarHeader(node: TestScalar(val: 20)))
        dict = try dict.inserting(key: "shared", value: ScalarHeader(node: TestScalar(val: 30)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(teamKey))
        encryption.set(["alice"], value: .recursive(aliceKey))
        encryption.set(["bob"], value: .recursive(bobKey))
        let encrypted = try header.encrypt(encryption: encryption)

        let aliceKeyData = aliceKey.withUnsafeBytes { Data($0) }
        let aliceKeyHash = Data(SHA256.hash(data: aliceKeyData)).base64EncodedString()
        let bobKeyData = bobKey.withUnsafeBytes { Data($0) }
        let bobKeyHash = Data(SHA256.hash(data: bobKeyData)).base64EncodedString()
        let teamKeyData = teamKey.withUnsafeBytes { Data($0) }
        let teamKeyHash = Data(SHA256.hash(data: teamKeyData)).base64EncodedString()

        let aliceVal = try encrypted.node!.get(key: "alice")!
        #expect(aliceVal.encryptionInfo!.keyHash == aliceKeyHash)
        let bobVal = try encrypted.node!.get(key: "bob")!
        #expect(bobVal.encryptionInfo!.keyHash == bobKeyHash)
        let sharedVal = try encrypted.node!.get(key: "shared")!
        #expect(sharedVal.encryptionInfo!.keyHash == teamKeyHash)

        try encrypted.storeRecursively(storer: store)
        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: store)

        let aliceResolved = try await resolved.node!.get(key: "alice")!.resolve(fetcher: store)
        #expect(aliceResolved.node!.val == 10)
        let bobResolved = try await resolved.node!.get(key: "bob")!.resolve(fetcher: store)
        #expect(bobResolved.node!.val == 20)
        let sharedResolved = try await resolved.node!.get(key: "shared")!.resolve(fetcher: store)
        #expect(sharedResolved.node!.val == 30)
    }

    // MARK: - List encryption preserved through transforms

    @Test("List-encrypted dict: transform preserves RadixHeader encryption")
    func testListEncryptionPreservedThroughTransform() throws {
        let key = SymmetricKey(size: .bits256)
        let store = TestKeyProvidingStoreFetcher()
        store.registerKey(key)

        var dict = ScalarDict()
        dict = try dict.inserting(key: "alpha", value: ScalarHeader(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "beta", value: ScalarHeader(node: TestScalar(val: 2)))
        dict = try dict.inserting(key: "gamma", value: ScalarHeader(node: TestScalar(val: 3)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .list(key))
        let encrypted = try header.encrypt(encryption: encryption)

        for (_, child) in encrypted.node!.children {
            #expect(child.encryptionInfo != nil)
        }

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alpha"], value: .delete)
        let transformed = try encrypted.transform(transforms: transforms, keyProvider: store)!

        for (_, child) in transformed.node!.children {
            #expect(child.encryptionInfo != nil)
        }

        #expect(transformed.node!.count == 2)
        #expect(try transformed.node!.get(key: "alpha") == nil)

        let betaVal = try transformed.node!.get(key: "beta")!
        #expect(betaVal.encryptionInfo == nil)
        #expect(betaVal.node!.val == 2)
    }

    // MARK: - Content deduplication despite encryption

    @Test("Same plaintext encrypted twice produces different CIDs (no dedup)")
    func testNoDeduplicationWithEncryption() throws {
        let key = SymmetricKey(size: .bits256)

        var dict1 = ScalarDict()
        dict1 = try dict1.inserting(key: "x", value: ScalarHeader(node: TestScalar(val: 1)))
        var dict2 = ScalarDict()
        dict2 = try dict2.inserting(key: "x", value: ScalarHeader(node: TestScalar(val: 1)))

        let plain1 = HeaderImpl(node: dict1)
        let plain2 = HeaderImpl(node: dict2)
        #expect(plain1.rawCID == plain2.rawCID)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let enc1 = try plain1.encrypt(encryption: encryption)
        let enc2 = try plain2.encrypt(encryption: encryption)

        let val1 = try enc1.node!.get(key: "x")!
        let val2 = try enc2.node!.get(key: "x")!
        #expect(val1.rawCID != val2.rawCID)
        #expect(val1.encryptionInfo!.keyHash == val2.encryptionInfo!.keyHash)
    }

    // MARK: - Error handling

    @Test("Resolve encrypted data with wrong key throws")
    func testResolveWithWrongKeyThrows() async throws {
        let correctKey = SymmetricKey(size: .bits256)
        let wrongKey = SymmetricKey(size: .bits256)

        let correctStore = TestKeyProvidingStoreFetcher()
        correctStore.registerKey(correctKey)

        let scalar = TestScalar(val: 42)
        let encrypted = try ScalarHeader(node: scalar, key: correctKey)
        try encrypted.storeRecursively(storer: correctStore)

        let wrongStore = TestKeyProvidingStoreFetcher()
        wrongStore.registerKey(wrongKey)
        let encData = try await correctStore.fetch(rawCid: encrypted.rawCID)
        wrongStore.storeRaw(rawCid: encrypted.rawCID, data: encData)

        let cidOnly = ScalarHeader(
            rawCID: encrypted.rawCID,
            node: nil,
            encryptionInfo: encrypted.encryptionInfo
        )
        await #expect(throws: (any Error).self) {
            _ = try await cidOnly.resolve(fetcher: wrongStore)
        }
    }

    @Test("Store encrypted data without KeyProvider throws")
    func testStoreWithoutKeyProviderThrows() throws {
        let key = SymmetricKey(size: .bits256)
        let encrypted = try ScalarHeader(node: TestScalar(val: 42), key: key)

        let plainStore = TestStoreFetcher()
        #expect(throws: DataErrors.self) {
            try encrypted.storeRecursively(storer: plainStore)
        }
    }
}
