import ArrayTrie

extension RadixHeader where NodeType.ValueType: Address {
    func resolve(fetcher: Fetcher) async throws -> Self {
        if let node = node {
            return self
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let newNode = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            guard let nodeAddress = newNode.value else { return Self(rawCID: rawCID, node: newNode) }
            let resolvedAddress = try await nodeAddress.resolve(fetcher: fetcher)
            return Self(rawCID: rawCID, node: NodeType(prefix: newNode.prefix, value: resolvedAddress, children: newNode.children))
        }
    }
}
