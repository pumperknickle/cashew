import Testing
import Foundation
import ArrayTrie
import Crypto
@preconcurrency import Multicodec
@testable import cashew

class TestKeyProvidingStoreFetcher: TestStoreFetcher, KeyProvidingFetcher {
    private let keyLock = NSLock()
    private var keys: [String: SymmetricKey] = [:]

    func registerKey(_ key: SymmetricKey) {
        let keyData = key.withUnsafeBytes { Data($0) }
        let hash = SHA256.hash(data: keyData)
        let keyHash = Data(hash).base64EncodedString()
        keyLock.withLock {
            keys[keyHash] = key
        }
    }

    func key(for keyHash: String) -> SymmetricKey? {
        keyLock.withLock {
            keys[keyHash]
        }
    }
}

struct TestScalar: Scalar {
    let val: Int
    init(val: Int) { self.val = val }
}

@Suite("Encryption Helper Tests")
struct EncryptionHelperTests {
    @Test("encrypt then decrypt round-trip")
    func testEncryptDecryptRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let original = "Hello, World!".data(using: .utf8)!
        let (encrypted, _) = try EncryptionHelper.encrypt(data: original, key: key)
        let decrypted = try EncryptionHelper.decrypt(data: encrypted, key: key)
        #expect(decrypted == original)
    }

    @Test("random IV produces different ciphertexts")
    func testRandomIV() throws {
        let key = SymmetricKey(size: .bits256)
        let data = "same data".data(using: .utf8)!
        let (enc1, iv1) = try EncryptionHelper.encrypt(data: data, key: key)
        let (enc2, iv2) = try EncryptionHelper.encrypt(data: data, key: key)
        #expect(iv1 != iv2)
        #expect(enc1 != enc2)
    }

    @Test("decrypt with wrong key throws")
    func testDecryptWrongKey() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let data = "secret".data(using: .utf8)!
        let (encrypted, _) = try EncryptionHelper.encrypt(data: data, key: key1)
        #expect(throws: (any Error).self) {
            _ = try EncryptionHelper.decrypt(data: encrypted, key: key2)
        }
    }

    @Test("empty data encrypt/decrypt")
    func testEmptyData() throws {
        let key = SymmetricKey(size: .bits256)
        let (encrypted, _) = try EncryptionHelper.encrypt(data: Data(), key: key)
        let decrypted = try EncryptionHelper.decrypt(data: encrypted, key: key)
        #expect(decrypted == Data())
    }
}

@Suite("EncryptionInfo Tests")
struct EncryptionInfoTests {
    @Test("init from SymmetricKey and Data")
    func testInitFromKeyAndIV() {
        let key = SymmetricKey(size: .bits256)
        let iv = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let info = EncryptionInfo(key: key, iv: iv)

        let keyData = key.withUnsafeBytes { Data($0) }
        let expectedHash = Data(SHA256.hash(data: keyData)).base64EncodedString()
        #expect(info.keyHash == expectedHash)
        #expect(info.iv == iv.base64EncodedString())
    }

