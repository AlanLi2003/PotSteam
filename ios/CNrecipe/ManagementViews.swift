import SwiftUI

struct KitchenPage:View {
    @EnvironmentObject var store:KitchenStore
    @State private var section="My Ingredients";@State private var filter="All items"
    @State private var editor:Entity?;@State private var shoppingSheet=false;@State private var clearPurchased=false
    private var soon:Int{store.list("inventory").filter{(0...2).contains(Dates.days($0.data.until) ?? -999)}.count}
    private var ingredients:[Entity]{store.list("inventory").filter{e in let d=Dates.days(e.data.until);switch filter{case "Use soon":return d != nil && (0...2).contains(d!);case "Expired":return d != nil && d!<0;case "No date":return d==nil;default:return true}}.sorted{(Dates.days($0.data.until) ?? 99999)<(Dates.days($1.data.until) ?? 99999)}}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:14){
        BrandHeader();Eyebrow(text:"Your everyday cooking space");Text("My Kitchen").font(Theme.title());Copy(text:"A little organization, better meals.")
        VStack(alignment:.leading,spacing:9){HStack(spacing:9){AppGlyph(name:"leaf").foregroundStyle(Theme.accent);Text(soon>0 ? "\(soon) ingredient\(soon==1 ? "":"s") to use soon":"Your storage dates are organized").font(.system(size:13,weight:.bold))};Copy(text:"Track what you store and plan what to cook next.");if soon>0{Button("Review these items →"){section="My Ingredients";filter="Use soon"}.font(.system(size:12,weight:.bold)).foregroundStyle(Theme.accent).padding(.horizontal,12).frame(minHeight:44).background(.white,in:RoundedRectangle(cornerRadius:8)).overlay(RoundedRectangle(cornerRadius:8).stroke(Theme.line))}}.padding(15).frame(maxWidth:.infinity,alignment:.leading).background(Theme.surface,in:RoundedRectangle(cornerRadius:15)).overlay(RoundedRectangle(cornerRadius:15).stroke(Theme.line))
        SubTabs(choices:["My Ingredients","Shopping List"],selected:$section,counts:["Shopping List":store.list("shopping").count])
        if section=="My Ingredients" {
            Chips(choices:["All items","Use soon","Expired","No date"],selected:$filter)
            ForEach(["Produce","Meat & Protein","Dairy & Eggs","Sauces & Pantry"],id:\.self){group in
                let items=ingredients.filter{$0.data.group==group}
                if !items.isEmpty{SectionHead(title:group,trailing:"\(items.count) item\(items.count==1 ? "":"s")");ForEach(items){item in Button{editor=item}label:{InventoryCard(entity:item)}.buttonStyle(.plain).accessibilityLabel("Edit \(item.data.name ?? "ingredient"), \(InventoryCard.status(item.data))")}}
            }
            if ingredients.isEmpty{EmptyState(title:"No items in this view",text:"Try another filter or add an ingredient.")}
            Button("＋ Add ingredient"){editor=Entity(kind:"inventory",id:UUID().uuidString,data:Fields(name:"",qty:"1 item",group:"Produce",storage:"Fridge",type:"Review on",added:Dates.today,until:""))}.buttonStyle(PressStyle(secondary:true)).accessibilityIdentifier("add-ingredient")
            Copy(text:"The colored bar shows the remaining proportion until your recorded date. It cannot measure actual freshness or determine safety. Follow product labels and storage guidance.")
        }else{
            VStack(spacing:7){
            ForEach(store.list("shopping")){e in HStack{
                CheckLine(name:e.data.name ?? "Item",quantity:e.data.qty ?? "",checked:e.data.checked ?? false,stacked:true,ingredientId:e.data.ingredientId){var d=e.data;d.checked = !(d.checked ?? false);store.enqueue("shopping",id:e.id,data:d)}
                Button{store.remove(e)}label:{Image(systemName:"xmark").frame(width:44,height:44)}.foregroundStyle(Theme.accent).accessibilityLabel("Remove \(e.data.name ?? "item")")
            }.padding(.horizontal,12).padding(.vertical,3).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(Theme.line))}}
            if store.list("shopping").isEmpty{EmptyState(title:"Your shopping list is empty",text:"Add ingredients from a recipe.")}
            Button("＋ Add shopping item"){shoppingSheet=true}.buttonStyle(PressStyle(secondary:true))
            Button("Clear purchased items"){clearPurchased=true}.buttonStyle(PressStyle(ghost:true)).disabled(!store.list("shopping").contains{$0.data.checked==true})
        }
    }.padding(.horizontal,22).padding(.top,14).padding(.bottom,110)}
    .sheet(item:$editor){e in NavigationStack{IngredientEditor(entity:e).toolbar(.hidden,for:.navigationBar)}.environmentObject(store)}
    .sheet(isPresented:$shoppingSheet){NavigationStack{ShoppingEditor().toolbar(.hidden,for:.navigationBar)}.environmentObject(store)}
    .confirmationDialog("Remove purchased items?",isPresented:$clearPurchased,titleVisibility:.visible){Button("Remove purchased items",role:.destructive){for e in store.list("shopping") where e.data.checked==true{store.remove(e)}}}}
}
struct InventoryCard:View {
    var entity:Entity
    static func status(_ d:Fields)->String{guard let days=Dates.days(d.until)else{return "Date not set"};return days<0 ? "Date passed" : days==0 ? "Check today":"\(days)d left"}
    private var color:Color{guard let days=Dates.days(entity.data.until)else{return Theme.muted};return days<=0 ? Theme.accent : days<=2 ? Theme.amber : Theme.sage}
    var body:some View{VStack(alignment:.leading,spacing:12){HStack(spacing:11){FoodIcon(name:entity.data.name ?? "",ingredientId:entity.data.ingredientId);VStack(alignment:.leading,spacing:5){Text(entity.data.name ?? "Ingredient").font(.system(size:14,weight:.bold));Text((entity.data.qty ?? "1 item")+" · "+(entity.data.storage ?? "")).font(.system(size:11)).foregroundStyle(Theme.muted)};Spacer();Text(Self.status(entity.data)).font(.system(size:11,weight:.bold)).foregroundStyle(color==Theme.amber ? Color(hex:0x795A20) : color)}
        if let ratio=Dates.proportion(entity.data){GeometryReader{g in Capsule().fill(Theme.line).overlay(alignment:.leading){Capsule().fill(color==Theme.amber ? Color(hex:0xA1762B):color).frame(width:g.size.width*ratio)}}.frame(height:5).accessibilityLabel("Recorded storage time remaining").accessibilityValue("\(Int(ratio*100)) percent")}
        HStack{Text("Added "+(entity.data.added ?? ""));Spacer();Text(entity.data.until?.isEmpty==false ? (entity.data.type ?? "Review on")+" · "+entity.data.until! : "Tap to set a date →")}.font(.system(size:11)).foregroundStyle(Theme.muted)
    }.foregroundStyle(Theme.ink).padding(14).background(.white,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Theme.line))}
}
struct IngredientEditor:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.dismiss) var dismiss
    var entity:Entity;@State private var fields=Fields();@State private var errors:[String:String]=[:];@State private var removal=false
    private var existing:Bool{store.list("inventory").contains{$0.id==entity.id}}
    func dateBinding(_ key:WritableKeyPath<Fields,String?>)->Binding<Date>{Binding(get:{Dates.parse(fields[keyPath:key]) ?? Date()},set:{fields[keyPath:key]=Dates.format($0)})}
    func field(_ label:String,_ key:WritableKeyPath<Fields,String?>)->some View{VStack(alignment:.leading,spacing:6){Text(label).font(.system(size:11,weight:.bold));TextField(label,text:Binding(get:{fields[keyPath:key] ?? ""},set:{fields[keyPath:key]=$0})).keyboardType(.asciiCapable).font(.system(size:16)).padding(12).background(.white,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(Theme.line)).accessibilityIdentifier(label);if let error=errors[label]{Text(error).font(.caption).foregroundStyle(Theme.accent)}}}
    func picker(_ title:String,_ values:[String],_ key:WritableKeyPath<Fields,String?>)->some View{VStack(alignment:.leading){Text(title).font(.system(size:11,weight:.bold));Picker(title,selection:Binding(get:{fields[keyPath:key] ?? values[0]},set:{fields[keyPath:key]=$0})){ForEach(values,id:\.self){Text($0)}}.tint(Theme.ink).frame(maxWidth:.infinity,minHeight:44).background(.white,in:RoundedRectangle(cornerRadius:9))}}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:16){
        HStack{Text(existing ? "Edit ingredient":"Add ingredient").font(Theme.title(25));Spacer();Button{dismiss()}label:{AppGlyph(name:"close").frame(width:44,height:44)}.accessibilityLabel("Close")}
        Copy(text:"Record known dates and storage details. Leave the tracked date blank if unknown.")
        field("Ingredient name",\.name);picker("Category",["Produce","Meat & Protein","Dairy & Eggs","Sauces & Pantry"],\.group);field("Quantity",\.qty)
        picker("Storage",["Fridge","Freezer","Pantry"],\.storage);picker("Date label",["Best before","Use by","Review on"],\.type)
        DatePicker("Added on",selection:dateBinding(\.added),displayedComponents:.date).font(.system(size:13)).frame(minHeight:44)
        if let e=errors["Added on"]{Text(e).font(.caption).foregroundStyle(Theme.accent)}
        Toggle("Set tracked date",isOn:Binding(get:{!(fields.until ?? "").isEmpty},set:{fields.until=$0 ? Dates.today:""})).tint(Theme.sage).font(.system(size:13)).frame(minHeight:44)
        if !(fields.until ?? "").isEmpty{DatePicker("Tracked date",selection:dateBinding(\.until),displayedComponents:.date).font(.system(size:13)).frame(minHeight:44)}
        if let e=errors["Tracked date"]{Text(e).font(.caption).foregroundStyle(Theme.accent)}
        Copy(text:"The bar is based only on these recorded dates. A best-before date is not a food safety cutoff. Do not invent a use-by date.")
        Button(existing ? "Save changes":"Add to kitchen"){
            errors=[:];let name=(fields.name ?? "").trimmingCharacters(in:.whitespacesAndNewlines)
            if name.isEmpty || name.count>70{errors["Ingredient name"]="Enter a name up to 70 characters."}
            if (fields.qty ?? "").count>35{errors["Quantity"]="Use up to 35 characters."}
            if Dates.parse(fields.added)==nil || (fields.added ?? "")>Dates.today{errors["Added on"]="Added date cannot be in the future."}
            if !(fields.until ?? "").isEmpty && (fields.until ?? "")<(fields.added ?? ""){errors["Tracked date"]="The tracked date cannot be earlier than the added date."}
            guard errors.isEmpty else{return};fields.name=name;let count=store.disk.outbox.count;store.enqueue("inventory",id:entity.id,data:fields);if store.disk.outbox.count>count{dismiss()}
        }.buttonStyle(PressStyle(primary:Theme.nav))
        if existing{Button("Remove ingredient",role:.destructive){removal=true}.buttonStyle(PressStyle(ghost:true))}
    }.padding(22)}.background(Theme.paper).scrollDismissesKeyboard(.interactively).modifier(KeyboardDone()).onAppear{fields=entity.data}.presentationDragIndicator(.visible)
    .confirmationDialog("Remove this ingredient?",isPresented:$removal,titleVisibility:.visible){Button("Remove ingredient",role:.destructive){let n=store.disk.outbox.count;store.remove(entity);if store.disk.outbox.count>n{dismiss()}}}
    }
}
struct ShoppingEditor:View{
    @EnvironmentObject var store:KitchenStore;@Environment(\.dismiss)var dismiss;@State private var name="";@State private var error=""
    var body:some View{VStack(alignment:.leading,spacing:18){HStack{Text("Add shopping item").font(Theme.title(25));Spacer();Button{dismiss()}label:{AppGlyph(name:"close").frame(width:44,height:44)}.accessibilityLabel("Close")};Copy(text:"Add a missing ingredient to the shopping list.");Text("Item name").font(.caption.bold());TextField("e.g. Sesame oil",text:$name).keyboardType(.asciiCapable).padding(12).background(.white,in:RoundedRectangle(cornerRadius:10)).accessibilityIdentifier("Item name");if !error.isEmpty{Text(error).font(.caption).foregroundStyle(Theme.accent)};Button("Add to list"){let value=name.trimmingCharacters(in:.whitespacesAndNewlines);guard !value.isEmpty,value.count<=80 else{error="Enter an item name up to 80 characters.";return};let n=store.disk.outbox.count;store.addShopping(name:value);if store.disk.outbox.count>n{dismiss()}}.buttonStyle(PressStyle(primary:Theme.nav));Spacer()}.padding(22).background(Theme.paper).modifier(KeyboardDone()).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)}
}
struct SavedPage:View {
    @EnvironmentObject var store:KitchenStore;@State private var section="Favorites"
    private var records:[Entity]{store.list("record").sorted{($0.data.completedAt ?? "")>($1.data.completedAt ?? "")}}
    private var recipes:[Recipe]{if section=="In progress"{return store.disk.session.map{$0.phase=="complete" ? []:[$0.recipe]} ?? []};return store.catalog.filter{r in store.list("favorite").contains{$0.data.recipeId==r.id}}}
    private var count:Int{section=="Cooking history" ? records.count:recipes.count}
    func row(_ r:Recipe,record:Entity?=nil)->some View{HStack(spacing:13){FoodPhoto(recipe:r,height:74).frame(width:86);VStack(alignment:.leading,spacing:6){Text(r.name).font(.system(size:14,weight:.bold));Text("\(r.minutes) min · \(r.difficulty)"+(section=="In progress" ? " · Resume cooking":"")).font(.system(size:11)).foregroundStyle(Theme.muted);if let record{Text(String(repeating:"★",count:record.data.rating ?? 0)).foregroundStyle(Theme.accent);if let note=record.data.note,!note.isEmpty{Text(note).foregroundStyle(Theme.muted)};Text(String((record.data.completedAt ?? "").prefix(10))).foregroundStyle(Theme.muted)}}.font(.system(size:11));Spacer()}.padding(10).foregroundStyle(Theme.ink).background(.white,in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(Theme.line))}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:15){BrandHeader();VStack(spacing:9){Eyebrow(text:"Your cooking collection");Text("Saved & made.").font(Theme.title());Copy(text:"Recipes you love, and the ones you've cooked.").multilineTextAlignment(.center)}.frame(maxWidth:.infinity).padding(.vertical,18);SubTabs(choices:["Favorites","Cooking history","In progress"],selected:$section,counts:["Favorites":store.list("favorite").count,"Cooking history":records.count,"In progress":store.disk.session?.phase=="complete" || store.disk.session==nil ? 0:1]);SectionHead(title:"\(count) "+(section=="Cooking history" ? (count==1 ? "cooking session":"cooking sessions"):(count==1 ? "recipe":"recipes")))
        if section=="Cooking history"{ForEach(records){record in if let r=record.data.recipeSnapshot ?? store.catalog.first(where:{$0.id==record.data.recipeId}){Button{store.open(r)}label:{row(r,record:record)}.buttonStyle(.plain)}}}
        else{ForEach(recipes){r in Button{if section=="In progress"{store.resume()}else{store.open(r)}}label:{row(r)}.buttonStyle(.plain)}}
        if count==0{EmptyState(title:"Nothing here yet",text:"Explore recipes, save favorites or finish a cooking session.");Button("Browse recipes →"){store.tab="Explore"}.buttonStyle(PressStyle(ghost:true))}
    }.padding(.horizontal,22).padding(.top,14).padding(.bottom,110)}}
}
struct SettingsPage:View {
    @EnvironmentObject var store:KitchenStore;@State private var login=false;@State private var logout=false;@State private var reset=false
    func pref(_ key:WritableKeyPath<Fields,String?>,fallback:String)->Binding<String>{Binding(get:{store.preferences[keyPath:key] ?? fallback},set:{v in store.savePreferences{$0[keyPath:key]=v}})}
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:18){BackHeader(title:"Settings"){store.route=""};VStack(alignment:.leading,spacing:5){Text("Preferences").font(.system(size:22,weight:.bold));Copy(text:"Set up your cooking space.")}
        VStack(spacing:0){
        HStack{Text("Language");Spacer();Text("English").foregroundStyle(Theme.muted)}.frame(minHeight:48);Divider().overlay(Theme.line)
        HStack{Text("Region");Spacer();Picker("Region",selection:pref(\.region,fallback:"United States")){ForEach(["United States","United Kingdom","Canada","Australia"],id:\.self){Text($0)}}.labelsHidden().pickerStyle(.menu).tint(Theme.muted)}.frame(minHeight:48);Divider().overlay(Theme.line)
        HStack{Text("Measurement units");Spacer();Picker("Measurement units",selection:pref(\.units,fallback:"US")){Text("US").tag("US");Text("Metric").tag("Metric")}.labelsHidden().pickerStyle(.menu).tint(Theme.muted).accessibilityIdentifier("settings-units")}.frame(minHeight:48);Divider().overlay(Theme.line)
        Toggle("Larger cooking text",isOn:Binding(get:{store.preferences.largeText ?? false},set:{v in store.savePreferences{$0.largeText=v}})).tint(Theme.sage).frame(minHeight:52)
        }.padding(.horizontal,13).background(.white,in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(Theme.line))
        SectionHead(title:"Ingredient alerts");Copy(text:"Highlight declared allergens. Always check labels and cross-contact.")
        VStack(spacing:0){ForEach(["Peanuts","Soy","Wheat","Eggs","Sesame"],id:\.self){a in Toggle(a,isOn:Binding(get:{(store.preferences.allergens ?? []).contains(a)},set:{v in store.savePreferences{d in var list=d.allergens ?? [];list.removeAll{$0==a};if v{list.append(a)};d.allergens=list}})).tint(Theme.sage).frame(minHeight:50);if a != "Sesame"{Divider().overlay(Theme.line)}}}.padding(.horizontal,13).background(.white,in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(Theme.line))
        if store.accountSyncEnabled {
        SectionHead(title:"Account & sync");Copy(text:store.syncStatus)
        if let auth=store.auth{Text(auth.user.email ?? "Signed in").font(.system(size:13));Button("Sync now"){Task{await store.refresh()}}.buttonStyle(PressStyle(secondary:true));Button("Sign out"){logout=true}.buttonStyle(PressStyle(ghost:true))}else{Copy(text:"Sign in with email to sync this kitchen across devices. You can keep cooking offline.");Button("Sign in with email"){login=true}.buttonStyle(PressStyle(secondary:true))}
        if store.importAvailable{Note(text:"Existing data on this device is kept separate. Choose whether to copy it into this account.");Button("Import this device's kitchen"){store.importDeviceData()}.buttonStyle(PressStyle(secondary:true));Button("Keep separate"){store.keepDeviceSeparate()}.buttonStyle(PressStyle(ghost:true))}
        ForEach(store.disk.conflicts){conflict in VStack(alignment:.leading,spacing:10){Note(text:conflict.receipt.message ?? "This change needs review",warning:true);Text(conflict.edit.data.name ?? conflict.edit.kind).font(.system(size:13,weight:.bold));HStack{Button("Keep my change"){store.resolve(conflict,keepMine:true)};Spacer();Button("Use cloud copy"){store.resolve(conflict,keepMine:false)}}.font(.system(size:12)).frame(minHeight:44)}}
        }
        SectionHead(title:"About");Copy(text:"PotSteam \(Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") as? String ?? "") (\(Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") as? String ?? ""))")
        Copy(text:"Your kitchen data is saved on this iPhone. Changing phones or removing the app may lose it.")
        Note(text:"Recipe and storage content is illustrative. Demo formulas and time estimates require culinary review.",warning:true)
        if store.auth==nil{Button("Reset device kitchen"){reset=true}.buttonStyle(PressStyle(secondary:true))}
    }.font(.system(size:14)).padding(22).padding(.bottom,20)}
    .sheet(isPresented:$login){if store.accountSyncEnabled {NavigationStack{LoginSheet().toolbar(.hidden,for:.navigationBar)}.environmentObject(store)}}
    .confirmationDialog("Reset this device’s kitchen? A recovery backup will be saved first.",isPresented:$reset,titleVisibility:.visible){Button("Reset device kitchen",role:.destructive){store.resetDeviceData()}}
    .confirmationDialog("Sign out? Pending changes stay in this account's local cache.",isPresented:$logout,titleVisibility:.visible){Button("Sign out",role:.destructive){do{try store.signOut()}catch{store.message=error.localizedDescription}}}}
}
struct LoginSheet:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.dismiss)var dismiss
    @State private var email="";@State private var error=""
    @State private var request:Task<Void,Never>?
    private var pending:EmailLinkAttempt? {store.emailLinkAttempt}
    private func send() {
        error=""
        let address=email
        request=Task {do {try await store.sendEmailLink(to:address)}catch {if !Task.isCancelled {self.error=error.localizedDescription}}}
    }
    private func cancel() {request?.cancel();do {try store.cancelEmailLink()}catch {store.message=error.localizedDescription}}
    var body:some View{VStack(alignment:.leading,spacing:20){
        HStack{Text("Your kitchen, everywhere.").font(Theme.title(26));Spacer();Button{cancel();dismiss()}label:{AppGlyph(name:"close").frame(width:44,height:44)}.accessibilityLabel("Close")}
        Copy(text:pending == nil ? "Enter your email to receive a sign-in link." : "Check your email. Open the sign-in link on this iPhone to continue.")
        TextField("Email address",text:$email).keyboardType(.emailAddress).textContentType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled().padding(13).background(.white,in:RoundedRectangle(cornerRadius:10)).disabled(pending != nil || store.emailLinkBusy)
        if pending != nil {Note(text:"Keep this request active while opening your email. Closing it cancels this sign-in request.")}
        let detail = error.isEmpty ? store.emailLinkError : error
        if !detail.isEmpty {Text(detail).font(.system(size:12)).foregroundStyle(Theme.accent)}
        TimelineView(.periodic(from:.now,by:1)){context in
            let seconds=pending.map{max(0,60-Int(context.date.timeIntervalSince($0.createdAt)))} ?? 0
            Button(store.emailLinkBusy ? "Please wait…" : pending == nil ? "Send sign-in link" : seconds>0 ? "Resend in \(seconds)s" : "Resend email link"){send()}.buttonStyle(PressStyle()).disabled(store.emailLinkBusy || seconds>0)
        }
        if pending != nil {Button("Use a different email"){cancel();error=""}.buttonStyle(PressStyle(ghost:true)).disabled(store.emailLinkBusy)}
        Copy(text:"Internal testing is available to project team email addresses.")
        Spacer()
    }.padding(22).background(Theme.paper).modifier(KeyboardDone()).presentationDragIndicator(.visible)
    .onAppear {if let pending {email=pending.email}}
    .onChange(of:store.auth?.user.id){_,id in if id != nil {dismiss()}}
    .onDisappear {cancel()}
    }
}
