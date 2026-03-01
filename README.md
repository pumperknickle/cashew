# Cashew

A Swift library for content-addressable Merkle data structures with lazy resolution, sparse proofs, and structural transformations.

## Overview

Cashew solves a specific problem: how do you build a key-value store where every version of the data has a unique cryptographic fingerprint, parts of the data can live on remote storage and be loaded on-demand, and you can efficiently prove things about what's in (or not in) the store without materializing all of it?

The answer is a **Merkle radix trie** -- a compressed trie where every node is identified by a CID (Content Identifier), which is the SHA2-256 hash of the node's deterministic JSON serialization. This is the same content-addressing scheme used by IPFS/IPLD, meaning Cashew data structures are natively interoperable with the IPFS ecosystem.

### The Core Idea

Every data structure in Cashew is **immutable** and **content-addressed**. When you "modify" a dictionary, you get back a new dictionary with a new root CID. Unchanged subtrees share the same CIDs as before -- this is structural sharing through content addressing.

The key abstraction is the **Header** -- a smart pointer that holds a CID and optionally the data that CID refers to:

```
Header
  rawCID: "baguqeera..."   <- always present (the hash)
  node: RadixNode?          <- sometimes present (the actual data)
```

A Header with `node == nil` is an **unresolved reference** -- you know *what* data exists (by its hash) but haven't loaded it yet. Call `resolve(fetcher:)` to fetch the data from any content-addressable store (IPFS, a database, the filesystem) and populate the `node`. This is how Cashew enables lazy loading of arbitrarily large data structures.

### How the Trie Works

A `MerkleDictionary` maps string keys to values. Internally, it dispatches by the first character of each key to a radix trie branch:

```
MerkleDictionary { count: 4 }
  'a' -> RadixHeader -> RadixNode(prefix: "alice", value: "engineer", children: {})
  'b' -> RadixHeader -> RadixNode(prefix: "b", value: nil, children: {
           'o' -> RadixHeader -> RadixNode(prefix: "ob", value: "designer", children: {})
           'a' -> RadixHeader -> RadixNode(prefix: "az", value: "manager", children: {})
         })
```

Each `RadixNode` stores a compressed `prefix` (the shared path segment), an optional `value` (present if this node terminates a complete key), and `children` keyed by the next character. Path compression means "alice" is stored as a single node rather than 5 chained nodes -- giving O(k) lookup where k is key length, with much lower constant factors than an uncompressed trie.

Every `RadixNode` is wrapped in a `RadixHeader` that computes its CID. When the dictionary is serialized (for storage or transmission), only the CIDs are written -- the actual node data is stripped. To reconstruct the data, you resolve headers by fetching node data from a content-addressable store using the CIDs.

### What You Can Do

Cashew provides four operations on these structures, each specified as a trie of paths:

**1. Resolution** -- Load data from storage. Three strategies control how deep to go:
- `.targeted`: fetch one node (e.g., load just the user's profile header)
- `.recursive`: fetch everything beneath a path (e.g., load an entire subtree)
- `.list`: fetch the trie structure for navigation but leave value-level addresses unresolved (e.g., list all user IDs without loading their profile data)

**2. Transform** -- Mutate the structure (insert, update, delete). Returns a new tree with new CIDs for affected nodes. Handles radix trie maintenance: splitting prefixes when keys diverge, merging nodes when deletions make branches unnecessary.

**3. Proof** -- Generate a minimal subtree proving specific properties:
- `.existence`: this key exists with this value
- `.insertion`: this key does not exist (proving it's safe to insert)
- `.mutation`: this key exists (proving it can be updated)
- `.deletion`: this key exists and here are its neighbors (proving deletion is structurally valid)

**4. Storage** -- Persist resolved nodes to a content-addressable store via `storeRecursively`.

### Nested Dictionaries (Two-Level Addressing)

When `ValueType` is itself a `Header<MerkleDictionary>`, Cashew supports hierarchical structures -- a dictionary whose values are other dictionaries, each with their own CID. This is the power case: you can have a users dictionary where each user value is a CID pointing to that user's own key-value store.

Transforms propagate through both levels: `transforms.set(["user1", "name"], value: .update("Alice"))` reaches into the nested dictionary at key "user1" and updates the "name" key inside it. The nested dictionary gets a new CID, which changes the parent's value, which gives the parent a new CID -- the Merkle property propagates up to the root.

A specialized `RadixNode` extension (`where ValueType: Header, ValueType.NodeType: MerkleDictionary`) handles these two-level transforms, including creating new empty nested dictionaries on-the-fly when inserting into a path that doesn't exist yet.

### Data Flow

```
                        ┌─────────────┐
                        │   Fetcher   │  (pluggable: IPFS, DB, filesystem)
                        │ fetch(cid)  │
                        └──────┬──────┘
                               │ Data
                               ▼
  ┌──────────┐  resolve   ┌─────────┐  transform   ┌──────────┐
  │Unresolved├───────────>│Resolved ├──────────────>│  New     │
  │  Header  │            │ Header  │               │ Header   │
  │(CID only)│            │(CID+Node)              │(new CID) │
  └──────────┘            └────┬────┘               └────┬─────┘
                               │                         │
                               │ proof                   │ storeRecursively
                               ▼                         ▼
                        ┌──────────┐             ┌─────────────┐
                        │  Proof   │             │   Storer    │
                        │(minimal  │             │ store(cid,  │
                        │ subtree) │             │       data) │
                        └──────────┘             └─────────────┘
```

### Architecture

Protocol hierarchy:

```
Node (base: Codable + LosslessStringConvertible + Sendable)
  |-- Scalar (leaf node, no children)
  |-- RadixNode (compressed trie node)
  |-- MerkleDictionary (top-level key-value map)

Address (Sendable, supports resolve/proof/transform/store)
  |-- Header (Codable, wraps a Node with its CID)
      |-- RadixHeader (Header constrained to RadixNode)
```

Concrete implementations: `MerkleDictionaryImpl<V>`, `RadixNodeImpl<V>`, `HeaderImpl<N>`, `RadixHeaderImpl<V>`.

Each operation (resolve, transform, proof) is implemented via protocol extensions organized by type: `Node+resolve.swift`, `RadixNode+resolve.swift`, `MerkleDictionary+resolve.swift`, etc. The `RadixNode+transform.swift` file is the most complex (~500 lines) because it handles all the radix trie maintenance (prefix splitting, node merging) plus the nested-dictionary specialization.

Concurrency is handled via Swift actors (`ThreadSafeDictionary`) and `CollectionConcurrencyKit`'s `concurrentForEach` for parallel resolution of sibling branches.

## Requirements

- macOS 12.0+
- Swift 6.0+

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pumperknickle/cashew.git", from: "1.0.0")
]
```

## Dependencies

| Package | Purpose |
|---------|---------|
| [ArrayTrie](https://github.com/pumperknickle/ArrayTrie) | Trie data structure for path-based traversal of resolution/transform/proof specs |
| [swift-crypto](https://github.com/apple/swift-crypto) | SHA2-256 hashing for CID generation |
| [swift-cid](https://github.com/swift-libp2p/swift-cid) | IPFS CIDv1 content identifiers |
| [swift-multicodec](https://github.com/swift-libp2p/swift-multicodec) | Codec identifiers (dag-json, dag-cbor, etc.) |
| [swift-multihash](https://github.com/swift-libp2p/swift-multihash) | Self-describing hash format |
| [swift-collections](https://github.com/apple/swift-collections) | Swift standard collections |
| [CollectionConcurrencyKit](https://github.com/JohnSundell/CollectionConcurrencyKit) | `concurrentForEach` for parallel async operations |

## Usage

### Creating and Mutating a Dictionary

```swift
import cashew

// Create an empty dictionary with String values
var dict = MerkleDictionaryImpl<String>()

// Insert keys
dict = try dict.inserting(key: "alice", value: "engineer")
dict = try dict.inserting(key: "bob", value: "designer")
dict = try dict.inserting(key: "alicia", value: "manager")

// Lookup
let value = try dict.get(key: "alice") // Optional("engineer")

// Update
dict = try dict.mutating(key: "bob", value: "lead designer")

// Delete
dict = try dict.deleting(key: "alicia")

// Enumerate all keys
let keys: Set<String> = try dict.allKeys()

// Enumerate all key-value pairs
let pairs: [String: String] = try dict.allKeysAndValues()
```

### Content Addressability

Every structure has a deterministic CID derived from its content:

```swift
let node = RadixNodeImpl<String>(prefix: "hello", value: "world", children: [:])
let header = RadixHeaderImpl(node: node)
print(header.rawCID) // CIDv1 string, e.g. "baguqeera..."

// Same content always produces the same CID
let header2 = RadixHeaderImpl(node: node)
assert(header.rawCID == header2.rawCID)
```

### Resolution (Lazy Loading)

Headers can be created with only a CID. Resolution fetches the actual data using a pluggable `Fetcher`:

```swift
struct IPFSFetcher: Fetcher {
    func fetch(rawCid: String) async throws -> Data {
        // fetch from IPFS, a database, or any content-addressable store
    }
}

let fetcher = IPFSFetcher()

// Three resolution strategies, specified via ArrayTrie<ResolutionStrategy>:
var paths = ArrayTrie<ResolutionStrategy>()

// .targeted - fetch just this node (one level)
paths.set(["users", "a"], value: .targeted)

// .recursive - fetch this node and everything beneath it
paths.set(["config"], value: .recursive)

// .list - fetch the trie structure for traversal but leave nested
//         address values unresolved (lazy loading)
paths.set(["posts"], value: .list)

let resolved = try await dictionary.resolve(paths: paths, fetcher: fetcher)
```

### Storage

Persist resolved data using a pluggable `Storer`:

```swift
struct MyStore: Storer {
    func store(rawCid: String, data: Data) throws {
        // write to disk, database, IPFS, etc.
    }
}

// Recursively stores this header and all resolved children
try header.storeRecursively(storer: MyStore())
```

### Transforms (Batch Mutations)

Apply multiple insert/update/delete operations in one pass using `ArrayTrie<Transform>`:

```swift
var transforms = ArrayTrie<Transform>()
transforms.set(["alice"], value: .update("senior engineer"))
transforms.set(["charlie"], value: .insert("intern"))
transforms.set(["bob"], value: .delete)

let newDict = try dict.transform(transforms: transforms)
// newDict has the mutations applied; CIDs are recomputed
```

### Sparse Merkle Proofs

Generate minimal subtrees that prove specific properties about keys:

```swift
var proofPaths = ArrayTrie<SparseMerkleProof>()

// Prove a key exists with its current value
proofPaths.set(["alice"], value: .existence)

// Prove a key can be inserted (doesn't exist yet)
proofPaths.set(["dave"], value: .insertion)

// Prove a key exists and can be mutated
proofPaths.set(["bob"], value: .mutation)

// Prove a key exists and can be deleted
proofPaths.set(["charlie"], value: .deletion)

let proof = try await dictionary.proof(paths: proofPaths, fetcher: fetcher)
// proof contains only the nodes needed to verify these properties
```

### Nested Dictionaries

Values can themselves be `Header` types wrapping `MerkleDictionary`, enabling nested/hierarchical structures:

```swift
typealias InnerDict = MerkleDictionaryImpl<String>
typealias OuterDict = MerkleDictionaryImpl<HeaderImpl<InnerDict>>

var outer = OuterDict()
let inner = try InnerDict()
    .inserting(key: "name", value: "Alice")
    .inserting(key: "role", value: "Engineer")
let innerHeader = HeaderImpl(node: inner)

outer = try outer.inserting(key: "user1", value: innerHeader)
```

Transforms on nested dictionaries propagate through the tree:

```swift
var transforms = ArrayTrie<Transform>()
// This updates "name" inside the nested dict at key "user1"
transforms.set(["user1", "name"], value: .update("Alicia"))

let updated = try outer.transform(transforms: transforms)
```

## API Reference

### Protocols

| Protocol | Conforms To | Purpose |
|----------|-------------|---------|
| `Node` | `Codable`, `LosslessStringConvertible`, `Sendable` | Base for all Merkle structures. Defines `get`, `set`, `resolve`, `transform`, `proof`, `storeRecursively`. |
| `Address` | `Sendable` | Reference to content. Supports `resolve`, `proof`, `transform`, `storeRecursively`, `removingNode`. |
| `Header` | `Codable`, `Address`, `LosslessStringConvertible` | Wraps a `Node` with its CID. Can be resolved or unresolved. |
| `RadixNode` | `Node` | Compressed trie node with `prefix`, optional `value`, and `children`. |
| `RadixHeader` | `Header` | Header constrained to `RadixNode`. |
| `MerkleDictionary` | `Node` | Top-level key-value map. Dispatches by first character to `RadixHeader` children. |
| `Scalar` | `Node` | Leaf node with no children. Returns empty for `properties()`. |
| `Fetcher` | `Sendable` | Async data retrieval by CID. One method: `fetch(rawCid:) async throws -> Data`. |
| `Storer` | -- | Data persistence by CID. One method: `store(rawCid:data:) throws`. |

### Enums

| Enum | Cases | Purpose |
|------|-------|---------|
| `ResolutionStrategy` | `.targeted`, `.recursive`, `.list` | Controls how deep resolution goes |
| `Transform` | `.insert(String)`, `.update(String)`, `.delete` | Mutation operations for transforms |
| `SparseMerkleProof` | `.insertion`, `.mutation`, `.deletion`, `.existence` | Proof types for sparse Merkle proofs |

### Error Types

| Error | Cases |
|-------|-------|
| `DataErrors` | `.nodeNotAvailable`, `.serializationFailed`, `.cidCreationFailed` |
| `TransformErrors` | `.transformFailed`, `.invalidKey`, `.missingData` |
| `ProofErrors` | `.invalidProofType`, `.proofFailed` |
| `ResolutionErrors` | `.TypeError` |
| `DecodingError` (internal) | `.decodeFromDataError` |

### Concrete Types

| Type | Purpose |
|------|---------|
| `MerkleDictionaryImpl<V>` | Concrete `MerkleDictionary`. `V` must be `Codable + Sendable + LosslessStringConvertible`. |
| `RadixNodeImpl<V>` | Concrete `RadixNode` with JSON coding for `Character`-keyed children. |
| `HeaderImpl<N>` | Generic `Header` wrapping any `Node` type. |
| `RadixHeaderImpl<V>` | `RadixHeader` for `RadixNodeImpl<V>`. |
| `Box<T>` | Wrapper making `Sendable` types storable in a reference type (used by `HeaderImpl`). |
| `ThreadSafeDictionary<K,V>` | Actor-based thread-safe dictionary for concurrent resolution. |

## Project Structure

```
Sources/cashew/
  Core/
    Node.swift              -- Node protocol + JSON serialization + compareSlices/commonPrefix helpers
    Address.swift           -- Address protocol
    Header.swift            -- Header protocol + CID creation (sync and async)
    HeaderImpl.swift        -- Concrete Header + Box<T> wrapper
    Scalar.swift            -- Leaf node protocol (no children)
    MulticodecExtensions.swift -- Codec lookup utilities
  MerkleDataStructures/
    MerkleDictionary.swift  -- MerkleDictionary protocol + allKeys/allKeysAndValues
    MerkleDictionaryImpl.swift -- Concrete implementation with JSON coding
    RadixNode.swift         -- RadixNode protocol + property accessors
    RadixNodeImpl.swift     -- Concrete implementation with JSON coding
    RadixHeader.swift       -- RadixHeader protocol (one line)
    RadixHeaderImpl.swift   -- Concrete RadixHeader with JSON coding
  Fetcher/
    Fetcher.swift           -- Fetcher protocol
    Storer.swift            -- Storer protocol
    Node+store.swift        -- Node.storeRecursively extension
    Header+store.swift      -- Header.storeRecursively extension
  Resolver/
    ResolutionStrategy.swift -- .targeted/.recursive/.list enum
    ResolutionErrors.swift  -- ResolutionErrors.TypeError
    Node+resolve.swift      -- Node.resolve and Node.resolveRecursive
    Header+resolve.swift    -- Header.resolve (fetches if node is nil)
    RadixNode+resolve.swift -- RadixNode.resolve with prefix traversal + list resolution
    RadixHeader+resolve.swift -- RadixHeader resolution (delegates to node)
    MerkleDictionary+resolve.swift -- MerkleDictionary resolution strategies
    Scalar+resolve.swift    -- No-op resolution for scalars
  Transform/
    Transform.swift         -- .insert/.update/.delete enum
    TransformErrors.swift   -- TransformErrors enum
    Node+transform.swift    -- Generic Node.transform
    Header+transform.swift  -- Header.transform (requires resolved node)
    RadixNode+transform.swift -- RadixNode transform + insert/delete/mutate/get + nested dict specialization
    RadixHeader+transform.swift -- RadixHeader delegates to node
    MerkleDictionary+transform.swift -- MerkleDictionary transform + get/insert/delete/mutate
  Proofs/
    SparseMerkleProof.swift -- .insertion/.mutation/.deletion/.existence enum
    ProofErrors.swift       -- ProofErrors enum
    Node+proofs.swift       -- Generic Node.proof
    Header+proofs.swift     -- Header.proof (fetches if needed)
    RadixNode+proofs.swift  -- RadixNode proof with prefix traversal + grandchild resolution
    RadixHeader+proofs.swift -- RadixHeader proof delegation
    MerkleDictionary+proofs.swift -- MerkleDictionary proof delegation
  ThreadSafeDictionary.swift -- Actor-based thread-safe dictionary
  DataErrors.swift          -- DataErrors enum
  DecodingErrors.swift      -- Internal DecodingError enum
  LosslessStringConvertible+data.swift -- Data/String conversion extensions
```

## Running Tests

```bash
swift test
```

175 tests across 14 test files covering resolution, transforms, proofs, headers, and key enumeration.

## License

MIT