    @Test("Codable round-trip")
    func testCodableRoundTrip() throws {
        let key = SymmetricKey(size: .bits256)
        let iv = Data([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
        let info = EncryptionInfo(key: key, iv: iv)
        let encoded = try JSONEncoder().encode(info)
        let decoded = try JSONDecoder().decode(EncryptionInfo.self, from: encoded)
        #expect(info == decoded)
    }

    @Test("Equatable")
    func testEquatable() {
        let info1 = EncryptionInfo(keyHash: "abc", iv: "def")
        let info2 = EncryptionInfo(keyHash: "abc", iv: "def")
        let info3 = EncryptionInfo(keyHash: "abc", iv: "xyz")
        #expect(info1 == info2)
        #expect(info1 != info3)
    }
}

@Suite("Header Encryption Data Model Tests")
struct HeaderEncryptionDataModelTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Encrypted HeaderImpl has different CID from plaintext")
    func testEncryptedHeaderDifferentCID() throws {
        let scalar = TestScalar(val: 42)
        let plainHeader = HeaderImpl(node: scalar)
        let key = SymmetricKey(size: .bits256)
        let encHeader = try HeaderImpl(node: scalar, key: key)
        #expect(plainHeader.rawCID != encHeader.rawCID)
    }

    @Test("encryptionInfo populated after encrypted init")
    func testEncryptionInfoPopulated() throws {
        let key = SymmetricKey(size: .bits256)
        let encHeader = try HeaderImpl(node: TestScalar(val: 1), key: key)
        #expect(encHeader.encryptionInfo != nil)
        let keyData = key.withUnsafeBytes { Data($0) }
        let expectedHash = Data(SHA256.hash(data: keyData)).base64EncodedString()
        #expect(encHeader.encryptionInfo!.keyHash == expectedHash)
    }

    @Test("Plaintext header has nil encryptionInfo")
    func testPlaintextNilEncryptionInfo() {
        let header = HeaderImpl(node: TestScalar(val: 1))
        #expect(header.encryptionInfo == nil)
    }

    @Test("removingNode preserves encryptionInfo")
    func testRemovingNodePreservesEncryption() throws {
        let key = SymmetricKey(size: .bits256)
        let encHeader = try HeaderImpl(node: TestScalar(val: 1), key: key)
        let stripped = encHeader.removingNode()
        #expect(stripped.encryptionInfo == encHeader.encryptionInfo)
        #expect(stripped.node == nil)
    }

    @Test("LosslessStringConvertible round-trip plaintext")
    func testDescriptionRoundTripPlaintext() {
        let header = HeaderImpl(node: TestScalar(val: 1))
        let desc = header.description
        let restored = HeaderImpl<TestScalar>(desc)
        #expect(restored != nil)
        #expect(restored!.rawCID == header.rawCID)
        #expect(restored!.encryptionInfo == nil)
    }

    @Test("LosslessStringConvertible round-trip encrypted")
    func testDescriptionRoundTripEncrypted() throws {
        let key = SymmetricKey(size: .bits256)
        let encHeader = try HeaderImpl(node: TestScalar(val: 1), key: key)
        let desc = encHeader.description
        #expect(desc.hasPrefix("enc:"))
        let restored = HeaderImpl<TestScalar>(desc)
        #expect(restored != nil)
        #expect(restored!.rawCID == encHeader.rawCID)
        #expect(restored!.encryptionInfo?.keyHash == encHeader.encryptionInfo?.keyHash)
        #expect(restored!.encryptionInfo?.iv == encHeader.encryptionInfo?.iv)
    }

    @Test("Codable round-trip encrypted HeaderImpl")
    func testCodableEncryptedHeaderImpl() throws {
        let key = SymmetricKey(size: .bits256)
        let encHeader = try HeaderImpl(node: TestScalar(val: 1), key: key)
        let encoded = try JSONEncoder().encode(encHeader)
        let decoded = try JSONDecoder().decode(HeaderImpl<TestScalar>.self, from: encoded)
        #expect(decoded.rawCID == encHeader.rawCID)
        #expect(decoded.encryptionInfo == encHeader.encryptionInfo)
    }
}

@Suite("Encrypted Store and Resolve Tests")
struct EncryptedStoreResolveTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Encrypted store and resolve round-trip")
    func testEncryptedStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        let scalar = TestScalar(val: 42)
        let encHeader = try HeaderImpl(node: scalar, key: key)
        try encHeader.storeRecursively(storer: fetcher)

