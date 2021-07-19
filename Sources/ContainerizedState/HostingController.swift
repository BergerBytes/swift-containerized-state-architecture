#if os(iOS)

import Foundation
import SwiftUI

@available(iOS 13.0, *)
class HostingController<State, Store: ViewStore<State>, Content: StateView>: UIHostingController<Content>, StatefulView where Content.StateType == State {
    private let viewStore: Store
    private let delegate: Content.Delegate
    private(set) var renderPolicy: RenderPolicy

    required init(viewStore: Store) {
        self.viewStore = viewStore
        self.renderPolicy = .notPossible(.viewNotReady)
        
        precondition(viewStore is Content.Delegate, "ViewStore does not conform to Delegate type: \(type(of: Content.Delegate.self))")
        
        delegate = viewStore as! Content.Delegate
        
        super.init(rootView: Content(state: viewStore.state, delegate: viewStore as? Content.Delegate))
        
        // SwiftUI does not need time to "load a view" like a UIViewController since the view is declarative.
        // The rendering can happen right away.
        self.renderPolicy = .possible
        self.viewStore += self
        self.viewStore.viewControllerDidLoad()
    }
    
    required init?(coder: NSCoder) {
        fatalError("HostingController does not support init?(coder:)")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewStore.viewControllerWillAppear()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewStore.viewControllerDidAppear()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        viewStore.viewControllerWillDisappear()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewStore.viewControllerDidDisappear()
    }
    
    func render(state: State, from distinctState: State.StateType?) {
        rootView = Content(state: state, delegate: delegate)
    }
}

#endif
