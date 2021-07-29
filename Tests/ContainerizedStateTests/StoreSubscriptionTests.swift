   import Debug
   import XCTest
   @testable import ContainerizedState
   
   final class StoreSubscriptionTests: XCTestCase {
    func test_releaseStoreFromSubscription_whenDeallocated() {
        struct SomeState: StoreState {
            enum State: EnumState {
                case none
            }
            
            var current: State = .none
        }
        
        class SomeOtherStore: StateStore<SomeState> {
            var otherStore: SomeStore?
            var deinitCallback: (() -> Void)
            
            init(deinitCallback: @escaping (() -> Void)) {
                self.deinitCallback = deinitCallback
                super.init(initialState: .init())
            }
            
            deinit {
                deinitCallback()
            }
        }
        
        class SomeStore: StateStore<SomeState> {
            var otherStore: SomeOtherStore?

            init(deinitCallback: @escaping (() -> Void)) {
                super.init(initialState: .init())
                
                otherStore = SomeOtherStore(deinitCallback: deinitCallback)
                subscribe(to: otherStore!) { [weak self] _ in
                    Debug.log("First Store: \(self!)")
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1)) {
                    self.otherStore = nil
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(2)) {
                    self.otherStore = SomeOtherStore(deinitCallback: deinitCallback)
                    self.otherStore?.deinitCallback = deinitCallback
                    self.subscribe(to: self.otherStore!) { _ in
                        Debug.log("Second Store: \(self)")
                    }
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(3)) {
                    self.otherStore = nil
                }
            }
        }
        
        let expectation = XCTestExpectation(description: "Retain cycle")
        
        var deinitCallCount: Int = 0
        let someStore = SomeStore {
            deinitCallCount += 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(4)) {
            XCTAssertEqual(2, deinitCallCount)
            expectation.fulfill()
            _ = someStore
        }
        
        wait(for: [expectation], timeout: 1.0)
    }
   }