        let cidOnly = HeaderImpl<TestScalar>(rawCID: encHeader.rawCID, node: nil, encryptionInfo: encHeader.encryptionInfo)
        let resolved = try await cidOnly.resolve(fetcher: fetcher)
        #expect(resolved.node != nil)
        #expect(resolved.node!.val == 42)
    }

    @Test("Resolve encrypted header without KeyProvidingFetcher throws")
    func testResolveWithoutKeyProviderThrows() async throws {
        let key = SymmetricKey(size: .bits256)
        let storeFetcher = TestKeyProvidingStoreFetcher()
        storeFetcher.registerKey(key)

        let encHeader = try HeaderImpl(node: TestScalar(val: 1), key: key)
        try encHeader.storeRecursively(storer: storeFetcher)

        let plainFetcher = TestStoreFetcher()
        let encryptedData = try await storeFetcher.fetch(rawCid: encHeader.rawCID)
        plainFetcher.storeRaw(rawCid: encHeader.rawCID, data: encryptedData)

        let cidOnly = HeaderImpl<TestScalar>(rawCID: encHeader.rawCID, node: nil, encryptionInfo: encHeader.encryptionInfo)
        await #expect(throws: DataErrors.self) {
            _ = try await cidOnly.resolve(fetcher: plainFetcher)
        }
    }

    @Test("Plaintext resolve works with KeyProvidingFetcher")
    func testPlaintextResolveWithKeyProvider() async throws {
        let fetcher = TestKeyProvidingStoreFetcher()
        let scalar = TestScalar(val: 99)
        let header = HeaderImpl(node: scalar)
        try header.storeRecursively(storer: fetcher)

        let cidOnly = HeaderImpl<TestScalar>(rawCID: header.rawCID)
        let resolved = try await cidOnly.resolve(fetcher: fetcher)
        #expect(resolved.node!.val == 99)
    }

    @Test("Encrypted RadixHeaderImpl store and resolve")
    func testEncryptedRadixHeaderStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        typealias RH = RadixHeaderImpl<HeaderImpl<TestScalar>>
        let valueHeader = HeaderImpl(node: TestScalar(val: 7))
        let node = RH.NodeType(prefix: "test", value: valueHeader, children: [:])
        let encHeader = try RH(node: node, key: key)
        try encHeader.storeRecursively(storer: fetcher)

        let cidOnly = RH(rawCID: encHeader.rawCID, node: nil, encryptionInfo: encHeader.encryptionInfo)
        let resolved = try await cidOnly.resolve(fetcher: fetcher)
        #expect(resolved.node != nil)
        #expect(resolved.node!.prefix == "test")
    }
}

@Suite("Targeted Encryption Strategy Tests")
struct TargetedEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Targeted encryption encrypts value at path")
    func testTargetedEncryptsValue() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        let aliceValue = try encDict.get(key: "alice")
        #expect(aliceValue != nil)
        #expect(aliceValue!.encryptionInfo != nil)

        let bobValue = try encDict.get(key: "bob")
        #expect(bobValue != nil)
        #expect(bobValue!.encryptionInfo == nil)
    }

    @Test("Targeted encryption store/resolve round-trip")
    func testTargetedStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)
        try encrypted.storeRecursively(storer: fetcher)

        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["alice"], value: .targeted)
        paths.set(["bob"], value: .targeted)
        let resolved = try await encrypted.removingNode().resolve(paths: paths, fetcher: fetcher)

        let aliceVal = try resolved.node!.get(key: "alice")
        #expect(aliceVal != nil)
        let aliceResolved = try await aliceVal!.resolve(fetcher: fetcher)
        #expect(aliceResolved.node!.val == 1)

        let bobVal = try resolved.node!.get(key: "bob")
        #expect(bobVal != nil)
        let bobResolved = try await bobVal!.resolve(fetcher: fetcher)
        #expect(bobResolved.node!.val == 2)
    }
    @Test("Root targeted encryption encrypts trie structure")
    func testRootTargetedEncryptsTrieStructure() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        for (_, child) in encDict.children {
            #expect(child.encryptionInfo != nil)
        }
    }

    @Test("Root targeted encryption does NOT encrypt values without sub-path override")
    func testRootTargetedDoesNotEncryptValues() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        let aliceVal = try encDict.get(key: "alice")
        #expect(aliceVal != nil)
        #expect(aliceVal!.encryptionInfo == nil)

        let bobVal = try encDict.get(key: "bob")
        #expect(bobVal != nil)
        #expect(bobVal!.encryptionInfo == nil)
    }

    @Test("Root targeted with sub-path override encrypts trie and targeted value")
    func testRootTargetedWithSubPathOverride() throws {
        let key = SymmetricKey(size: .bits256)
        let aliceKey = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .targeted(key))
        encryption.set(["alice"], value: .targeted(aliceKey))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        for (_, child) in encDict.children {
            #expect(child.encryptionInfo != nil)
        }

        let aliceVal = try encDict.get(key: "alice")
        #expect(aliceVal != nil)
        #expect(aliceVal!.encryptionInfo != nil)

        let bobVal = try encDict.get(key: "bob")
        #expect(bobVal != nil)
        #expect(bobVal!.encryptionInfo == nil)
    }

    @Test("Root targeted store/resolve round-trip")
    func testRootTargetedStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)
        try encrypted.storeRecursively(storer: fetcher)

        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set([""], value: .list)
        paths.set(["alice"], value: .targeted)
        paths.set(["bob"], value: .targeted)
        let resolved = try await encrypted.removingNode().resolve(paths: paths, fetcher: fetcher)

        let aliceVal = try resolved.node!.get(key: "alice")
        #expect(aliceVal != nil)
        let aliceResolved = try await aliceVal!.resolve(fetcher: fetcher)
        #expect(aliceResolved.node!.val == 1)

        let bobVal = try resolved.node!.get(key: "bob")
        #expect(bobVal != nil)
        let bobResolved = try await bobVal!.resolve(fetcher: fetcher)
        #expect(bobResolved.node!.val == 2)
    }
}

