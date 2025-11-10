//
//  ViewModel.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import Foundation
import Combine

/// A protocol that defines common functionality for view models
protocol ViewModel: ObservableObject {
    /// The associated input type that the view model accepts
    associatedtype Input
    
    /// The associated output type that the view model produces
    associatedtype Output
    
    /// Processes input events from the view
    /// - Parameter input: The input event to process
    func process(input: Input)
    
    /// Transforms view inputs into outputs
    /// - Parameter input: The input publisher emitting events from the view
    /// - Returns: A publisher emitting outputs to be observed by the view
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never>
}

/// A utility class for managing subscriptions
class CancellableBag {
    /// The set of cancellables
    private(set) var cancellables = Set<AnyCancellable>()
    
    /// Adds a cancellable to the bag
    /// - Parameter cancellable: The cancellable to add
    func add(_ cancellable: AnyCancellable) {
        cancellables.insert(cancellable)
    }
    
    /// Cancels all stored cancellables
    func cancelAll() {
        cancellables.forEach { $0.cancel() }
        cancellables.removeAll()
    }
}

/// A base class for view models that provides common functionality
class BaseViewModel<Input, Output>: ViewModel {
    /// The bag for managing cancellables
    let bag = CancellableBag()
    
    /// The subject for processing inputs
    let input = PassthroughSubject<Input, Never>()
    
    /// The subject for emitting outputs
    let output = PassthroughSubject<Output, Never>()
    
    /// Initializes the view model and sets up the transform pipeline
    init() {
        // Fix: Use add method instead of store(in:) to avoid inout parameter issues
        let subscription = transform(input: input.eraseToAnyPublisher())
            .subscribe(output)
        bag.add(subscription)
    }
    
    /// Processes an input event
    /// - Parameter input: The input event to process
    func process(input: Input) {
        self.input.send(input)
    }
    
    /// Transforms input events into output events
    /// - Parameter input: The input publisher
    /// - Returns: The output publisher
    func transform(input: AnyPublisher<Input, Never>) -> AnyPublisher<Output, Never> {
        // This is a placeholder implementation that should be overridden by subclasses
        // By default, it just returns an empty publisher
        return Empty<Output, Never>().eraseToAnyPublisher()
    }
}
