import SwiftUI
import Combine

class KeyboardManager: ObservableObject {
    @Published private(set) var keyboardHeight: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        let showPublisher = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillShowNotification
        )
        .compactMap { notification -> CGFloat? in
            (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height
        }
        
        let hidePublisher = NotificationCenter.default.publisher(
            for: UIResponder.keyboardWillHideNotification
        )
        .map { _ in CGFloat(0) }
        
        Publishers.Merge(showPublisher, hidePublisher)
            .receive(on: DispatchQueue.main)
            .assign(to: \.keyboardHeight, on: self)
            .store(in: &cancellables)
    }
    
    deinit {
        cancellables.removeAll()
    }
} 