@Suite("List Encryption Strategy Tests")
struct ListEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("List encryption encrypts RadixHeaders but not values")
    func testListEncryptsStructureNotValues() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .list(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        for (_, child) in encDict.children {
            #expect(child.encryptionInfo != nil)
        }

        let aliceValue = try encDict.get(key: "alice")
        #expect(aliceValue != nil)
        #expect(aliceValue!.encryptionInfo == nil)
    }

    @Test("List encryption store/resolve round-trip")
    func testListStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .list(key))
        let encrypted = try header.encrypt(encryption: encryption)
        try encrypted.storeRecursively(storer: fetcher)

        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set([""], value: .list)
        paths.set(["alice"], value: .targeted)
        paths.set(["bob"], value: .targeted)
        let cidOnly = encrypted.removingNode()
        let resolved = try await cidOnly.resolve(paths: paths, fetcher: fetcher)

        let aliceVal = try resolved.node!.get(key: "alice")
        #expect(aliceVal != nil)
        let aliceResolved = try await aliceVal!.resolve(fetcher: fetcher)
        #expect(aliceResolved.node!.val == 1)
    }
}

@Suite("Recursive Encryption Strategy Tests")
struct RecursiveEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Recursive encryption encrypts entire subtree")
    func testRecursiveEncryptsAll() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        for (_, child) in encDict.children {
            #expect(child.encryptionInfo != nil)
        }
        let aliceVal = try encDict.get(key: "alice")
        #expect(aliceVal!.encryptionInfo != nil)
        let bobVal = try encDict.get(key: "bob")
        #expect(bobVal!.encryptionInfo != nil)
    }

    @Test("Recursive encryption store/resolve round-trip")
    func testRecursiveStoreResolve() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)
        try encrypted.storeRecursively(storer: fetcher)

        let resolved = try await encrypted.removingNode().resolveRecursive(fetcher: fetcher)
        let aliceVal = try resolved.node!.get(key: "alice")
        #expect(aliceVal != nil)
        let aliceResolved = try await aliceVal!.resolve(fetcher: fetcher)
        #expect(aliceResolved.node!.val == 1)
    }

    @Test("Recursive with longer-path override")
    func testRecursiveWithOverride() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key1))
        encryption.set(["bob"], value: .recursive(key2))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        let aliceVal = try encDict.get(key: "alice")
        #expect(aliceVal!.encryptionInfo != nil)

        let key1Data = key1.withUnsafeBytes { Data($0) }
        let key1Hash = Data(SHA256.hash(data: key1Data)).base64EncodedString()
        #expect(aliceVal!.encryptionInfo!.keyHash == key1Hash)

        let bobVal = try encDict.get(key: "bob")
        #expect(bobVal!.encryptionInfo != nil)

        let key2Data = key2.withUnsafeBytes { Data($0) }
        let key2Hash = Data(SHA256.hash(data: key2Data)).base64EncodedString()
        #expect(bobVal!.encryptionInfo!.keyHash == key2Hash)
    }
}

