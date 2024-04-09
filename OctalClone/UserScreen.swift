//
//  UserScreen.swift
//  HNClient
//
//  Created by Myles Linder on 2023-08-01.
//

import SwiftUI

struct UserScreen: View {
    @Environment(\.navigateInCurrentTab) private var navigateInCurrentTab
    @StateObject private var userVM = UserFetcher()

    let id: String

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            header
            Group {
                if let user = userVM.user {
                    let userInfoItems = [
                        UserInfoItem(label: "Karma", value: user.karma.formatted(.number), systemName: "arrow.up.circle.fill"),
                        UserInfoItem(label: "User Since", value: formattedDateString(user.createdAt), systemName: "calendar.circle.fill"),
                        UserInfoItem(label: "Submission Count", value: user.submissionCount.formatted(.number), systemName: "number.circle.fill", destination: .story),
                        UserInfoItem(label: "Comment Count", value: user.commentCount.formatted(.number), systemName: "number.circle.fill", destination: .comment)
                    ]

                    LazyVGrid(columns: [GridItem(), GridItem()]) {
                        ForEach(userInfoItems, content: { item in UserInfoRow(user: user, item: item) })
                    }

                    Divider().frame(height: 1)
                    about
                } else {
                    Spacer()
                }
            }
        }
        .frame(alignment: .top)
        .padding()
        .loading(userVM.fetchStatus == .fetching)
        .navigationTitle(id)
        .hideNavbarTitle()
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if userVM.user == nil {
                await userVM.fetchUser(id: id)
            }
        }
    }
    
    private var header: some View {
        let title = Text(id)
            .font(.largeTitle.bold())
        let titleButton =  Button {
            if let user = userVM.user, let navigateInCurrentTab {
                navigateInCurrentTab(NavigableHNUser(id: user.username))
            }
            print("button", navigateInCurrentTab == nil)
        } label: {
            HStack {
                title
                Image(systemName: "chevron.up")
                    .font(.callout)
            }
        }
        return ViewThatFits {
            HStack(alignment: .center) {
                if navigateInCurrentTab != nil {
                    titleButton
                } else {
                    title
                }
                Spacer()
                userActivityNavLink
            }
            VStack(alignment: .trailing, spacing: 0) {
                Group {
                    if navigateInCurrentTab != nil {
                        titleButton
                    } else {
                        title
                    }
                }
                    .frame(maxWidth: .infinity, alignment: .leading)
                userActivityNavLink
            }
        }
    }

    private var userActivityNavLink: some View {
        Group {
            if let user = userVM.user {
                NavigationLink(value: NavigableHNUser(id: user.username, type: .activity())) {
                    VStack(alignment: .leading) {
                        HStack(spacing: 7) {
                            Image(systemName: "person.crop.circle.badge.clock")
                                .symbolRenderingMode(.hierarchical)
                                .font(.title2)
                            Text("Activity")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }

    private var about: some View {
        Group {
            if let user = userVM.user, let htmlText = user.$about, !htmlText.description.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(htmlText)
                }
                .padding(.top, 5)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                Spacer()
            }
        }
    }

}

struct UserInfoItem: Identifiable, Hashable {
    let label: String
    let value: String
    var id: String { label }
    let systemName: String
    var destination: Post.PostType? = .none
    
}

struct UserInfoRow: View {
    let user: User
    let item: UserInfoItem
    var body: some View {
        let label =   VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: item.systemName)
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.orange, Color(uiColor: UIColor.tertiarySystemFill))
                Spacer()
                Text(item.value)
                    .fontWeight(.bold)
            }
            Text(item.label)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.secondary)
        }
        return GroupBox {
            if let destination = item.destination {
                NavigationLink(value: NavigableHNUser(id: user.username, type: .activity(destination))) {
                    label
                }
            } else {
                label
            }
        }
        .padding(.vertical, 10)
        .foregroundColor(.primary)
        .backgroundStyle(Color.quaternarySystemFill)
    }
    
}


//struct UserPage_Previews: PreviewProvider {
//    static var previews: some View {
//        UserScreen(id: "davidbarker")
//    }
//}
