#if os(iOS)

import UIKit

public class ViewController<State: ViewState, Store: ViewStore<State>, Delegate>: UIViewController, StatefulView {
    private var viewStore: Store
    public var delegate: Delegate?

    /// The last rendered state.
    /// - Note: The state provided in ``render(state:from:)`` should still be used as the main way a view is updated; This property should
    /// mainly be used data source patterned subviews, i.e. collection views.
    public var state: State

    public required init(viewStore: Store) {
        self.viewStore = viewStore
        self.state = viewStore.state
        
        super.init(nibName: nil, bundle: nil)
        
        precondition(self.viewStore is Delegate, "ViewStore does not conform to Delegate type: \(type(of: Delegate.self))")
        
        delegate = self.viewStore as? Delegate
    }
    
    public required init?(coder: NSCoder) {
        fatalError("ViewController does not support init?(coder:)")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .white
        
        // Subscription should happen after the subclass has completed any ViewDidLoad work.
        // Queue the subscription to ensure it happens after the current stack completes.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewStore += self
            self.viewStore.viewControllerDidLoad()
        }
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewStore.viewControllerWillAppear()
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewStore.viewControllerDidAppear()
    }
    
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewStore.viewControllerWillDisappear()
    }
    
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewStore.viewControllerDidDisappear()
    }
    
    public func render(state: State, from distinctState: State.StateType?) {
        self.state = state
    }
}

#endif
