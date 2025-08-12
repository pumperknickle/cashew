import Foundation

public protocol Scalar: Node { }

extension Scalar {
    public func get(property: String) -> (any Address)? {
        return nil
    }
    
    func properties() -> Set<PathSegment> {
        return Set()
    }
    
    // update
    func set(property: PathSegment, to child: Address) -> Self {
        return self
    }
    
    func set(properties: [PathSegment: Address]) -> Self {
        return self
    }
}

