//
//  View+Extensions.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI

// MARK: - View Modifiers

/// Applies a loading state to a view
struct LoadingModifier: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(isLoading)
                .blur(radius: isLoading ? 2 : 0)
            
            if isLoading {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                        .padding(.bottom, 16)
                    
                    Text("Loading...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.05))
                )
                .shadow(radius: 5)
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies a loading state to the view
    /// - Parameter isLoading: Whether the view is in a loading state
    /// - Returns: A modified view with a loading indicator
    func loading(_ isLoading: Bool) -> some View {
        modifier(LoadingModifier(isLoading: isLoading))
    }
    
    /// Conditionally applies a modifier to a view
    /// - Parameters:
    ///   - condition: The condition to check
    ///   - modifier: The modifier to apply if the condition is true
    /// - Returns: A modified view if the condition is true, otherwise the original view
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, modifier: (Self) -> Content) -> some View {
        if condition {
            modifier(self)
        } else {
            self
        }
    }
    
    /// Applies a shadow to a view with default parameters
    /// - Parameters:
    ///   - color: The shadow color
    ///   - radius: The shadow radius
    ///   - x: The shadow x offset
    ///   - y: The shadow y offset
    /// - Returns: A modified view with a shadow
    func standardShadow(
        color: Color = .black.opacity(0.1),
        radius: CGFloat = 5,
        x: CGFloat = 0,
        y: CGFloat = 2
    ) -> some View {
        shadow(color: color, radius: radius, x: x, y: y)
    }
    
    /// Applies a rounded border to a view
    /// - Parameters:
    ///   - color: The border color
    ///   - width: The border width
    ///   - cornerRadius: The corner radius
    /// - Returns: A modified view with a rounded border
    func roundedBorder(
        _ color: Color = .gray,
        width: CGFloat = 1,
        cornerRadius: CGFloat = 8
    ) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: width)
        )
    }
    
    /// Applies a card style to a view
    /// - Parameters:
    ///   - backgroundColor: The card background color
    ///   - cornerRadius: The corner radius
    /// - Returns: A modified view with a card style
    func cardStyle(
        backgroundColor: Color = Color.primary.opacity(0.05),
        cornerRadius: CGFloat = 10
    ) -> some View {
        self
            .padding()
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .standardShadow()
    }
    
    /// Makes the view dismissible by drag
    /// - Parameter onDismiss: The action to perform when the view is dismissed
    /// - Returns: A modified view that can be dismissed by drag
    func dismissible(onDismiss: @escaping () -> Void) -> some View {
        self
            .gesture(
                DragGesture(minimumDistance: 50, coordinateSpace: .local)
                    .onEnded { value in
                        if value.translation.height > 0 {
                            onDismiss()
                        }
                    }
            )
    }
}
