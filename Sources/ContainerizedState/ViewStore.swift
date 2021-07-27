import Foundation
import Debug

/// A state store designed to provide a view state to a ViewController and additional stateful views.
open class ViewStore<State: ViewState>: StateStore<State> {
    private var views = Set<AnyStatefulView<State>>()
    
    public override var state: State {
        didSet(oldState) {
            // Update every tracked stateful view with the updated state.
            stateTransactionQueue.sync { [weak self, state, oldState] in
                self?.views.forEach {
                    self?.stateDidChange(oldState: oldState, newState: state, view: $0)
                }
            }
        }
    }
    
    private func stateDidChange(oldState: State, newState: State, view: AnyStatefulView<State>, force: Bool = false) {
        switch view.renderPolicy {
        case .possible:
            handlePossibleRender(newState: newState, oldState: oldState, view: view, force: force)
        case .notPossible(let renderError):
            handleNotPossibleRender(error: renderError, view: view)
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
        
        if Thread.isMainThread {
            renderBlock()
        } else {
            DispatchQueue.main.async(execute: renderBlock)
        }
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
    
    func viewControllerDidLoad() {}
    
    func viewControllerWillAppear() {}
    func viewControllerDidAppear() {}
    func viewControllerWillDisappear() {}
    func viewControllerDidDisappear() {}
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
