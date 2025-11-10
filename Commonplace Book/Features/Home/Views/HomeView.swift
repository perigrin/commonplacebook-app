//
//  HomeView.swift
//  Commonplace Book
//
//  Created by Chris Prather on 5/1/25.
//

import SwiftUI
import CoreData

/// The main home view showing a list of items
struct HomeView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = HomeViewModel()
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                itemList
                
                if items.isEmpty {
                    emptyStateView
                }
            }
            .navigationTitle("Items")
            .toolbar {
                leadingToolbarItems
                trailingToolbarItems
            }
            .overlay(
                errorView
            )
            Text("Select an item")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            viewModel.onAppear()
        }
        .accessibility(label: Text("Home Screen"))
        .accessibilityElement(children: .contain)
    }
    
    // MARK: - View Components
    
    /// List of items
    private var itemList: some View {
        List {
            ForEach(items) { item in
                NavigationLink {
                    ItemDetailView(item: item)
                } label: {
                    ItemRowView(item: item)
                }
                .accessibilityHint("Navigate to item details")
            }
            .onDelete(perform: deleteItems)
        }
        #if os(iOS)
        .listStyle(InsetGroupedListStyle())
        #else
        .listStyle(DefaultListStyle())
        #endif
        .refreshable {
            // Pull to refresh functionality
            viewModel.onAppear()
        }
        .loading(viewModel.isLoading)
    }
    
    /// Empty state view when there are no items
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("No Items")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Tap the + button to add a new item")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: addItem) {
                Label("Add Item", systemImage: "plus")
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)
        }
        .padding()
        .background(Color.primary.opacity(0.05))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding()
        .accessibility(label: Text("Empty state"))
    }
    
    /// Error view that displays when an error occurs
    @ViewBuilder
    private var errorView: some View {
        if let errorMessage = viewModel.errorMessage {
            VStack {
                Spacer()
                
                Text(errorMessage)
                    .font(.callout)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.red.opacity(0.9))
                    .cornerRadius(8)
                    .shadow(radius: 2)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibility(label: Text("Error message"))
            }
            .animation(.easeInOut, value: errorMessage)
            .zIndex(100) // Ensure error is on top
        }
    }
    
    /// Leading toolbar items
    @ToolbarContentBuilder
    private var leadingToolbarItems: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarLeading) {
            Button(action: {
                // Additional action like filtering
            }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .accessibilityLabel(Text("Filter"))
            }
        }
        #else
        ToolbarItem(placement: .automatic) {
            EmptyView()
        }
        #endif
    }
    
    /// Trailing toolbar items
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .navigationBarTrailing) {
            EditButton()
                .accessibilityLabel(Text("Edit list"))
        }
        #endif
        
        ToolbarItem {
            Button(action: addItem) {
                Label("Add Item", systemImage: "plus")
            }
            .accessibilityLabel(Text("Add new item"))
        }
    }
    
    // MARK: - Actions
    
    /// Adds a new item
    private func addItem() {
        withAnimation {
            viewModel.addItem(in: viewContext)
        }
    }

    /// Deletes items at the specified offsets
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            viewModel.deleteItems(at: offsets, items: items, in: viewContext)
        }
    }
}

// MARK: - Item Row View

/// A view representing a single item in the list
struct ItemRowView: View {
    let item: Item
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Item")
                    .font(.headline)
                if let timestamp = item.timestamp {
                    Text(ItemFormatter.format(timestamp))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // Makes the entire row tappable
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Item Detail View

/// A view showing the details of a single item
struct ItemDetailView: View {
    let item: Item
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let timestamp = item.timestamp {
                    VStack(spacing: 8) {
                        Text("Created at")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text(ItemFormatter.format(timestamp))
                            .font(.title2)
                    }
                    .padding()
                    .background(Color.primary.opacity(0.05))
                    .cornerRadius(10)
                }
                
                // Additional item details would go here
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Item Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .accessibility(label: Text("Item details screen"))
    }
}

// MARK: - Helpers

struct ItemFormatter {
    static func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Previews

#Preview {
    HomeView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
