# Cashew

A Swift library for content-addressable storage and Merkle data structures with cryptographic proofs and resolution capabilities.

## Overview

Cashew provides a comprehensive toolkit for building decentralized applications with content-addressable storage. It implements Merkle trees, radix tries, and sparse Merkle proofs with support for:

- **Content-addressable storage** using CIDs (Content Identifiers)
- **Merkle data structures** including dictionaries and radix nodes
- **Cryptographic proofs** for data integrity verification
- **Asynchronous resolution** of remote data references
- **Transformations** for efficient data mutations
- **Thread-safe operations** using Swift's actor model

## Key Features

### Core Data Structures

- **Node Protocol**: Base protocol for all Merkle data structures
- **MerkleDictionary**: Key-value storage with Merkle tree properties
- **RadixNode**: Compressed trie implementation for efficient prefix matching
- **Address**: Content-addressable references with CID support

### Proof System

- **SparseMerkleProof**: Cryptographic proofs for data existence, insertion, mutation, and deletion
- **Proof validation**: Verify data integrity without storing complete datasets
- **Multi-proof support**: Validate multiple operations in a single proof

### Resolution & Fetching

- **Async resolution**: Resolve references to remote data using pluggable fetchers
- **Resolution strategies**: Flexible strategies for handling different data access patterns
- **Thread-safe caching**: Built-in support for concurrent operations

### Transformations

- **Efficient mutations**: Apply changes without rebuilding entire data structures
- **Batch operations**: Transform multiple properties in a single operation
- **Content preservation**: Maintain cryptographic integrity through transformations

## Requirements

- iOS 12.0+ / macOS 12.0+
- Swift 6.0+
- Xcode 14.0+

## Installation

### Swift Package Manager

Add Cashew to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/cashew.git", from: "1.0.0")
]
```

Or add it through Xcode:
1. File → Add Package Dependencies
2. Enter the repository URL
3. Select the version range

## Usage

### Creating Data Structures

```swift
import cashew

// Create a Merkle dictionary for storing key-value pairs
let dictionary = MerkleDictionaryImpl<String>(children: [:], count: 0)

// Create a radix node for prefix-based storage
let radixNode = RadixNodeImpl<String>(
    prefix: "user",
    value: "john_doe", 
    children: [:]
)
```

### Working with Addresses

```swift
// Create addresses for content-addressable storage
let header = try HeaderImpl(
    rawCid: "baguqeeraygnllsf724bh4ntqonh2shkgfwkxizcdjucbadjkoyj4byvgh7ya",
    node: someNode
)

// Access the CID
let cid = header.rawCid

// Store node data
let data = header.toData()
```

### Adding and Updating Data

```swift
// Add properties to a dictionary
let updatedDict = dictionary.set(properties: [
    "name": nameAddress,
    "email": emailAddress,
    "profile": profileAddress
])

// Update a radix node
let updatedNode = radixNode.set(properties: [
    "a": childAddress
])
```

### Proofs and Verification

```swift
// Create proof paths using ArrayTrie
var proofPaths = ArrayTrie<SparseMerkleProof>()
proofPaths.insert(["user", "profile"], value: .existence)
proofPaths.insert(["user", "email"], value: .mutation("new_email@example.com"))

// Generate proofs
let proovedDict = try await dictionary.proof(paths: proofPaths, fetcher: myFetcher)

// Validate different proof types
proofPaths.insert(["new_user"], value: .insertion("alice"))
proofPaths.insert(["old_user"], value: .deletion)
```

### Resolution and Fetching

```swift
// Implement a custom fetcher
struct MyFetcher: Fetcher {
    func fetch(rawCid: String) async throws -> Data {
        // Fetch data from IPFS, database, network, etc.
        return try await networkClient.fetchData(for: rawCid)
    }
}

// Create resolution strategies
var resolutionPaths = ArrayTrie<ResolutionStrategy>()
resolutionPaths.insert(["users"], value: .list)
resolutionPaths.insert(["user", "profile"], value: .recursive)
resolutionPaths.insert(["config", "theme"], value: .scalar)

// Resolve references
let fetcher = MyFetcher()
let resolved = try await dictionary.resolve(paths: resolutionPaths, fetcher: fetcher)
```

### Transformations

```swift
// Create transformation paths
var transforms = ArrayTrie<Transform>()
transforms.insert(["user", "name"], value: .update("Alice Johnson"))
transforms.insert(["user", "settings", "theme"], value: .insert("dark"))
transforms.insert(["temp_data"], value: .delete)

// Apply transformations
let transformed = try dictionary.transform(transforms: transforms)
```

### Content Addressability

```swift
// All data structures maintain content addressability
let node1 = RadixNodeImpl<String>(prefix: "test", value: "data", children: [:])
let node2 = RadixNodeImpl<String>(prefix: "test", value: "data", children: [:])

// Same content produces same hash
assert(node1.description == node2.description)

// Different content produces different hash
let node3 = RadixNodeImpl<String>(prefix: "test", value: "different", children: [:])
assert(node1.description != node3.description)
```


## API Reference

### Core Protocols

- **Node**: Base protocol for all Merkle data structures
  - `get(property:)` - Retrieve address for a property
  - `set(properties:)` - Update multiple properties
  - `resolve(paths:fetcher:)` - Resolve remote references
  - `transform(transforms:)` - Apply mutations
  - `proof(paths:fetcher:)` - Generate cryptographic proofs

- **Address**: Content-addressable references
  - `rawCid` - Content identifier string
  - `toData()` - Serialize to bytes
  - `storeRecursively(storer:)` - Persist data

- **Fetcher**: Data retrieval interface
  - `fetch(rawCid:)` - Fetch data by content ID

### Data Types

- **SparseMerkleProof**: Proof operations
  - `.existence` - Verify data exists
  - `.insertion(value)` - Prove data can be added
  - `.mutation(value)` - Prove data can be changed
  - `.deletion` - Prove data can be removed

- **ResolutionStrategy**: Resolution modes
  - `.scalar` - Resolve single values
  - `.list` - Resolve collections
  - `.recursive` - Deep resolution
  - `.targeted` - Specific node resolution

- **Transform**: Mutation operations
  - `.insert(value)` - Add new data
  - `.update(value)` - Change existing data
  - `.delete` - Remove data

## Architecture

Cashew is built around several key protocols:

- **Node**: Base protocol for all data structures
- **Address**: Content-addressable references  
- **Fetcher**: Pluggable data retrieval interface
- **Storer**: Pluggable data persistence interface

The library uses Swift's modern concurrency features including async/await and actors for thread-safe operations.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass: `swift test`
5. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Related Projects

- [swift-cid](https://github.com/swift-libp2p/swift-cid) - Content Identifier implementation
- [swift-multicodec](https://github.com/swift-libp2p/swift-multicodec) - Multicodec support
- [swift-multihash](https://github.com/swift-libp2p/swift-multihash) - Cryptographic hash functions
