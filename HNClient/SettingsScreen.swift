//
//  SettingsScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-09-07.
//

import SwiftUI



struct SettingsScreen: View {
    struct ListSwipeAction: Identifiable {
        let label: String
        let color: Color
        let systemImage: String
        var id: String { label }
    }
    
    @State private var actions: [ListSwipeAction] = [
        ListSwipeAction(label: "Open Link", color: .blue, systemImage: "safari.fill"),
        ListSwipeAction(label: "Upvote", color: .teal, systemImage: "arrow.up.square.fill"),
        ListSwipeAction(label: "Search Web", color: .mint, systemImage: "globe.badge.chevron.backward"),
        ListSwipeAction(label: "Search HN", color: .indigo, systemImage: "magnifyingglass.circle.fill"),
        ListSwipeAction(label: "Share", color: .gray, systemImage: "square.and.arrow.up.fill"),
        ListSwipeAction(label: "View User", color: .black, systemImage: "person.crop.square.fill"),
        ListSwipeAction(label: "Save", color: .orange, systemImage: "bookmark.square.fill")
    ]
    var body: some View {
        List {
            ColorSection()
            Section("List Swipe Actions") {
                ForEach($actions, editActions: [.move]) { actionBinding in
                    let action = actionBinding.wrappedValue
                    HStack {
                        Image(systemName: action.systemImage)
                            .foregroundStyle(.white, action.color)
                            .font(.headline)
                        Text(action.label)
                            .font(.subheadline)
                    }
                }
            }


            Section("Web Links") {
                VStack(alignment: .leading) {
                    Text("Asds")
                        .font(.largeTitle)
                    Picker("AA", selection: .constant("Open in Safari")) {
                        Text("Open in Safari")
                            .tag("Open in Safari")
                        Text("Open in In-App Browser")
                    }
                    Toggle("Open HN Links in app", isOn: .constant(true))
                    Toggle("Long press post to preview link", isOn: .constant(true))
                }
            }
            Section("Saved Posts Storage") {
                Picker("Storage", selection: .constant("Open in Safari")) {
                    Text("Use HN Favourites")
                        .tag("Open in Safari")
                    Text("Use App")
                }
                Toggle("Cloudkit", isOn: .constant(true))
            }

            Section("Other Stuff") {
                Toggle("show images", isOn: .constant(true))
                Toggle("use bg img blur", isOn: .constant(true))
                Toggle("show next comment button", isOn: .constant(true))
                Toggle("allow next comment drag", isOn: .constant(true))
                Toggle("Store settings in icloud?", isOn: .constant(true))
            }
        }
        .font(.subheadline)
        .environment(\.editMode, .constant(.active))
        .navigationTitle("Settings")
    }
}


private struct CategoryColor: Identifiable {
    var color: Color
    let title: String
    var id: String {
        title
    }
}
private struct ColorSection: View {
    @State private var categories: [CategoryColor] = HackerNewsAPI.StoryCategory.allCases.map { category in
        CategoryColor(color: category.color, title: category.label)
    }

    @State private var editingCategoryColor: CategoryColor? = .none
    var body: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Story Categories")
                    .font(.title3)
                    .padding(.vertical, 7.5)
//                Toggle("Use Colors", isOn: .constant(true))
//                Text("one for each category - open some limited option picker like reminders")
            }
            ForEach($categories, editActions: [.move]) { category in
                HStack(spacing: 15) {
                        Image(systemName: "circle.fill")
                            .foregroundStyle(category.wrappedValue.color)
                            .font(.title2)
                        Text(category.wrappedValue.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                .onTapGesture {
                    editingCategoryColor = category.wrappedValue
                }
            }
        } header: {
            Text("")
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
        .sheet(item: $editingCategoryColor) { categoryColor in
            let index = categories.firstIndex(where: {$0.id == categoryColor.id })!
            
            CategoryColorPickerSheet(categoryColor: $categories[index])
        }
    }
}

private struct CategoryColorPickerSheet: View {
    @Binding var categoryColor: CategoryColor
    
    let colors: [Color] = [
        .black,
//        Color.darkGray,
        .gray,
//        Color.lightGray,
        .brown,
        .orange,
        .blue,
        .cyan,
        .teal,
        .mint,
        .green,
        .purple,
        .indigo,
        .pink,
        .red
    ]
    
    @State private var colorScheme: ColorScheme = .light
    var body: some View {
        VStack {
            VStack {
                GroupBox {
                    HStack {
                        Text(categoryColor.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .font(.title)
                            .fontWeight(.black)
                            .foregroundColor(categoryColor.color)
                        Spacer()
                        Image(systemName: colorScheme == .dark ? "sun.max.fill" : "moon.fill")
                            .onTapGesture {
                                withAnimation {
                                    colorScheme = colorScheme == .dark ? .light : .dark
                                }
                            }
                    }
                }
                .backgroundStyle(Material.ultraThin)
                
                
                GeometryReader { geometry in
                    VStack {
                        LoadingFrame(geometry: geometry)
                        LoadingFrame(geometry: geometry)
                    }
                }
                .padding(.horizontal)
            }
            .background(Color.systemBackground)
            .clipped()
            .environment(\.colorScheme, colorScheme)
            
            GroupBox {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 42), spacing: 10)]) {
                    ForEach(colors, id: \.self) { color in
                        ZStack {
                            Circle()
                                .frame(width: 50)
                                .opacity(color == categoryColor.color ? 1 : 0)
                                .foregroundColor(categoryColor.color.opacity(0.3))
                            Circle()
                                .fill(color)
                                .frame(width: 40)
                        }
                            .onTapGesture {
                                categoryColor.color = color
                            }
                    }
                }
                .padding(.bottom)
            }
            
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea(.container, edges: .bottom)
        .background(Color.secondarySystemBackground)
        .presentationDetents([.medium])
    }
}

struct SettingsScreen_Previews: PreviewProvider {
    static var previews: some View {
        SettingsScreen()
//            .environment(\.colorScheme, .dark)
    }
}
