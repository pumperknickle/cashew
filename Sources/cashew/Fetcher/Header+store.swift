public extension Header {
    func storeRecursively(storer: Storer) throws {
        guard let node = node else {
            return
        }
        guard let nodeData = node.toData() else { throw DataErrors.serializationFailed }
        try storer.store(rawCid: rawCID, data: nodeData)
        try node.storeRecursively(storer: storer)
    }
}
