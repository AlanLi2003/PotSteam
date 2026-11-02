import SwiftUI
import CoreText

struct DetailPage:View {
    @EnvironmentObject var store:KitchenStore;@State private var replace=false
    private var r:Recipe?{store.selected}
    var body:some View{Group { if let r = store.selected { ScrollView{VStack(alignment:.leading,spacing:16){
        BackHeader(title:"Recipe details"){store.route=""};FoodPhoto(recipe:r,height:218)
        Eyebrow(text:r.category);Text(r.name).font(Theme.title(31));Copy(text:r.chineseName)
        HStack{stat("\(r.minutes) min","Total time");stat(r.difficulty,"Difficulty");stat("\(store.servings)","Servings")}.padding(.vertical,10)
        SectionHead(title:"Make it your way")
        HStack{Text("Servings");Spacer();HStack(spacing:0){Button("−"){store.servings=max(1,store.servings-1)}.frame(width:44,height:44).accessibilityLabel("Decrease servings");Text("\(store.servings)").frame(width:30);Button("＋"){store.servings=min(8,store.servings+1)}.frame(width:44,height:44).accessibilityLabel("Increase servings")}.background(.white,in:Capsule()).overlay(Capsule().stroke(Theme.line))}.font(.system(size:13))
        HStack{Text("Measurements");Spacer();Picker("Measurements",selection:Binding(get:{store.preferences.units ?? "US"},set:{v in store.savePreferences{$0.units=v}})){Text("US").tag("US");Text("Metric").tag("Metric")}.pickerStyle(.segmented).frame(width:150)}.font(.system(size:13)).frame(minHeight:44)
        SectionHead(title:"Ingredients",trailing:"\(r.ingredients.count) items")
        ForEach(r.quote(store.servings,store.preferences.units ?? "US")?.ingredients ?? []){i in IngredientLine(name:i.name,quantity:i.display,ingredientId:i.ingredientId)}
        if !r.allergens.isEmpty{Note(text:"Allergen note: "+r.allergens.joined(separator:", ")+". Check actual product labels and potential cross-contact.",warning:true)}
        FavoriteButton(recipe:r)
    }.padding(22)}.safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:8){        Button("Get ready to cook →"){if store.disk.session != nil && store.disk.session?.phase != "complete"{replace=true}else{store.beginPrep()}}.buttonStyle(PressStyle())
        Button("Add ingredients to shopping list"){if store.addRecipeShopping(r){store.showNotice("Ingredients added to shopping list")}}.buttonStyle(PressStyle(secondary:true))
}.padding(.horizontal,22).padding(.vertical,10).background(Theme.paper)}}}.confirmationDialog("Replace the cooking session in progress?",isPresented:$replace,titleVisibility:.visible){Button("Start this recipe",role:.destructive){store.beginPrep()};Button("Resume existing session"){store.resume()}}}
    func stat(_ value:String,_ label:String)->some View{VStack(spacing:6){Text(value).font(.system(size:14,weight:.bold));Text(label).font(.system(size:10)).foregroundStyle(Theme.muted)}.frame(maxWidth:.infinity,minHeight:58).background(.white,in:RoundedRectangle(cornerRadius:9)).overlay(RoundedRectangle(cornerRadius:9).stroke(Theme.line))}
}
struct FavoriteButton:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.accessibilityReduceMotion)var reduced
    var recipe:Recipe;@State private var scale:CGFloat=1;@State private var token=UUID()
    private var saved:Bool{store.list("favorite").contains{$0.data.recipeId==recipe.id}}
    var body:some View{Button{store.toggleFavorite(recipe);guard !reduced else{return};let t=UUID();token=t;withAnimation(.easeOut(duration:0.08)){scale=0.92};Task{try? await Task.sleep(for:.milliseconds(80));guard t==token else{return};withAnimation(.easeOut(duration:0.08)){scale=1.12};try? await Task.sleep(for:.milliseconds(80));guard t==token else{return};withAnimation(.easeOut(duration:0.08)){scale=1}}}label:{Label(saved ? "Saved":"Save recipe",systemImage:saved ? "heart.fill":"heart").scaleEffect(scale)}.buttonStyle(PressStyle(ghost:true)).accessibilityValue(saved ? "Saved":"Not saved")}
}
struct PrepPage:View {
    @EnvironmentObject var store:KitchenStore
    var body:some View{if let s=store.disk.session{ScrollView{VStack(alignment:.leading,spacing:14){
        BackHeader(title:"Get ready"){store.route="detail"};Eyebrow(text:"Before you start",green:true);Text("Everything in place.").font(Theme.title());Copy(text:"Check your ingredients and equipment before cooking \(s.recipe.name).")
        VStack(alignment:.leading,spacing:0){SectionHead(title:"Checklist",trailing:"\(s.checked.count)/\(s.recipe.ingredients.count+s.recipe.equipment.count) ready")
        ForEach(s.recipe.quote(s.servings,s.units)?.ingredients ?? []){i in CheckLine(name:i.name,quantity:i.display,checked:s.checked.contains(i.id),ingredientId:i.ingredientId){store.updateSession{if $0.checked.contains(i.id){$0.checked.remove(i.id)}else{$0.checked.insert(i.id)}}}}
        SectionHead(title:"Equipment")
        ForEach(s.recipe.equipment){e in CheckLine(name:e.name,checked:s.checked.contains(e.id),equipmentId:e.id){store.updateSession{if $0.checked.contains(e.id){$0.checked.remove(e.id)}else{$0.checked.insert(e.id)}}}}
        }.padding(.horizontal,13).padding(.bottom,8).background(.white,in:RoundedRectangle(cornerRadius:14)).overlay(RoundedRectangle(cornerRadius:14).stroke(Theme.line))
        Note(text:"Review allergens and food safety directions. Keep raw foods separate from ready-to-eat ingredients.",warning:true)
        Button("Add unchecked ingredients to shopping list"){store.servings=s.servings;if store.addRecipeShopping(s.recipe,missing:Set(s.recipe.ingredients.filter{!s.checked.contains($0.id)}.map(\.id)),sessionServings:s.servings,sessionUnits:s.units){store.showNotice("Unchecked ingredients added")}}.buttonStyle(PressStyle(secondary:true))
    }.padding(22)}.safeAreaInset(edge:.bottom,spacing:0){VStack(spacing:4){
        Button("Start cooking →"){store.updateSession{$0.phase="cook"};store.route="cook"}.buttonStyle(PressStyle()).disabled(s.checked.count != s.recipe.ingredients.count+s.recipe.equipment.count)
        Button("Mark everything ready"){store.updateSession{$0.checked=Set(s.recipe.ingredients.map(\.id)+s.recipe.equipment.map(\.id))}}.buttonStyle(PressStyle(ghost:true))
    }.padding(.horizontal,22).padding(.vertical,8).background(Theme.paper)}}}
}
struct CookPage:View {
    @EnvironmentObject var store:KitchenStore
    @Environment(\.accessibilityReduceMotion) private var reduced
    var body:some View{if let s=store.disk.session,s.recipe.steps.indices.contains(s.step){let step=s.recipe.steps[s.step]
        ScrollView{VStack(alignment:.leading,spacing:18){BackHeader(title:s.recipe.name){store.leaveCooking()};Eyebrow(text:"Cooking mode · Step \(s.step+1) of \(s.recipe.steps.count)",green:true)
            HStack(spacing:5){ForEach(s.recipe.steps.indices,id:\.self){n in Capsule().fill(n<=s.step ? Theme.sage : Theme.line).frame(height:4)}}.accessibilityLabel("Step \(s.step+1) of \(s.recipe.steps.count)")
            Text(String(format:"%02d",s.step+1)).font(Theme.title(49)).foregroundStyle(Theme.line)
            VStack(alignment:.leading,spacing:16){Eyebrow(text:"One step at a time",green:true);Text(step.title).font(Theme.title(25));Text(step.instruction).font(.system(size:store.preferences.largeText==true ? 21:15)).lineSpacing(7).fixedSize(horizontal:false,vertical:true);Note(text:step.tip)}.padding(20).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:16)).overlay(RoundedRectangle(cornerRadius:16).stroke(Theme.line))
            if step.durationSeconds>0{TimerRing(session:s).frame(maxWidth:.infinity).padding(.vertical,5)}

            Button("View ingredients & quantities"){store.pauseTimer();store.drawer=true}.buttonStyle(PressStyle(ghost:true))
            Button("Save and exit cooking"){store.leaveCooking()}.buttonStyle(PressStyle(ghost:true))
        }.padding(22)}.safeAreaInset(edge:.bottom,spacing:0){            HStack(spacing:10){Button("← Back"){store.nextStep(-1)}.buttonStyle(PressStyle(secondary:true)).disabled(s.step==0);Button(s.step==s.recipe.steps.count-1 ? "Finish":"Next step →"){store.nextStep(1)}.buttonStyle(PressStyle()).accessibilityIdentifier("cook-next-"+String(s.step))}.padding(.horizontal,22).padding(.vertical,10).background(Theme.paper)}.id(s.id+"-"+String(s.step)).transition(.opacity).animation(.easeOut(duration:reduced ? 0.1:0.18),value:s.step)
        .sheet(isPresented:$store.drawer,onDismiss:{store.invalidate()}){IngredientDrawer(session:s).environmentObject(store)}
    }}
}
struct TimerRing:View {
    // Georgia has old-style numerals; use a serif face with lining, tabular digits for the countdown.
    static let digitFont:UIFont = {
        let base=UIFont.systemFont(ofSize:52).fontDescriptor
        let descriptor=(base.withDesign(.serif) ?? base).addingAttributes([.featureSettings:[
            [UIFontDescriptor.FeatureKey.type:kNumberCaseType,.selector:kUpperCaseNumbersSelector],
            [UIFontDescriptor.FeatureKey.type:kNumberSpacingType,.selector:kMonospacedNumbersSelector]
        ]])
        return UIFont(descriptor:descriptor,size:52)
    }()
    @EnvironmentObject var store:KitchenStore;@Environment(\.accessibilityReduceMotion)var reduced
    var session:CookSession
    var running:Bool{session.deadline != nil};var remaining:Int{session.seconds(at:store.clock)}
    var done:Bool{session.initialized && remaining==0};var color:Color{done ? Theme.sage : !running && session.initialized ? Theme.muted : running && remaining<=10 ? Color(hex:0xA1762B) : Theme.sage}
    var status:String{done ? "Done" : running ? remaining<=10 ? "Almost done":"Running" : session.initialized ? "Paused":"Optional step timer"}
    var seconds:Int{session.initialized ? remaining : session.recipe.steps[session.step].durationSeconds}
    var body:some View{VStack(spacing:12){ZStack{
        TimelineView(.animation(minimumInterval:1/15,paused:!running || reduced)){context in
            let period=remaining<=10 ? 1.2:2.4;let wave=(sin(context.date.timeIntervalSince1970*2*Double.pi/period)+1)/2
            Circle().stroke(color.opacity(running && !reduced ? 0.08+0.08*wave:0),lineWidth:12).scaleEffect(running && !reduced ? 1.02+0.03*wave:1)
        }
        Circle().stroke(Theme.line,lineWidth:6)
        Circle().trim(from:0,to:CGFloat(min(1,max(0,Double(seconds)/Double(max(1,session.recipe.steps[session.step].durationSeconds)))))).stroke(color,style:StrokeStyle(lineWidth:6,lineCap:.round)).rotationEffect(.degrees(-90))
        VStack(spacing:6){Text(status).font(.system(size:11,weight:.bold)).foregroundStyle(color);Text(String(format:"%02d:%02d",seconds/60,seconds%60)).font(Font(Self.digitFont)).fixedSize().accessibilityIdentifier("timer-readout")}
    }.frame(width:190,height:190).accessibilityElement(children:.combine)
        if !done{Button(running ? "Pause timer":session.initialized ? "Resume timer":"Start timer"){store.toggleTimer()}.buttonStyle(PressStyle(secondary:!running,primary:Theme.nav))}else{Text("Step complete").font(.system(size:12)).foregroundStyle(Theme.sage)}
    }}
}
struct IngredientDrawer:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.dismiss)var dismiss;var session:CookSession
    var body:some View{ScrollView{VStack(alignment:.leading,spacing:16){HStack{Text("Ingredients at a glance").font(Theme.title(25));Spacer();Button{dismiss()}label:{AppGlyph(name:"close").frame(width:44,height:44)}.accessibilityLabel("Close")}
        if session.initialized && session.remaining>0{Note(text:"Timer paused — close this sheet, then tap Resume timer to continue.",warning:true).foregroundStyle(Theme.accent)}
        VStack(alignment:.leading,spacing:5){Text(session.recipe.name).font(Theme.title(22));Copy(text:"\(session.servings) servings")}
        ForEach(session.recipe.quote(session.servings,session.units)?.ingredients ?? []){i in IngredientLine(name:i.name,quantity:i.display,ingredientId:i.ingredientId)}
    }.padding(22)}.background(Theme.paper).presentationDetents([.medium,.large]).presentationDragIndicator(.visible)}
}
struct CompletePage:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.accessibilityReduceMotion)var reduced
    @FocusState private var noteFocused:Bool
    @State private var ratingFeedback=UUID()
    @State private var noteDraft=""
    @State private var noteSessionID:String?
    private func loadNote(_ session:CookSession) {
        guard noteSessionID != session.id else{return}
        noteSessionID=session.id;noteDraft=session.note
    }
    @discardableResult private func persistNote()->Bool {
        guard let id=noteSessionID,store.disk.session?.id==id else{return false}
        if store.disk.session?.note==noteDraft {return true}
        return store.updateSession{$0.note=noteDraft}
    }
    var body:some View{if let s=store.disk.session{let animateRating = !reduced;let selectedRating=s.rating;ScrollView{VStack(spacing:18){BackHeader(title:"Well done"){store.route=""};Image(systemName:"checkmark.circle.fill").font(.system(size:55)).foregroundStyle(Theme.sage).padding(.top,28).accessibilityHidden(true);Eyebrow(text:"Meal complete");Text("You made it!").font(Theme.title(37));Copy(text:"One more Chinese dish you can cook with confidence.").multilineTextAlignment(.center);FoodPhoto(recipe:s.recipe,height:135).frame(maxWidth:230);Text(s.recipe.name).font(Theme.title(22));Copy(text:s.recipe.chineseName)
        VStack(alignment:.leading,spacing:8){Text("How did it turn out?").font(.system(size:12,weight:.bold));HStack(spacing:0){ForEach(1...5,id:\.self){rating in Button{store.updateSession{$0.rating=rating};ratingFeedback=UUID()}label:{Image(systemName:rating<=s.rating ? "star.fill":"star").font(.system(size:28)).foregroundStyle(rating<=s.rating ? Theme.accent:Theme.muted).frame(width:48,height:48).keyframeAnimator(initialValue:CGFloat(1),trigger:ratingFeedback){view,scale in view.scaleEffect(animateRating && rating==selectedRating ? scale:1)}keyframes:{_ in LinearKeyframe(1.08,duration:0.09);LinearKeyframe(1,duration:0.09)}}.accessibilityLabel("\(rating) stars").accessibilityAddTraits(s.rating==rating ? .isSelected:[])};Spacer();Text("\(s.rating) / 5").font(.system(size:11)).foregroundStyle(Theme.muted)}}.padding(14).frame(maxWidth:.infinity,alignment:.leading).background(.white,in:RoundedRectangle(cornerRadius:13)).overlay(RoundedRectangle(cornerRadius:13).stroke(Theme.line)).accessibilityElement(children:.contain).accessibilityLabel("Current rating: \(s.rating) of 5 stars")
        VStack(alignment:.leading,spacing:8){Text("A note for next time").font(.system(size:12,weight:.bold));TextField("What worked? Anything to improve?",text:$noteDraft,axis:.vertical).keyboardType(.asciiCapable).lineLimit(3...8).padding(12).background(.white,in:RoundedRectangle(cornerRadius:12)).overlay(RoundedRectangle(cornerRadius:12).stroke(Theme.line)).accessibilityIdentifier("cooking-note").focused($noteFocused)}
        Button(s.historySaved ? "Saved to cooking history":"Save to cooking history"){
            noteFocused=false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)
            Task {await Task.yield();guard store.route=="complete",store.disk.session?.id==noteSessionID else{return};if persistNote(){store.saveHistory()}}
        }.buttonStyle(PressStyle()).disabled(s.historySaved)
        Button("Explore more recipes →"){store.route="";store.tab="Explore"}.buttonStyle(PressStyle(ghost:true))
    }.padding(22)}.onAppear{loadNote(s)}.onChange(of:s.id){_,_ in loadNote(s)}
    .onChange(of:noteDraft){_,_ in persistNote()}.onDisappear{persistNote()}
    .scrollDismissesKeyboard(.interactively).toolbar{ToolbarItemGroup(placement:.keyboard){Spacer();Button("Done"){noteFocused=false}}}}}
}
