//
//  LoginSheet.swift
//  HNClient
//
//  Created by Myles Linder on 2023-09-06.
//

import SwiftUI

struct BackButtonSymbol {
    static var detail: UIImage {
        UIImage(systemName: "chevron.left.circle.fill")!
            .applyingSymbolConfiguration(.init(font: .preferredFont(forTextStyle: .title2)))!
            .applyingSymbolConfiguration(.init(weight: .semibold))!
    }

    static var primary: UIImage {
        UIImage(systemName: "chevron.left")!
    }
}

func isEqualImages(_ image1: UIImage, and image: UIImage) -> Bool {
    let data1: Data? = image1.pngData()
    let data: Data? = image.pngData()
    return data1 == data
}

class DestinationNavBarController: UIViewController {
    func setNavbarAppearance(_ image: UIImage) {
        navigationController?.navigationBar.standardAppearance.setBackIndicatorImage(image, transitionMaskImage: image)
        navigationController?.navigationBar.scrollEdgeAppearance?.setBackIndicatorImage(image, transitionMaskImage: image)
    }

    override func viewWillAppear(_ animated: Bool) {
        let img = BackButtonSymbol.detail
            .applyingSymbolConfiguration(.init(paletteColors:
                                                [traitCollection.userInterfaceStyle == .dark ? .black : .white, .darkText.withAlphaComponent(0.5)]
            ))!
        let appearance = UINavigationBarAppearance()
        appearance.setBackIndicatorImage(img, transitionMaskImage: img)
        appearance.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] = UIColor.clear
        appearance.configureWithTransparentBackground()
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        
        super.viewWillAppear(animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        setNavbarAppearance(BackButtonSymbol.primary)
        super.viewWillDisappear(animated)
    }
}


struct DesinationNavBarView: UIViewControllerRepresentable {
    var scrollDistance: CGFloat
    var threshold: CGFloat
    
    func makeUIViewController(context: Context) -> DestinationNavBarController {
        return DestinationNavBarController()
    }
    
    func updateUIViewController(_ uiViewController: DestinationNavBarController, context: Context) {
        var opacity: Double { scrollDistance > 0 ? abs(scrollDistance) / threshold : 0 }
        var symbolOpacity: Double { scrollDistance > 75 ? abs(scrollDistance - 75) / 130.0 : 0 }
        let op = context.environment.colorScheme == .dark ? min(1, 0 + symbolOpacity) : max(0, 1 - symbolOpacity)
        let color = UIColor(hue: 0, saturation: 0, brightness: op, alpha: 1)
        let img = BackButtonSymbol.detail
            .applyingSymbolConfiguration(.init(paletteColors: [color, .darkGray.withAlphaComponent(max(0.2, 1 - symbolOpacity * 1.5))]))!
       
        if scrollDistance >= threshold {
            // TODO: should the image check just check some state variable so not having to constantly compare images?
            if let currentBackSymbol = uiViewController.navigationController?.navigationBar.standardAppearance.backIndicatorImage, !isEqualImages(currentBackSymbol, and: BackButtonSymbol.primary) {
                Task {
                    UIView.animate(withDuration: 0.3) {
                        uiViewController.navigationController?.navigationBar.standardAppearance.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] = UIColor.label
                        uiViewController.navigationController?.navigationBar.scrollEdgeAppearance?.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] = UIColor.label
                        uiViewController.setNavbarAppearance(BackButtonSymbol.primary)
                        uiViewController.navigationController?.navigationBar.layoutIfNeeded()
                    }
                }
            }
        } else if scrollDistance < threshold, let currentBackSymbol = uiViewController.navigationController?.navigationBar.standardAppearance.backIndicatorImage, !isEqualImages(currentBackSymbol, and: img) {
            Task {
                UIView.animate(withDuration: 0.3) {
                    uiViewController.navigationController?.navigationBar.standardAppearance.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] = UIColor.clear
                    uiViewController.navigationController?.navigationBar.scrollEdgeAppearance?.backButtonAppearance.normal.titleTextAttributes[.foregroundColor] = UIColor.clear
                    uiViewController.setNavbarAppearance(img)
                    uiViewController.navigationController?.navigationBar.layoutIfNeeded()
                }
            }
        }
    }
}

class RootNavBarController: UIViewController {
    
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.navigationBar.topItem?.title = ""
        super.viewWillDisappear(animated)
    }
    
}

struct RootNavBarView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RootNavBarController { RootNavBarController() }
    func updateUIViewController(_ uiViewController: RootNavBarController, context: Context) {}
}

struct LoginSheet: View {
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @EnvironmentObject private var tabbb: Tab
    
    @StateObject private var loginVm = LoginVM()
    @StateObject private var userVM = UserFetcher()
    
