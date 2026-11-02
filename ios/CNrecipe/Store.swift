import SwiftUI
import CryptoKit
import Network

@MainActor final class KitchenStore: ObservableObject {
    @Published private(set) var disk = DiskState()
    @Published private(set) var catalog: [Recipe] = []
    @Published var tab = "Explore" {didSet {if tab != oldValue {clearNotice()}}}
    @Published var route = "" {didSet {if route != oldValue {clearNotice();if route == "cook" {clock=Date()}}}}
    @Published var selected: Recipe?
    @Published var servings = 2; @Published var message = ""; @Published var syncStatus = "On this device"
    @Published var auth: AuthSession?; @Published var importAvailable = false; @Published var drawer = false
    @Published var clock = Date(); @Published var online = true
    @Published var exploreLoading = true
    @Published private(set) var emailLinkAttempt: EmailLinkAttempt?
    @Published private(set) var emailLinkBusy = false
    @Published private(set) var emailLinkError = ""
    private var notice: (id:UUID,text:String)?
    private var emailLinkGeneration = UUID()
    let accountSyncEnabled: Bool
    let api: API; let notifications = TimerNotifications()
    private let folder: URL
    private var scope = "device"; private var readFailed = false; private var syncing = false
    private var callback = UUID(); private let network = NWPathMonitor(); private var networkReady = false
    private var deviceImport: [Entity] = []
    private var deviceFingerprint: String?
    private var catalogGeneration = UUID()
    private var networkStopped = false
    private var networkRefreshTasks:[UUID:Task<Void,Never>] = [:]
    private let automaticNetwork: Bool
    var active = true
    init(folder: URL? = nil, monitor: Bool = true, loadAuth: Bool = true, api: API = API(), accountSyncEnabled: Bool = AppConfig.accountSyncEnabled) {
        self.accountSyncEnabled = accountSyncEnabled
        self.api = api
        automaticNetwork = monitor
        self.folder = folder ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("CNrecipe")
        do {
            let cached = self.folder.appendingPathComponent("catalog-v1.json")
            let bundled = Bundle.main.url(forResource:"catalog",withExtension:"json",subdirectory:"Content")!
            do { catalog = try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:cached)).validated().recipes }
            catch { catalog = try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:bundled)).validated().recipes }
            // A locked/unavailable Keychain must not disable the offline kitchen.
            // Keep its contents intact and prevent token replacement until unlocked.
            do { if loadAuth && accountSyncEnabled {
                auth = try SessionVault.read()
                if let pending = try SessionVault.readEmailLinkAttempt() {
                    if pending.isExpired(at: Date()) || auth != nil { try SessionVault.writeEmailLinkAttempt(nil) }
                    else { emailLinkAttempt = pending }
                }
            } }
            catch { message = "Secure sign-in storage is unavailable. Your offline kitchen remains usable. \(error.localizedDescription)" }
            scope = auth?.user.id ?? "device"
            try loadScope()
            if auth != nil {prepareDeviceImportSafely()}
        } catch { readFailed = true; message = "Saved data could not be read. Original files are preserved. \(error.localizedDescription)" }
        if monitor {
            network.pathUpdateHandler = { [weak self] path in Task { @MainActor in
                guard let self,!self.networkStopped else { return }; self.online = path.status == .satisfied
                if self.online {
                    let id=UUID()
                    self.networkRefreshTasks[id]=Task { [weak self] in
                        guard let self else{return}
                        await self.refresh()
                        self.networkRefreshTasks[id]=nil
                    }
                } else { self.syncStatus = "Offline · saved on this device" }
            }}; network.start(queue:DispatchQueue(label:"cnrecipe.connectivity"))
        }
    }
    // Drain monitor-triggered requests before an injected networking session is closed.
    func stopNetworkMonitoring() async {
        networkStopped=true;network.pathUpdateHandler=nil;network.cancel()
        let pending=Array(networkRefreshTasks.values);networkRefreshTasks.removeAll()
        for task in pending {task.cancel()}
        for task in pending {await task.value}
    }
    func showNotice(_ text:String) {
        let id=UUID();notice=(id,text);message=text
        Task { [weak self] in
            do {try await Task.sleep(for:.seconds(3))}catch{return}
            guard let self,self.notice?.id==id,self.message==text else{return}
            self.clearNotice()
        }
    }
    private func clearNotice() {
        guard let notice else{return}
        self.notice=nil
        if message==notice.text {message=""}
    }
    private var file: URL { folder.appendingPathComponent("state-v2-\(scope).json") }
    private func write(_ value: DiskState) throws {
        guard !readFailed else { throw APIError(message:"Storage needs recovery; the original file has not been overwritten.") }
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let data = try JSONEncoder().encode(value); guard data.count < 20_000_000 else { throw APIError(message:"Local storage is full. Your last saved copy is preserved.") }
        try data.write(to:file,options:[.atomic,.completeFileProtectionUntilFirstUserAuthentication])
    }
    @discardableResult func commit(_ change: (inout DiskState)->Void) -> Bool {
        var next=disk; change(&next)
        do { try write(next); disk=next; return true } catch { message="Changes could not be saved. \(error.localizedDescription)"; return false }
    }
    private func loadScope() throws {
        readFailed=false
        if FileManager.default.fileExists(atPath:file.path) {
            let next=try JSONDecoder().decode(DiskState.self,from:Data(contentsOf:file)); guard validDisk(next) else { throw APIError(message:"Saved data is invalid or unsupported") }; disk=next
        } else {
            disk=DiskState()
            if scope=="device" { try migrateLegacy() }
            try write(disk)
        }
        servings=disk.session?.servings ?? 2
        syncStatus=auth == nil ? "On this device" : "Ready to sync"
    }
    private func validDisk(_ value:DiskState)->Bool {
        guard value.version==2,value.cursor>=0,Set(value.entities.map(\.key)).count==value.entities.count,Set(value.outbox.map(\.id)).count==value.outbox.count else{return false}
        if let s=value.session {return s.recipe.version>0 && !s.recipe.ingredients.isEmpty && s.recipe.steps.indices.contains(s.step) && (1...8).contains(s.servings) && ["US","Metric"].contains(s.units) && ["prep","cook","complete"].contains(s.phase) && s.remaining>=0}
        return true
    }
    private func migrateLegacy() throws {
        let legacy=folder.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath:legacy.path) else { return }
        let data=try Data(contentsOf:legacy)
        guard let old=try JSONSerialization.jsonObject(with:data) as? [String:Any],old["version"] as? Int == 1,
              let pantry=old["pantry"] as? [[String:Any]],let saved=old["saved"] as? [String],let shopping=old["shopping"] as? [[Any]] else { throw APIError(message:"The previous app's file is invalid") }
        let hash=SHA256.hash(data:data).map{String(format:"%02x",$0)}.joined()
        let backup=folder.appendingPathComponent("legacy-v1-\(hash).json")
        if !FileManager.default.fileExists(atPath:backup.path) { try data.write(to:backup,options:.atomic) }
        func fields(_ obj:[String:Any]) throws -> Fields { try JSONDecoder().decode(Fields.self,from:JSONSerialization.data(withJSONObject:obj)) }
        for p in pantry { disk.entities.append(Entity(kind:"inventory",id:"legacy-\(p["id"] ?? UUID().uuidString)",data:try fields(p))) }
        for (i,p) in shopping.enumerated() where p.count>=2 { disk.entities.append(Entity(kind:"shopping",id:"legacy-shop-\(i)",data:Fields(name:p[0] as? String,checked:p[1] as? Bool ?? false))) }
        for id in saved where catalog.contains(where:{$0.id==id}) { disk.entities.append(Entity(kind:"favorite",id:id,data:Fields(recipeId:id))) }
        let records=old["records"] as? [[String:Any]] ?? []
        for (i,record) in records.enumerated() {
            guard let id=record["recipeId"] as? String,let r=catalog.first(where:{$0.id==id}) else { continue }
            disk.entities.append(Entity(kind:"record",id:"legacy-record-\(i)",data:Fields(recipeId:id,recipeVersion:r.version,rating:record["rating"] as? Int ?? 0,note:record["note"] as? String ?? "",completedAt:record["date"] as? String ?? ISO8601DateFormatter().string(from:Date()),recipeSnapshot:r)))
        }
        // The old history set could contain entries from before per-cook records existed.
        for id in old["history"] as? [String] ?? [] where !disk.entities.contains(where:{$0.kind=="record" && $0.data.recipeId==id}) {
            if let r=catalog.first(where:{$0.id==id}) { disk.entities.append(Entity(kind:"record",id:"legacy-history-\(id)",data:Fields(recipeId:id,recipeVersion:r.version,rating:0,note:"",completedAt:ISO8601DateFormatter().string(from:Date()),recipeSnapshot:r))) }
        }
        disk.entities.append(Entity(kind:"preferences",id:"preferences",data:Fields(units:old["units"] as? String ?? "US",region:old["region"] as? String ?? "United States",largeText:old["largeText"] as? Bool ?? false,allergens:old["allergens"] as? [String] ?? [])))
        if let ongoing=old["ongoing"] as? [String:Any],let id=ongoing["recipeId"] as? String,let r=catalog.first(where:{$0.id==id}) {
            var session=CookSession(recipe:r,servings:ongoing["servings"] as? Int ?? 2,units:old["units"] as? String ?? "US")
            session.phase=ongoing["phase"] as? String == "prep" ? "prep" : "cook";session.step=min(r.steps.count-1,max(0,ongoing["step"] as? Int ?? 0))
            for i in old["checked"] as? [Int] ?? [] { let ids=r.ingredients.map(\.id)+r.equipment.map(\.id);if ids.indices.contains(i){session.checked.insert(ids[i])} }
            if let timer=old["timer"] as? [String:Any] { session.remaining=max(0,timer["remaining"] as? Int ?? 0);session.initialized=timer["initialized"] as? Bool ?? false;if timer["running"] as? Bool == true,let deadline=timer["deadline"] as? Double { session.deadline=Date(timeIntervalSince1970:deadline/1000) } }
            session.rating=old["rating"] as? Int ?? 0;session.note=old["cookingNote"] as? String ?? "";disk.session=session
        }
        if old["completion"] as? Bool == true,let id=old["selected"] as? String,let r=catalog.first(where:{$0.id==id}) {
            var s=CookSession(recipe:r,servings:old["servings"] as? Int ?? 2,units:old["units"] as? String ?? "US");s.phase="complete";s.rating=old["rating"] as? Int ?? 0;s.note=old["cookingNote"] as? String ?? "";disk.session=s
        }
        disk.legacySHA256=hash
    }
    private static func visible(_ state: DiskState) -> [Entity] {
        var result=Dictionary(uniqueKeysWithValues:state.entities.map{($0.key,$0)})
        for op in state.conflicts.map(\.edit)+state.outbox {
            let key=op.kind+":"+op.entityId
            if op.action=="delete" { result.removeValue(forKey:key) }
            else { result[key]=Entity(kind:op.kind,id:op.entityId,data:op.data,revision:result[key]?.revision ?? 0) }
        }
        return result.values.filter{!$0.deleted}.sorted{$0.id<$1.id}
    }
    var visible: [Entity] {Self.visible(disk)}
    private func prepareDeviceImport() throws {
        let file=folder.appendingPathComponent("state-v2-device.json")
        guard FileManager.default.fileExists(atPath:file.path) else {deviceImport=[];importAvailable=false;return}
        let bytes=try Data(contentsOf:file),state=try JSONDecoder().decode(DiskState.self,from:bytes)
        guard validDisk(state) else{throw APIError(message:"Unsupported device data version")}
        deviceFingerprint=SHA256.hash(data:bytes).map{String(format:"%02x",$0)}.joined()
        deviceImport=Self.visible(state);importAvailable = !deviceImport.isEmpty && disk.deviceImportDecision != deviceFingerprint
    }
    private func prepareDeviceImportSafely(){do{try prepareDeviceImport()}catch{importAvailable=false;message="This device's previous data cannot be imported. Its original files are preserved."}}
    var storageNeedsRecovery:Bool{readFailed}
    func resetDeviceData() {
        guard auth==nil,scope=="device" else{message="Sign out before resetting this device's kitchen.";return}
        let blocked=readFailed
        do {
            let backup=folder.appendingPathComponent("reset-backup-"+UUID().uuidString)
            try FileManager.default.createDirectory(at:backup,withIntermediateDirectories:true)
            for name in ["state.json","state-v2-device.json"] {let source=folder.appendingPathComponent(name);if FileManager.default.fileExists(atPath:source.path){try FileManager.default.copyItem(at:source,to:backup.appendingPathComponent(name))}}
            readFailed=false;let next=DiskState();try write(next);disk=next;invalidate();notifications.cancel();route="";tab="My Kitchen";message="Device kitchen reset. A recovery backup was saved."
        }catch{readFailed=blocked;message="Reset could not be completed. Your original files are preserved. \(error.localizedDescription)"}
    }
    func list(_ kind:String)->[Entity] { visible.filter{$0.kind==kind} }
    var preferences: Fields { list("preferences").first?.data ?? Fields(units:"US",region:"United States",largeText:false,allergens:[]) }
    @discardableResult func enqueue(_ kind:String,id:String,data:Fields,action:String="put") -> Bool {
        let previous=disk.outbox.last{$0.kind==kind && $0.entityId==id}
        let base=disk.entities.first{$0.kind==kind && $0.id==id}?.revision ?? 0
        let op=Edit(kind:kind,entityId:id,action:action,baseRevision:base,data:data,dependsOn:previous?.id)
        if commit({$0.outbox.append(op)}) { Task { await sync() };return true };return false
    }
    func remove(_ entity:Entity) { enqueue(entity.kind,id:entity.id,data:entity.data,action:"delete") }
    func savePreferences(_ change:(inout Fields)->Void) { var d=preferences;change(&d);enqueue("preferences",id:"preferences",data:d) }
    func toggleFavorite(_ r:Recipe) { if let e=list("favorite").first(where:{$0.data.recipeId==r.id}) {remove(e)} else {enqueue("favorite",id:r.id,data:Fields(recipeId:r.id))} }
    @discardableResult func addShopping(name:String,ingredientId:String?=nil,qty:String?=nil) -> Bool {
        // Match the existing server merge rule while using the local kitchen:
        // repeat additions preserve the original quantity and checked state.
        let normalized=name.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        if let existing=list("shopping").first(where:{item in
            (ingredientId?.isEmpty == false && item.data.ingredientId == ingredientId) || item.data.name?.trimmingCharacters(in:.whitespacesAndNewlines).lowercased() == normalized
        }) {
            return enqueue("shopping",id:existing.id,data:existing.data,action:"shopping.add")
        }
        let id=ingredientId.map{"ingredient-"+$0} ?? "manual-"+SHA256.hash(data:Data(name.trimmingCharacters(in:.whitespacesAndNewlines).lowercased().utf8)).prefix(16).map{String(format:"%02x",$0)}.joined()
        return enqueue("shopping",id:id,data:Fields(name:name,qty:qty,ingredientId:ingredientId,checked:false),action:"shopping.add")
    }
    @discardableResult func addRecipeShopping(_ r:Recipe,missing:Set<String>?=nil,sessionServings:Int?=nil,sessionUnits:String?=nil) -> Bool {
        guard let quote=r.quote(sessionServings ?? servings,sessionUnits ?? preferences.units ?? "US") else {message="Ingredient quantities are unavailable. Try opening the recipe again.";return false}
        let items=quote.ingredients.filter{missing == nil || missing!.contains($0.id)}
        guard !items.isEmpty else {showNotice("No ingredients to add.");return false}
        for item in items {if !addShopping(name:item.name,ingredientId:item.ingredientId,qty:item.display) {return false}}
        return true
    }
    func refresh() async {
        let generation=UUID();catalogGeneration=generation
        do {
            let c:Catalog=try await api.call("/v1/catalog")
            if generation==catalogGeneration {try cacheRecipes(c,replace:true);online=true}
        } catch { syncStatus="Offline · using downloaded recipes" }
        await sync()
    }
    func query(_ q:String,filter:String) async throws -> Catalog {
        let generation=UUID();catalogGeneration=generation
        // Inventory and alert preferences remain on-device. The shared API only
        // receives the user's search text and a public recipe category filter.
        let remoteFilter = filter == "Pantry" ? "All" : filter
        var c=URLComponents();c.queryItems=[URLQueryItem(name:"q",value:q),URLQueryItem(name:"filter",value:remoteFilter)]
        let result:Catalog=try await api.call("/v1/catalog"+(c.string ?? ""))
        if generation==catalogGeneration {try cacheRecipes(result,replace:q.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && remoteFilter=="All")}
        return personalize(result,filter:filter)
    }
    private func personalize(_ response:Catalog,filter:String)->Catalog {
        let inventory=list("inventory")
        func normalized(_ value:String)->String {value.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()}
        let names=Set(inventory.compactMap{$0.data.name}.map(normalized))
        let ids=Set(inventory.compactMap{$0.data.ingredientId})
        let alerts=Set(preferences.allergens ?? [])
        var result=response
        result.recipes=response.recipes.compactMap {original in
            if filter=="Pantry", !original.ingredients.contains(where:{ids.contains($0.ingredientId) || names.contains(normalized($0.name)) || names.contains($0.ingredientId)}) {return nil}
            var recipe=original
            recipe.allergyAlerts=recipe.allergens.filter{alerts.contains(String($0.split(separator:" ").first ?? ""))}
            return recipe
        }
        return result
    }
    func downloadedCatalog(query:String="",filter:String="All")->Catalog {
        let q=query.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()
        let recipes=catalog.filter {recipe in
            let text=([recipe.name,recipe.chineseName,recipe.category]+recipe.ingredients.map(\.name)).joined(separator:" ").lowercased()
            guard q.isEmpty || text.contains(q) else {return false}
            switch filter {
            case "Quick":return recipe.minutes<=15
            case "Beginner":return recipe.difficulty=="Beginner"
            case "Vegetarian":return recipe.vegetarian
            case "Noodles":return recipe.category=="Rice & Noodles"
            default:return true
            }
        }
        return personalize(Catalog(schemaVersion:1,recipes:recipes,catalogVersion:"downloaded"),filter:filter)
    }
    func cacheRecipes(_ response:Catalog,replace:Bool)throws {
        _ = try response.validated()
        // Personal allergen annotations belong to the request, never the shared cache.
        let incoming=response.recipes.map{recipe in var base=recipe;base.allergyAlerts=nil;return base}
        var merged=replace ? []:catalog
        for recipe in incoming {if let i=merged.firstIndex(where:{$0.id==recipe.id}){merged[i]=recipe}else{merged.append(recipe)}}
        let cache=Catalog(schemaVersion:response.schemaVersion,recipes:merged,catalogVersion:response.catalogVersion)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        try JSONEncoder().encode(cache).write(to:folder.appendingPathComponent("catalog-v1.json"),options:.atomic);catalog=merged
    }
    func sync() async {
        guard accountSyncEnabled,automaticNetwork,auth != nil,!syncing,!readFailed,online else { return };syncing=true;defer{syncing=false}
        let originalScope=scope
        do {
            if let old=auth,old.expiry<Date().addingTimeInterval(60) { let renewed=try await api.refresh(old);guard scope==originalScope else{return};try SessionVault.write(renewed);auth=renewed }
            guard let auth else{return};syncStatus="Syncing…"
            let batch=try SyncRequest.bounded(cursor:disk.cursor,operations:disk.outbox)
            if let blocked=batch.blocked {
                commit{$0.outbox.removeAll{$0.id==blocked.id};$0.conflicts.append(Conflict(edit:blocked,receipt:Receipt(id:blocked.id,status:"rejected",message:"This change is too large to sync. The local copy is preserved.",entities:[])))}
                syncStatus="Changes need review";return
            }
            let r:SyncResponse=try await api.call("/v1/sync",body:JSONEncoder().encode(batch.request),token:auth.access_token)
            guard originalScope==scope else{return}
            let ok=commit { next in
                var entities=Dictionary(uniqueKeysWithValues:next.entities.map{($0.key,$0)})
                for e in r.entities {entities[e.key]=e}
                for receipt in r.receipts {
                    guard let op=next.outbox.first(where:{$0.id==receipt.id}) else{continue}
                    if receipt.status != "applied" { next.conflicts.append(Conflict(edit:op,receipt:receipt)) }
                    else if op.action=="shopping.add",let canonical=receipt.entities.first,canonical.id != op.entityId {
                        for i in next.outbox.indices where next.outbox[i].kind==op.kind && next.outbox[i].entityId==op.entityId {next.outbox[i].entityId=canonical.id}
                    }
                    next.outbox.removeAll{$0.id==receipt.id}
                }
                next.entities=Array(entities.values);next.cursor=r.cursor
            }
            if ok {syncStatus=disk.conflicts.isEmpty ? "Synced" : "Changes need review"}
            if !disk.outbox.isEmpty && ok { Task { await self.sync() } }
        }catch{syncStatus="Saved locally · sync will retry";message=error.localizedDescription}
    }
    func sendEmailLink(to rawEmail: String) async throws {
        guard accountSyncEnabled else {throw APIError(message:"Account sync is not available in this version.")}
        guard !emailLinkBusy else { return }
        let email = rawEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard email.count <= 254, email.range(of: "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$", options: .regularExpression) != nil else {
            throw APIError(message: "Enter a valid email address")
        }
        if let previous = emailLinkAttempt, Date().timeIntervalSince(previous.createdAt) < 60 {
            throw APIError(message: "Wait 60 seconds before requesting another email link.")
        }
        let previous = emailLinkAttempt
        let attempt = try EmailLinkAttempt.make(email: email)
        let generation = UUID(); emailLinkGeneration = generation
        try SessionVault.writeEmailLinkAttempt(attempt)
        emailLinkAttempt = attempt; emailLinkBusy = true; emailLinkError = ""
        defer { if emailLinkGeneration == generation { emailLinkBusy = false } }
        do {
            try await api.requestEmailLink(attempt)
            guard emailLinkGeneration == generation else { return }
        } catch {
            guard emailLinkGeneration == generation else { return }
            // A failed resend must not invalidate the previous email link.
            try SessionVault.writeEmailLinkAttempt(previous)
            emailLinkAttempt = previous; emailLinkError = error.localizedDescription
            throw error
        }
    }
    func cancelEmailLink() throws {
        emailLinkGeneration = UUID(); emailLinkBusy = false
        try SessionVault.writeEmailLinkAttempt(nil)
        emailLinkAttempt = nil; emailLinkError = ""
    }
    func completeEmailLink(_ url: URL) async {
        guard accountSyncEnabled else {return}
        do {
            let code = try EmailLinkCallback.code(from: url)
            guard !emailLinkBusy else { throw APIError(message: "Sign-in is already in progress. If needed, open the email link again when it finishes.") }
            guard let attempt = emailLinkAttempt else { throw APIError(message: "This sign-in link is no longer active. Request a new email link in Settings.") }
            guard !attempt.isExpired(at: Date()) else {
                try cancelEmailLink()
                throw APIError(message: "This sign-in request has expired. Request a new email link.")
            }
            let generation = emailLinkGeneration
            emailLinkBusy = true; emailLinkError = ""
            defer { if emailLinkGeneration == generation { emailLinkBusy = false } }
            let session: AuthSession
            do { session = try await api.exchangeEmailLink(code, attempt: attempt) }
            catch { guard emailLinkGeneration == generation else { return }; throw error }
            guard emailLinkGeneration == generation, emailLinkAttempt?.id == attempt.id else { return }
            guard session.user.email?.lowercased() == attempt.email.lowercased(), UUID(uuidString: session.user.id) != nil,
                  !session.access_token.isEmpty, !session.refresh_token.isEmpty, session.expires_in > 0 else {
                throw APIError(message: "The sign-in response does not match the requested account.")
            }
            try SessionVault.writeEmailLinkAttempt(nil)
            emailLinkAttempt = nil
            try signedIn(session)
            message = "Signed in successfully."
        } catch {
            emailLinkError = error.localizedDescription
            message = error.localizedDescription
        }
    }
    func signedIn(_ session:AuthSession) throws {
        guard accountSyncEnabled else {throw APIError(message:"Account sync is not available in this version.")}
        invalidate();pauseTimer()
        try SessionVault.write(session);auth=session;scope=session.user.id
        do {try loadScope()}catch{readFailed=true;message="Account cache cannot be read. Original files preserved.";throw error}
        prepareDeviceImportSafely();selected=nil;route="";tab="Explore"
        if automaticNetwork {Task {await refresh()}}
    }
    func importDeviceData() {
        guard accountSyncEnabled else {return}
        let edits=deviceImport.map{e in Edit(kind:e.kind,entityId:e.id,action:e.kind=="shopping" ? "shopping.add" : "put",baseRevision:disk.entities.first{$0.key==e.key}?.revision ?? 0,data:e.data,dependsOn:disk.outbox.last{$0.kind==e.kind && $0.entityId==e.id}?.id)}
        if commit({$0.outbox.append(contentsOf:edits);$0.deviceImportDecision=deviceFingerprint}) {deviceImport=[];importAvailable=false;Task{await sync()}}
    }
    func keepDeviceSeparate(){if commit({$0.deviceImportDecision=deviceFingerprint}){deviceImport=[];importAvailable=false}}
    func signOut() throws {
        try cancelEmailLink()
        invalidate();pauseTimer();try SessionVault.write(nil);auth=nil;scope="device";try loadScope();route="";selected=nil;notifications.cancel()
    }
    func resolve(_ conflict:Conflict,keepMine:Bool) {
        guard commit({$0.conflicts.removeAll{$0.id==conflict.id}}) else{return}
        if keepMine {enqueue(conflict.edit.kind,id:conflict.edit.entityId,data:conflict.edit.data,action:conflict.edit.action)}
    }
    func open(_ recipe:Recipe) {selected=recipe;servings=2;route="detail"}
    func beginPrep() {
        guard let r=selected else{return}
        invalidate();notifications.cancel()
        if commit({$0.session=CookSession(recipe:r,servings:servings,units:preferences.units ?? "US")}){route="prep"}
    }
    func resume() {guard let s=disk.session else{return};selected=s.recipe;servings=s.servings;route=s.phase}
    @discardableResult func updateSession(_ change:(inout CookSession)->Void)->Bool {commit{if $0.session != nil {change(&$0.session!)}}}
    func invalidate() {callback=UUID()}
    func pauseTimer() {invalidate();notifications.cancel();guard let s=disk.session,s.deadline != nil else{return};let seconds=s.seconds();updateSession{$0.remaining=seconds;$0.deadline=nil}}
    func toggleTimer() {
        guard let s=disk.session else{return};invalidate()
        if s.deadline != nil {pauseTimer();return}
        let seconds=s.initialized && s.remaining>0 ? s.remaining : s.recipe.steps[s.step].durationSeconds
        guard seconds>0 else{return};let now=Date();clock=now;let end=now.addingTimeInterval(Double(seconds))
        if commit({$0.session?.remaining=seconds;$0.session?.deadline=end;$0.session?.initialized=true}) {Task{guard disk.session?.id==s.id,disk.session?.deadline==end else{return};do{try await notifications.schedule(end)}catch{message=error.localizedDescription}}}
    }
    func nextStep(_ offset:Int) {
        invalidate();notifications.cancel()
        guard let s=disk.session else{return}
        let step=s.step+offset
        updateSession {next in next.deadline=nil;next.remaining=0;next.initialized=false;if step>=next.recipe.steps.count {next.phase="complete"}else{next.step=max(0,step)}}
        route=disk.session?.phase ?? ""
    }
    func tick() {
        let now=Date();if (route=="cook" || !Calendar.current.isDate(now,inSameDayAs:clock)),Int(now.timeIntervalSince1970) != Int(clock.timeIntervalSince1970) {clock=now}
        guard active,route=="cook",!drawer,let s=disk.session, s.deadline != nil,s.seconds()==0 else{return}
        notifications.cancel();let token=UUID();callback=token
        updateSession{$0.deadline=nil;$0.remaining=0;$0.initialized=true}
        Task {try? await Task.sleep(for:.milliseconds(1400));guard token==callback,route=="cook",!drawer,disk.session?.id==s.id,disk.session?.step==s.step else{return};nextStep(1)}
    }
    func leaveCooking() {pauseTimer();route="";tab="Saved"}
    func saveHistory() {
        guard let s=disk.session,!s.historySaved else{return}
        let data=Fields(recipeId:s.recipe.id,recipeVersion:s.recipe.version,rating:s.rating,note:s.note,completedAt:ISO8601DateFormatter().string(from:Date()),recipeSnapshot:s.recipe)
        let op=Edit(kind:"record",entityId:s.id,data:data)
        if commit({$0.outbox.append(op);$0.session?.historySaved=true}) {showNotice("Saved to cooking history");Task{await sync()}}
    }
}
