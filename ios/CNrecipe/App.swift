import SwiftUI
import Combine

@main struct CNrecipeApp: App {
    @StateObject private var store = KitchenStore()
    var body: some Scene { WindowGroup { NavigationStack {KitchenRoot().toolbar(.hidden,for:.navigationBar)}.environmentObject(store).tint(Theme.accent).preferredColorScheme(.light) } }
}
struct KitchenRoot: View {
    @EnvironmentObject var store: KitchenStore
    @Environment(\.scenePhase) private var phase
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    var body: some View {
        ZStack(alignment: .bottom) {
            Theme.paper.ignoresSafeArea()
            Group {
                switch store.route {
                case "detail": DetailPage()
                case "prep": PrepPage()
                case "cook": CookPage()
                case "complete": CompletePage()
                case "settings": SettingsPage()
                default:
                    switch store.tab {
                    case "My Kitchen": KitchenPage()
                    case "Saved": SavedPage()
                    default: ExploreWeb().overlay{if store.exploreLoading{ProgressView("Opening your kitchen…").font(.caption).allowsHitTesting(false)}}
                    }
                }
            }
        }
        .safeAreaInset(edge:.bottom,spacing:0){if store.route.isEmpty{MainNavigation()}}
        .foregroundStyle(Theme.ink).tint(Theme.accent)
        .safeAreaInset(edge:.top,spacing:0) {
            if !store.message.isEmpty {
                HStack(alignment:.top) {
                    Text(store.message).font(.system(size:12)).frame(maxWidth:.infinity,alignment:.leading)
                    if store.storageNeedsRecovery {Button("Recovery settings"){store.route="settings"}.font(.caption)}
                    Button("Dismiss"){store.message=""}.font(.system(size:11,weight:.bold)).frame(minWidth:44,minHeight:44)
                }.padding(.horizontal,16).background(Theme.surface).accessibilityElement(children:.contain)
            }
        }
        .onOpenURL { url in if store.accountSyncEnabled {Task { await store.completeEmailLink(url) }} }
        .onReceive(ticker){_ in store.tick()}
        .onChange(of:phase){_,next in store.active=next == .active;if next == .active {store.tick();Task{await store.refresh()}}}
        .task {await store.refresh();while !Task.isCancelled {do{try await Task.sleep(for:.seconds(30))}catch{return};if store.active {await store.sync()}}}
    }
}

#if DEBUG
#Preview { NavigationStack {KitchenRoot().toolbar(.hidden,for:.navigationBar)}.environmentObject(KitchenStore()).tint(Theme.accent).preferredColorScheme(.light) }
#endif