    var isLoggedIn: Bool {
        loginVm.isLoggedIn
    }
   
    @State private var showSheet = false
    @State private var displayErrorCard = true
    @Namespace private var userErrorIconNamespace
    private let minListRowHeight = 55.0
    private var chevronColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
//            RootNavBarView()
//            Text("Support Topics").font(.headline).fontWeight(.medium)
            Grid {
                GridRow {
                    Group {
                        switch userVM.fetchStatus {
                        // TODO: handle fetching since there is a user to show
                        case .idle, .fetching:
                            if let user = userVM.hnUser {
                                let regularUser = User(username: user.id, about: HTMLText(user.about), karma: user.karma, createdAt: user.created, avg: nil, submitted: 0, updatedAt: String(Date().timeIntervalSince1970), submissionCount: 0, commentCount: 0, objectID: user.id)
                                Group {
                                    UserInfoRow(user: regularUser, item: .init(label: "User Since", value: formattedDateString(regularUser.createdAt), systemName: "calendar.circle.fill"))
                                    UserInfoRow(user: regularUser, item: .init(label: "Karma", value: user.karma.formatted(.number), systemName: "arrow.up.circle.fill"))
                                }
                            }
                        case .failed(let reason, let description):
                            GroupBox {
                                if displayErrorCard {
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(description ?? "Error")
                                            .font(.caption2.smallCaps())
                                            .foregroundColor(Color.darkGray)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        HStack {
                                            Image(systemName: "person.crop.circle.badge.xmark")
                                                .symbolRenderingMode(.multicolor)
                                                .matchedGeometryEffect(id: "userIcon", in: userErrorIconNamespace)
                                            Text(reason)
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        // debounce
                                        Text("Try Again")
                                    }
                                    .padding(.top, 2.5)
                                }
                            } label: {
                                Button {
                                    withAnimation {
                                        displayErrorCard.toggle()
                                    }
                                } label: {
                                    HStack {
                                        if !displayErrorCard {
                                            Image(systemName: "person.crop.circle.badge.xmark")
                                                .symbolRenderingMode(.multicolor)
                                                .matchedGeometryEffect(id: "userIcon", in: userErrorIconNamespace)
                                        }
                                        Text(displayErrorCard ? "Something went wrong with your profile" : "Unable to display user profile")
                                            .frame(maxWidth: .infinity, alignment: .leading)
//                                            .transaction { transaction in
//                                                transaction.disablesAnimations = true
//                                            }
                                        Image(systemName: "chevron.down")
                                            .rotationEffect(Angle(degrees: displayErrorCard ? -180 : 0))
                                            .font(.footnote)
                                    }
                                    .font(.subheadline)
                                }
                                .buttonStyle(.plain)
                            }
                            .backgroundStyle(Color.systemBackground)
                            .transaction { t in
                                t.animation = .linear
                            }
                            .transition(.move(edge: .top).animation(.easeInOut))
                            .gridCellColumns(2)
                        }
                    }
                }
              
                GridRow {
                    ZStack(alignment: .topTrailing) {
                        let square = bigSquare("Submit a Story", systemName: "mail.fill")
                            .backgroundStyle(Color.systemBackground)
                            .foregroundStyle(.orange)
                        if isLoggedIn {
                            square
                        } else {
                            Group {
                                square
                                    .allowsHitTesting(false)
                                Image(systemName: "lock")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .padding(7.5)
                            }
                            .onTapGesture {
                                showSheet = true
                            }
                        }
                    }
                  
                    bigSquare("Saved Posts", systemName: "bookmark.square.fill", navigable: true)
                        // rgb(255 213 153)
                        // rgb(254 234 204)
                        .backgroundStyle(Color(uiColor: UIColor(red: 254 / 255, green: 234 / 255, blue: 204 / 255, alpha: 1)))
                        .foregroundStyle(.white, .orange)
                }
                GridRow {
                    List {
                        Group {
//                            listItem("Saved Posts / Favourites", systemName: "bookmark.square.fill", destination: "saved")
//                                .foregroundStyle(.white, .orange)
                            listItem("History", systemName: "clock.fill", destination: ViewedPostHistory(posts: []))
                                .foregroundStyle(Color.darkGray)
                            listItem("Submissions", systemName: "doc.circle.fill", destination: NavigableHNUser(id: loginVm.username ?? "", type: .activity()), disabled: !isLoggedIn)
                                .foregroundStyle(.white, .indigo)
                            listItem("Comments", systemName: "text.bubble.fill", destination: NavigableHNUser(id: loginVm.username ?? "", type: .activity(.comment)), disabled: !isLoggedIn)
                                .foregroundStyle(.white, .teal)
                            listItem("Upvoted", systemName: "arrow.up.square.fill", destination: "activity", disabled: !isLoggedIn)
                                .foregroundStyle(.white, .mint)
                            listItem("Settings", systemName: "gear", destination: "settings")
                                .listRowSeparator(.hidden, edges: .bottom)
                                .foregroundStyle(.secondary, .primary)
                                .symbolRenderingMode(.multicolor)
                        }
                        .listRowBackground(Color.clear)
                    }
                    .environment(\.defaultMinListRowHeight, minListRowHeight)
                    .scrollContentBackground(.hidden)
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .frame(height: minListRowHeight * 5) // https://stackoverflow.com/a/68043068/4386422
                    .background(Color.systemBackground)
                    .roundCorners()
                    .gridCellColumns(2)
                }
                if !loginVm.isLoggedIn {
                    GridRow {
                        Button {
                            showSheet = true
                            
                        } label: {
                            HStack {
                                HNLogo()
                                Text("Hacker News Login")
                            }
                            .padding(.vertical, 7.5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.systemBackground)
                        .gridCellColumns(2)
                    }
                }
                if loginVm.isLoggedIn {
                    GridRow {
                        Link(destination: URL(string: "https://news.ycombinator.com/user?id=\(loginVm.username ?? "")")!) {
                            GroupBox {
                                HStack {
                                    Text("Edit Profile on HN")
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                }
                            }
                            .backgroundStyle(Color.systemBackground)
                        }
                        .gridCellColumns(2)
                    }
                    GridRow {
                        GroupBox {
                            Button(role: .destructive) {
                                loginVm.logout()
                            }
                            label: {
                                HStack {
                                    Text("Logout")
                                    Image(systemName: "door.right.hand.open")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .tint(.red)
                        }
                        .padding(.top)
                        .backgroundStyle(Color.tertiarySystemFill.opacity(0.5))
                        .gridCellColumns(2)
                    }
                }
            }
            .animation(.linear, value: userVM.fetchStatus)
        }
        .padding([.top, .horizontal])
        .background(Color.secondarySystemBackground)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(loginVm.username ?? "Profile")
                    .screenTitle()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundColor(.orange)
            }
        }
        .navigationTitle(loginVm.username ?? "Profile")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSheet) {
            LoginForm(loginVm: loginVm)
                .onChange(of: loginVm.authCookie != nil) { hasCookie in
                    if hasCookie {
                        showSheet = false
                    }
                }
        }
        // TODO: create an enum called like SystemView with the types as options
        .navigationDestination(for: String.self) { s in
            GeometryReader { geometry in
                switch s {
                case "saved":
                    SavedPostsScreen(id: .profile, containingGeometry: geometry)
                        .toolbar(.hidden, for: .navigationBar) // TODO: ignores safe area causes errors (see readme)
                case "settings":
                    SettingsScreen()
                default: EmptyView()
                }
            }
        }
        .navigationDestination(for: ViewedPostHistory.self) { _ in
            GeometryReader { geo in
                HistoryScreen(containingGeometry: geo)
                    .ignoresSafeArea(edges: .top)
                //                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
        .task(id: loginVm.username) {
            if let username = loginVm.username, userVM.hnUser == nil, userVM.fetchStatus == .idle {
                await userVM.fetchUser(id: username, type: .hn)
            }
        }
    }
    
    func bigSquare(_ title: String, systemName: String, navigable: Bool = false) -> some View {
        NavigationLink(value: "saved") {
            GroupBox {
                HStack {
                    VStack {
                        Image(systemName: systemName)
                            .font(.title)
                            .fontWeight(.regular)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 2.5)
                        Text(title)
                            .font(.callout)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .foregroundColor(.primary)
                    }
                    if navigable {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.primary)
                            .font(.footnote)
                            .fontWeight(.bold)
                    }
                }
            }
        }
    }
    
    func listItem<D: Hashable>(_ title: String, systemName: String, destination: D, disabled: Bool = false) -> some View {
        HStack(spacing: 15) {
            Image(systemName: systemName)
                .font(.title3)
            NavigationLink(value: destination) {
                Text(title)
                    .font(.callout)
                    .foregroundColor(.primary)
                    .font(.body)
            }
            
            .foregroundStyle(.clear, disabled ? .clear : chevronColor)
            .disabled(disabled)
        }
        .overlay {
            if disabled {
                Button {
                    showSheet = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "lock")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}

class LoginVM: ObservableObject {
    @Published var authCookie: HTTPCookie? =
        HTTPCookieStorage.shared.cookies?.first(where: { cookie in
            cookie.domain == "news.ycombinator.com"
        })

    var isLoggedIn: Bool { authCookie != nil }
    var username: String? {
        if let authCookie, let endOfName = authCookie.value.firstIndex(of: "&") {
            return String(authCookie.value[...authCookie.value.index(before: endOfName)])
        }
        return nil
    }
    
    func observer(_ n: Notification) {
        if let cookieStorage = n.object as? HTTPCookieStorage, let cookies = cookieStorage.cookies, let cookie = cookies.first(where: { cookie in
            cookie.domain == "news.ycombinator.com"
        }) {
            authCookie = cookie
        }
    }
    
    init() {
        NotificationCenter.default
            .addObserver(forName: NSNotification.Name.NSHTTPCookieManagerCookiesChanged, object: nil, queue: .main, using: observer)
    }
    
    @MainActor
    func login(username: String, password: String) async {
        // gaurd authCookie empty, username and password both not empty
        if authCookie == nil {
            await Login.send(username: username, password: password)
            authCookie =
                HTTPCookieStorage.shared.cookies?.first(where: { cookie in
                    cookie.domain == "news.ycombinator.com"
                })
        }
    }
    
    @MainActor
    func logout() {
        if let authCookie {
            HTTPCookieStorage.shared.deleteCookie(authCookie)
            self.authCookie = .none
            print("logout - SUCCESS!")
        } else {
            print("logout - nothing to do")
        }
    }
}

struct HNLogo: View {
    var body: some View {
        Text("HN")
            .fontWeight(.black)
            .foregroundColor(.white)
            .padding(.horizontal, 3)
            .padding(.vertical, 2)
            .background(.orange)
            .cornerRadius(5)
    }
}

struct LoginForm: View {
    typealias Feature = (String, String)
    
    @State private var username: String = ""
    @State private var password: String = ""
    
    let features: [Feature] = [
        ("Upvote stories you like", "arrow.up.square"),
        ("Comment on stories", "captions.bubble"),
        ("Reply to comments", "text.bubble"),
        ("Submit stories to HN", "doc.badge.plus"),
        ("Hide stories you're not interested in", "x.square")
    ]
    
    var title: some View {
        ZStack {
            HStack {
                HNLogo()
                    .font(.title2)
                Spacer()
            }
            Text("Login")
                .screenTitle()
        }
        .padding([.top, .horizontal])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            title
                .frame(maxWidth: .infinity, alignment: .leading)
            form
        }
        .background(Color.secondarySystemBackground)
    }
    
    @FocusState private var usernameFocused
    @FocusState private var passwordFocused
    @ObservedObject var loginVm: LoginVM
    
    @State private var bottomPadding = 0.0
    var form: some View {
        GeometryReader { _ in
            ScrollViewReader { _ in
                Form {
                    Section {
                        VStack(alignment: .leading) {
                            Text("Username")
                                .font(.caption.smallCaps())
                                .fontWeight(.medium)
                            TextField("paulg", text: $username)
                                .focused($usernameFocused)
                                .padding(.vertical, 2.5)
                                .onSubmit(of: .text) {
                                    passwordFocused = true
                                }
                        }
                        VStack(alignment: .leading) {
                            Text("Password")
                                .font(.caption.smallCaps())
                                .fontWeight(.medium)
                            SecureField("password", text: $password)
                                .focused($passwordFocused)
                                .padding(.vertical, 2.5)
                                .onSubmit(of: .text) {
                                    submitForm()
                                }
                        }
                        Button {
                            submitForm()
                        } label: {
                            Text("Login")
                                .font(.headline)
                                .fontWeight(.bold)
//                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(.plain)
                        .background(.orange)
                        .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
//                        .disabled(username.isEmpty || password.isEmpty)
                    }
                    .id(1)
                    Section {
                        ForEach(features, id: \.0) { feature in
                            HStack(spacing: 15) {
                                Image(systemName: feature.1)
                                    .foregroundStyle(.orange, .primary)
                                    .font(.title3)
                                    .fontWeight(.regular)
                                Text(feature.0)
                                    .font(.subheadline)
                            }
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .scrollIndicators(.hidden, axes: .vertical)
                .scrollDismissesKeyboard(.immediately)
//                .onAppear {
//                    withAnimation {
//                        scrollProxy.scrollTo(1, anchor: .top)
//                    }
//                }
            }
        }
//        .presentationDragIndicator(.visible)
    }
    
    private func validateForm() -> Bool {
        true
    }
    
    private func submitForm() {
        let validation = validateForm()
        if validation {
            Task {
                await loginVm.login(username: "myleslinder", password: "UPDATE_ME")
            }
        }
    }
}

// struct LoginScreen_Previews: PreviewProvider {
//    static var previews: some View {
//        LoginScreen()
//    }
// }
