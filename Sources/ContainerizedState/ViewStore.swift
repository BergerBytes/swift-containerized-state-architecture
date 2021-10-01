import Foundation
import Debug

/// Specialized ViewStore with ViewController lifecycle events.
/// Used with ``ViewController``
open class ViewControllerStore<State: ViewState>: ViewStore<State> {
    open func viewControllerDidLoad() {}
    open func viewControllerWillAppear() {}
    open func viewControllerDidAppear() {}
    open func viewControllerWillDisappear() {}
    open func viewControllerDidDisappear() {}
}

/// A state store designed to provide a view state to a ViewController and additional stateful views.
open class ViewStore<State: ViewState>: Store<State> {
    private var views = Set<AnyStatefulView<State>>()
    
    public override var state: State {
        didSet(oldState) {
            // Update every tracked stateful view with the updated state.
            stateTransactionQueue.async { [weak self, state, oldState, views] in
                views.forEach {
                    self?.stateDidChange(oldState: oldState, newState: state, view: $0)
                }
            }
        }
    }
    
    private func stateDidChange(oldState: State, newState: State, view: AnyStatefulView<State>, force: Bool = false) {
        let handleChange = { [weak self, oldState, newState, view, force] in
            switch view.renderPolicy {
            case .possible:
                self?.handlePossibleRender(newState: newState, oldState: oldState, view: view, force: force)
            case .notPossible(let renderError):
                self?.handleNotPossibleRender(error: renderError, view: view)
            }
        }
        
        if Thread.current == stateTransactionQueue || !Thread.isMainThread {
            DispatchQueue.main.sync(execute: handleChange)
        } else {
            handleChange()
        }
    }
    
    private func handlePossibleRender(newState: State, oldState: State, view: AnyStatefulView<State>, force: Bool) {
        if force == false && newState == oldState {
            Debug.log("Skip rendering with the same state: \(newState)", level: .low)
            return
        }
        
        let renderBlock = { [view, newState, oldState] in
            view.render(state: newState,
                        from: newState.current.isDistinct(from: oldState.current)
                            ? oldState.current
                            : nil)
        }
        
        DispatchQueue.main.async(execute: renderBlock)
    }
    
    private func handleNotPossibleRender(error: RenderPolicy.RenderError, view: AnyStatefulView<State>) {
        switch error {
        case .viewNotReady:
            assertionFailure(
                Debug.log("[\(view)] view not ready to be rendered", level: .error)
            )
        case .viewDeallocated:
            Debug.log("[\(view.identifier)] view deallocated", level: .warning)
            views.remove(view)
        }
    }
    
    public override func forcePushState() {
        // Update every tracked stateful view with the updated state.
        stateTransactionQueue.async { [weak self, state, views] in
            views.forEach {
                self?.stateDidChange(oldState: state, newState: state, view: $0, force: true)
            }
        }
    }
}

// MARK: - Subscription

extension ViewStore {
    public func subscribe<View: StatefulView>(from view: View) where View.State == State {
        let anyView = AnyStatefulView(view)
        if views.insert(anyView).inserted {
            stateDidChange(oldState: state, newState: state, view: anyView, force: true)
        } else {
            assertionFailure("Trying to subscribe from an already subscribed view.")
        }
    }
    
    public func unsubscribe<View: StatefulView>(from view: View) where View.State == State {
        if views.remove(AnyStatefulView(view)) == nil {
            assertionFailure("Trying to unsubscribe from a not subscribed view.")
        }
    }
}

public func += <State, View: StatefulView>(left: ViewStore<State>, right: View) where View.State == State {
    left.subscribe(from: right)
}

public func -= <State, View: StatefulView>(left: ViewStore<State>, right: View) where View.State == State {
    left.unsubscribe(from: right)
}