@Suite("Mixed Encryption Tests")
struct MixedEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Sibling paths with different keys")
    func testSiblingDifferentKeys() throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key1))
        encryption.set(["bob"], value: .targeted(key2))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        let aliceVal = try encDict.get(key: "alice")
        let bobVal = try encDict.get(key: "bob")

        let key1Data = key1.withUnsafeBytes { Data($0) }
        let key1Hash = Data(SHA256.hash(data: key1Data)).base64EncodedString()
        let key2Data = key2.withUnsafeBytes { Data($0) }
        let key2Hash = Data(SHA256.hash(data: key2Data)).base64EncodedString()

        #expect(aliceVal!.encryptionInfo!.keyHash == key1Hash)
        #expect(bobVal!.encryptionInfo!.keyHash == key2Hash)
    }

    @Test("Sibling paths with different keys store/resolve")
    func testSiblingDifferentKeysStoreResolve() async throws {
        let key1 = SymmetricKey(size: .bits256)
        let key2 = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key1)
        fetcher.registerKey(key2)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key1))
        encryption.set(["bob"], value: .targeted(key2))
        let encrypted = try header.encrypt(encryption: encryption)
        try encrypted.storeRecursively(storer: fetcher)

        var paths = ArrayTrie<ResolutionStrategy>()
        paths.set(["alice"], value: .targeted)
        paths.set(["bob"], value: .targeted)
        let resolved = try await encrypted.removingNode().resolve(paths: paths, fetcher: fetcher)

        let aliceVal = try resolved.node!.get(key: "alice")!
        let aliceResolved = try await aliceVal.resolve(fetcher: fetcher)
        #expect(aliceResolved.node!.val == 1)

        let bobVal = try resolved.node!.get(key: "bob")!
        let bobResolved = try await bobVal.resolve(fetcher: fetcher)
        #expect(bobResolved.node!.val == 2)
    }

    @Test("Mixed encrypted and plaintext tree")
    func testMixedEncryptedPlaintext() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "secret", value: HeaderImpl(node: TestScalar(val: 42)))
        dict = try dict.inserting(key: "public", value: HeaderImpl(node: TestScalar(val: 99)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["secret"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let encDict = encrypted.node!
        let secretVal = try encDict.get(key: "secret")
        #expect(secretVal!.encryptionInfo != nil)
        let publicVal = try encDict.get(key: "public")
        #expect(publicVal!.encryptionInfo == nil)
    }
}

@Suite("Transform With Encryption Tests")
struct TransformWithEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Transform then encrypt")
    func testTransformThenEncrypt() throws {
        let key = SymmetricKey(size: .bits256)
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        dict = try dict.inserting(key: "charlie", value: HeaderImpl(node: TestScalar(val: 3)))
        let header = HeaderImpl(node: dict)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["charlie"], value: .delete)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["bob"], value: .targeted(key))

        let result = try header.transform(transforms: transforms, encryption: encryption)
        #expect(result != nil)

        let bobVal = try result!.node!.get(key: "bob")
        #expect(bobVal != nil)
        #expect(bobVal!.encryptionInfo != nil)

        let aliceVal = try result!.node!.get(key: "alice")
        #expect(aliceVal != nil)
        #expect(aliceVal!.encryptionInfo == nil)

        let charlieVal = try result!.node!.get(key: "charlie")
        #expect(charlieVal == nil)
    }

    @Test("Transform without encryption is unchanged")
    func testTransformWithoutEncryption() throws {
        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        let header = HeaderImpl(node: dict)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["bob"], value: .insert("HeaderImpl<TestScalar>(val: 2)"))

        let encryption = ArrayTrie<EncryptionStrategy>()
        let result = try header.transform(transforms: transforms, encryption: encryption)
        #expect(result != nil)
        let bobVal = try result!.node!.get(key: "bob")
        #expect(bobVal != nil)
        #expect(bobVal!.encryptionInfo == nil)
    }
}

@Suite("Transform Preserves Encryption Tests")
struct TransformPreservesEncryptionTests {
    typealias DictType = MerkleDictionaryImpl<HeaderImpl<TestScalar>>

