public extension RadixHeader {
    func resolveChildren(fetcher: Fetcher) async throws -> Self {
        if let node = node {
            let newNode = try await node.resolveChildren(fetcher: fetcher)
            return Self(rawCID: rawCID, node: newNode)
        }
        else {
            let fetchedData = try await fetcher.fetch(rawCid: rawCID)
            guard let node = NodeType(data: fetchedData) else { throw DecodingError.decodeFromDataError }
            let newNode = try await node.resolveChildren(fetcher: fetcher)
            return Self(rawCID: rawCID, node: newNode)
        }
    }
}
