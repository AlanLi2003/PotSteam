import SwiftUI
import WebKit

struct ExploreWeb: UIViewRepresentable {
    @EnvironmentObject var store:KitchenStore
    func makeCoordinator()->ExploreBridge {ExploreBridge(store:store)}
    func makeUIView(context:Context)->WKWebView {
        let config=WKWebViewConfiguration();config.userContentController.addScriptMessageHandler(context.coordinator,contentWorld:.page,name:"explore")
        let web=WKWebView(frame:.zero,configuration:config);web.isOpaque=false;web.backgroundColor = .clear;web.scrollView.backgroundColor = .clear;web.navigationDelegate=context.coordinator
        let folder=Bundle.main.url(forResource:"Explore",withExtension:nil)!
        context.coordinator.folder=folder;web.loadFileURL(folder.appendingPathComponent("index.html"),allowingReadAccessTo:folder)
        return web
    }
    func updateUIView(_ uiView:WKWebView,context:Context){}
    static func dismantleUIView(_ uiView:WKWebView,coordinator:ExploreBridge){uiView.configuration.userContentController.removeScriptMessageHandler(forName:"explore")}
}
@MainActor final class ExploreBridge:NSObject,WKScriptMessageHandlerWithReply,WKNavigationDelegate {
    let store:KitchenStore;var folder:URL?
    private var queryCounter=0;private var servedRecipes:[String:Recipe]=[:]
    init(store:KitchenStore){self.store=store}
    private func trusted(_ url:URL?)->Bool{guard let url,let folder else{return false};return url.isFileURL && url.standardizedFileURL.path.hasPrefix(folder.standardizedFileURL.path+"/")}
    func userContentController(_ userContentController:WKUserContentController,didReceive message:WKScriptMessage,replyHandler:@escaping(Any?,String?)->Void){
        guard message.frameInfo.isMainFrame,trusted(message.frameInfo.request.url),let body=message.body as? [String:Any],let method=body["method"] as? String else{replyHandler(nil,"Untrusted Explore message");return}
        switch method {
        case "catalog":
            guard let query=body["query"] as? String,query.count<=180,let filter=body["filter"] as? String,["All","Quick","Beginner","Vegetarian","Noodles","Pantry"].contains(filter) else{replyHandler(nil,"Invalid search");return}
            queryCounter+=1;let counter=queryCounter
            Task{do{let c=try await store.query(query,filter:filter);if counter==queryCounter{servedRecipes=Dictionary(uniqueKeysWithValues:c.recipes.map{($0.id,$0)})};replyHandler(try JSONSerialization.jsonObject(with:JSONEncoder().encode(c)),nil)}catch{replyHandler(nil,error.localizedDescription)}}
        case "downloaded":
            let query=body["query"] as? String ?? "",filter=body["filter"] as? String ?? "All"
            guard query.count<=180,["All","Quick","Beginner","Vegetarian","Noodles","Pantry"].contains(filter) else {replyHandler(nil,"Invalid search");return}
            do{let result=store.downloadedCatalog(query:query,filter:filter);servedRecipes=Dictionary(uniqueKeysWithValues:result.recipes.map{($0.id,$0)});replyHandler(["recipes":try JSONSerialization.jsonObject(with:JSONEncoder().encode(result.recipes)),"ongoingName":store.disk.session?.phase == "complete" ? "" : store.disk.session?.recipe.name ?? ""],nil)}catch{replyHandler(nil,error.localizedDescription)}
        case "resume":store.resume();replyHandler(true,nil)
        case "openRecipe":guard let id=body["recipeId"] as? String,id.count<=100,let r=servedRecipes[id] ?? store.catalog.first(where:{$0.id==id})else{replyHandler(nil,"Recipe is not downloaded yet. Try again after syncing.");return};store.open(r);replyHandler(true,nil)
        case "settings":store.route="settings";replyHandler(true,nil)
        default:replyHandler(nil,"Unsupported Explore operation")
        }
    }
    func webView(_ webView:WKWebView,decidePolicyFor navigationAction:WKNavigationAction,decisionHandler:@escaping(WKNavigationActionPolicy)->Void){decisionHandler(trusted(navigationAction.request.url) ? .allow:.cancel)}
    func webViewWebContentProcessDidTerminate(_ webView:WKWebView){webView.reload()}
    func webView(_ webView:WKWebView,didStartProvisionalNavigation navigation:WKNavigation!){store.exploreLoading=true}
    func webView(_ webView:WKWebView,didFinish navigation:WKNavigation!){store.exploreLoading=false}
    func webView(_ webView:WKWebView,didFailProvisionalNavigation navigation:WKNavigation!,withError error:Error){store.exploreLoading=false;store.message="Explore could not open. Switch tabs to try again."}
}