    @Test("Top-level header re-encrypted after transform")
    func testTopLevelHeaderReEncrypted() throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))

        let plainHeader = HeaderImpl(node: dict)
        let encHeader = try HeaderImpl(node: dict, key: key)
        #expect(encHeader.encryptionInfo != nil)

        let originalKeyHash = encHeader.encryptionInfo!.keyHash
        let originalCID = encHeader.rawCID

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alice"], value: .delete)
        let result = try encHeader.transform(transforms: transforms, keyProvider: fetcher)
        #expect(result != nil)
        #expect(result!.encryptionInfo != nil)
        #expect(result!.encryptionInfo!.keyHash == originalKeyHash)
        #expect(result!.rawCID != originalCID)
        #expect(result!.rawCID != plainHeader.rawCID)
    }

    @Test("Delete value in encrypted dict")
    func testDeleteInEncryptedDict() throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alice"], value: .delete)
        let result = try encrypted.transform(transforms: transforms, keyProvider: fetcher)
        #expect(result != nil)

        let aliceVal = try result!.node!.get(key: "alice")
        #expect(aliceVal == nil)

        let bobVal = try result!.node!.get(key: "bob")
        #expect(bobVal != nil)
        #expect(bobVal!.encryptionInfo != nil)
    }

    @Test("Insert into encrypted dict does NOT auto-encrypt")
    func testInsertNotAutoEncrypted() throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["charlie"], value: .insert(HeaderImpl<TestScalar>(node: TestScalar(val: 3)).description))
        let result = try encrypted.transform(transforms: transforms, keyProvider: fetcher)
        #expect(result != nil)

        let charlieVal = try result!.node!.get(key: "charlie")
        #expect(charlieVal != nil)
        #expect(charlieVal!.encryptionInfo == nil)

        let aliceVal = try result!.node!.get(key: "alice")
        #expect(aliceVal != nil)
        #expect(aliceVal!.encryptionInfo != nil)
    }

    @Test("Encrypted RadixHeader preserved through child mutation")
    func testRadixHeaderEncryptionPreserved() throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .list(key))
        let encrypted = try header.encrypt(encryption: encryption)

        for (_, child) in encrypted.node!.children {
            #expect(child.encryptionInfo != nil)
        }

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alice"], value: .delete)
        let result = try encrypted.transform(transforms: transforms, keyProvider: fetcher)
        #expect(result != nil)

        for (_, child) in result!.node!.children {
            #expect(child.encryptionInfo != nil)
        }
    }

    @Test("Transform + store + resolve round-trip on encrypted data")
    func testTransformStoreResolveRoundTrip() async throws {
        let key = SymmetricKey(size: .bits256)
        let fetcher = TestKeyProvidingStoreFetcher()
        fetcher.registerKey(key)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        dict = try dict.inserting(key: "bob", value: HeaderImpl(node: TestScalar(val: 2)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set([""], value: .recursive(key))
        let encrypted = try header.encrypt(encryption: encryption)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["alice"], value: .delete)
        let transformed = try encrypted.transform(transforms: transforms, keyProvider: fetcher)!

        try transformed.storeRecursively(storer: fetcher)

        let resolved = try await transformed.removingNode().resolveRecursive(fetcher: fetcher)
        let bobVal = try resolved.node!.get(key: "bob")
        #expect(bobVal != nil)
        let bobResolved = try await bobVal!.resolve(fetcher: fetcher)
        #expect(bobResolved.node!.val == 2)
    }

    @Test("Transform without keyProvider strips encryption (backward compat)")
    func testTransformWithoutKeyProviderStripsEncryption() throws {
        let key = SymmetricKey(size: .bits256)

        var dict = DictType()
        dict = try dict.inserting(key: "alice", value: HeaderImpl(node: TestScalar(val: 1)))
        let header = HeaderImpl(node: dict)

        var encryption = ArrayTrie<EncryptionStrategy>()
        encryption.set(["alice"], value: .targeted(key))
        let encrypted = try header.encrypt(encryption: encryption)

        let aliceBefore = try encrypted.node!.get(key: "alice")!
        #expect(aliceBefore.encryptionInfo != nil)

        var transforms = ArrayTrie<Transform>()
        transforms.set(["bob"], value: .insert(HeaderImpl<TestScalar>(node: TestScalar(val: 2)).description))
        let result = try encrypted.transform(transforms: transforms)

        #expect(result != nil)
        #expect(result!.encryptionInfo == nil)
    }
}
