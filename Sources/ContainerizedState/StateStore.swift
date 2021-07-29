import Foundation
import Debug

open class StateStore<State: StoreState> {
    private var subscriptions = NSHashTable<StateSubscription<State>>.weakObjects()
    public var otherStoresSubscriptions = [String: AnyObject]()
    internal lazy var stateTransactionQueue = DispatchQueue(label: "\(type(of: self)).StateTransactionQueue")

    // The current state of the store.
    // This should be protected and changed only by subclasses.
    public var state: State {
        didSet(oldState) {
            stateTransactionQueue.sync { [weak self, state] in
                self?.stateDidChange(oldState: oldState, newState: state)
            }
        }
    }

    public var storeIdentifier: String {
        return String(describing: self)
    }

    public init(initialState: State) {
        state = initialState
    }

    private func stateDidChange(oldState: State, newState: State) {
        // Prevent stores from invoking updates if the state has not changed.
        guard oldState != newState else {
            Debug.log("[\(debugDescription)] Skip forwarding same state: \(newState)", level: .low)
            return
        }

        subscriptions.allObjects.forEach {
            $0.fire(state)
        }
    }
}

// MARK: - Subscription
extension StateStore {
    // Helper method to subscribe to other stores that automatically retains the subscription tokens
    // so children stores can easily subscribe to other store changes without hassle.
    /// - Parameters:
    ///   - store: The store to subscribe to.
    ///   - weak: Should the subscription be a weak reference. Default is `True`.
    ///   - handler: Callback to respond to state changes.
    public func subscribe<T>(to store: StateStore<T>, weak: Bool = true, handler: @escaping (T) -> Void) {
        // If the subscription is not nil, check if it is a WeakRef and that the value is nil,
        // otherwise there is an attempt to resubscribe to a store and that is not allowed.
        if let subscription = otherStoresSubscriptions[store.storeIdentifier] {
            guard
                let weakSubscription = subscription as? WeakRef,
                weakSubscription.value == nil
            else {
                assertionFailure("Trying to subscribe to an already subscribed store.")
                return
            }
        }
        
        otherStoresSubscriptions[store.storeIdentifier] = weak
            ? WeakRef(store.subscribe(handler))
            : store.subscribe(handler)
    }

    public func unsubscribe<T>(from store: StateStore<T>) {
        if otherStoresSubscriptions[store.storeIdentifier] == nil {
            assertionFailure("Trying to unsubscribe from a not subscribed store.")
        }

        otherStoresSubscriptions[store.storeIdentifier] = nil
    }

    public func subscribe(_ closure: @escaping (State) -> Void) -> StateSubscription<State> {
        let subscription = StateSubscription(closure)
        subscriptions.add(subscription)
        subscription.fire(state)
        return subscription
    }
}

// MARK: - CustomDebugStringConvertible
extension StateStore: CustomDebugStringConvertible {
    public var debugDescription: String {
        return String(describing: type(of: self))
    }
}

// MARK: - WeakRef
extension StateStore {
    public final class WeakRef {
        weak var value: AnyObject?
        
        init(_ value: AnyObject?) {
            self.value = value
        }
    }
}
