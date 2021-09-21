import Foundation
import Debug

open class StateStore<State: StoreState> {
    private var subscriptions = NSHashTable<StateSubscription<State>>.weakObjects()
    public var otherStoresSubscriptions = [String: AnyObject]()
    internal lazy var stateTransactionQueue = DispatchQueue(
        label: "\(type(of: self)).\(storeIdentifier).StateTransactionQueue.\(UUID().uuidString)"
    )

    // The current state of the store.
    // This should be protected and changed only by subclasses.
    public var state: State {
        didSet(oldState) {
            stateTransactionQueue.async { [weak self, state, oldState] in
                self?.stateDidChange(oldState: oldState, newState: state)
            }
        }
    }

    /// String identifying a unique store. Override if needed to differentiate stores of the same type. Default: `String(describing: self)`
    open var storeIdentifier: String {
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

        DispatchQueue.main.async { [subscriptions, state] in
            subscriptions.allObjects.forEach {
                $0.fire(state)
            }
        }
    }
    
    // MARK: - Subscription
    
    // Helper method to subscribe to other stores that automatically retains the subscription tokens
    // so children stores can easily subscribe to other store changes without hassle.
    open func subscribe<T>(to store: StateStore<T>, handler: @escaping (T) -> Void) {
        if otherStoresSubscriptions[store.storeIdentifier] != nil {
            assertionFailure("Trying to subscribe to an already subscribed store.")
            return
        }
        
        otherStoresSubscriptions[store.storeIdentifier] = store.subscribe(handler)
    }

    open func unsubscribe<T>(from store: StateStore<T>) {
        if otherStoresSubscriptions[store.storeIdentifier] == nil {
            assertionFailure("Trying to unsubscribe from a not subscribed store.")
        }

        otherStoresSubscriptions[store.storeIdentifier] = nil
    }
    
    open func unsubscribe(from storeIdentifier: String) {
        if otherStoresSubscriptions[storeIdentifier] == nil {
            assertionFailure("Trying to unsubscribe from a not subscribed store.")
        }

        otherStoresSubscriptions[storeIdentifier] = nil
    }
    
    open func subscribe(_ closure: @escaping (State) -> Void) -> StateSubscription<State> {
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
