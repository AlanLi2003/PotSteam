import SwiftUI

enum Theme {
    static let paper=Color(hex:0xFAF9F6),ink=Color(hex:0x272B27),line=Color(hex:0xEAE9E3)
    static let accent=Color(hex:0xB64E38),sage=Color(hex:0x567B61),nav=Color(hex:0x323F35),amber=Color(hex:0xCE9E4A)
    static let muted=Color(hex:0x686F65),surface=Color(hex:0xF1F0EA)
    static func title(_ size:CGFloat=35)->Font { .custom("Georgia",size:size,relativeTo:.title) }
}
extension Color { init(hex:UInt) {self.init(red:Double((hex>>16)&255)/255,green:Double((hex>>8)&255)/255,blue:Double(hex&255)/255)} }
struct PressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) var reduced
    @Environment(\.isEnabled) var enabled
    var secondary=false;var ghost=false;var primary=Theme.accent
    func makeBody(configuration:Configuration)->some View {
        configuration.label.font(.system(size:14,weight:.semibold)).frame(maxWidth:.infinity,minHeight:48)
            .foregroundStyle(ghost ? Theme.accent : secondary ? Theme.ink : .white)
            .background(ghost ? .clear : secondary ? Color.white : primary,in:RoundedRectangle(cornerRadius:13))
            .overlay(RoundedRectangle(cornerRadius:13).stroke(secondary ? Theme.line : .clear))
            .contentShape(Rectangle()).opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && !reduced && enabled ? 0.97 : 1)
            .animation(.easeOut(duration:reduced ? 0.1 : 0.14),value:configuration.isPressed)
    }
}
struct Eyebrow: View { var text:String; var green=false;var body:some View {Text(text.uppercased()).font(.system(size:10,weight:.heavy)).tracking(1.7).foregroundStyle(green ? Theme.sage : Theme.accent)} }
struct Copy: View {var text:String;var body:some View{Text(text).font(.system(size:13)).foregroundStyle(Theme.muted).lineSpacing(5).fixedSize(horizontal:false,vertical:true)} }
struct Note: View {var text:String;var warning=false;var body:some View {Text(text).font(.system(size:13)).lineSpacing(4).frame(maxWidth:.infinity,alignment:.leading).padding(14).background(warning ? Color(hex:0xF4EDE3) : Color(hex:0xEAF0E8),in:RoundedRectangle(cornerRadius:12))} }
struct BrandHeader: View {
    @EnvironmentObject var store:KitchenStore
    var body:some View {HStack(spacing:0){Text("CN").foregroundStyle(Theme.ink);Text("recipe").foregroundStyle(Theme.accent);Text(" ✳︎").font(.system(size:12)).foregroundStyle(Theme.accent);Spacer();Button{store.route="settings"}label:{AppGlyph(name:"settings").frame(width:44,height:44).background(.white,in:Circle()).overlay(Circle().stroke(Theme.line))}.accessibilityLabel("Settings")}.font(.system(size:23,weight:.heavy))}
}
struct BackHeader: View {
    var title:String;var back:()->Void
    var body:some View {HStack{Button(action:back){Image(systemName:"chevron.left").frame(width:44,height:44).background(.white,in:Circle()).overlay(Circle().stroke(Theme.line))}.accessibilityLabel("Back");Spacer();Text(title).font(.system(size:14,weight:.bold)).multilineTextAlignment(.center);Spacer();Color.clear.frame(width:44,height:44)}.foregroundStyle(Theme.ink)}
}
struct SectionHead:View {var title:String;var trailing="";var body:some View{HStack{Text(title).font(.system(size:16,weight:.bold));Spacer();Text(trailing).font(.system(size:11)).foregroundStyle(Theme.muted)}.padding(.top,12)} }
struct Chips:View {
    var choices:[String];@Binding var selected:String;@Environment(\.accessibilityReduceMotion) var reduced
    var body:some View {ScrollView(.horizontal,showsIndicators:false){HStack(spacing:7){ForEach(choices,id:\.self){choice in Button{withAnimation(.easeOut(duration:reduced ? 0.1 : 0.16)){selected=choice}}label:{Text(choice).font(.system(size:11,weight:.bold)).padding(.horizontal,13).frame(minHeight:44).foregroundStyle(choice==selected ? .white : Theme.muted).background(choice==selected ? Theme.nav : .white,in:Capsule()).overlay(Capsule().stroke(choice==selected ? Theme.nav : Theme.line))}.accessibilityAddTraits(choice==selected ? .isSelected : [])}}}}
}
struct SubTabs:View {var choices:[String];@Binding var selected:String;var counts:[String:Int]=[:];var body:some View{HStack(spacing:17){ForEach(choices,id:\.self){choice in Button{selected=choice}label:{Text(choice+(counts[choice].map{" (\($0))"} ?? "")).font(.system(size:13,weight:.bold)).foregroundStyle(choice==selected ? Theme.ink : Theme.muted).frame(minHeight:46).accessibilityLabel(choice).overlay(alignment:.bottom){Rectangle().fill(choice==selected ? Theme.accent : .clear).frame(height:2)}}}}.frame(maxWidth:.infinity,alignment:.leading).overlay(alignment:.bottom){Rectangle().fill(Theme.line).frame(height:1).zIndex(-1)}} }
struct FoodIcon:View {
    var name:String;var ingredientId:String?=nil;var equipmentId:String?=nil
    private static let catalogAssets:[String:String] = {
        guard let url=Bundle.main.url(forResource:"ingredient-icons",withExtension:"json",subdirectory:"Content"),let bytes=try? Data(contentsOf:url),let mapping=try? JSONDecoder().decode([String:String].self,from:bytes) else{return [:]}
        return mapping
    }()
    private static let ingredientAssets=["tomatoes":"tomato","eggs":"egg","scallions":"scallions","cooking-oil":"oil","salt":"salt","chicken-breast":"chicken","peanuts":"peanuts","dried-chilies":"chilies","light-soy-sauce":"soy-sauce","cooked-chilled-rice":"rice","noodles":"noodles","bok-choy":"bok-choy","garlic":"garlic","tofu":"tofu","ground-pork":"pork","chili-bean-paste":"bean-paste"]
    private static let aliases:[String:[String]]=[
        "egg":["egg","eggs","鸡蛋","雞蛋"],"tomato":["tomato","tomatoes","番茄","西红柿","西紅柿"],
        "scallions":["scallion","scallions","spring onion","spring onions","green onion","green onions","葱","蔥","小葱","青葱"],
        "oil":["cooking oil","oil","vegetable oil","sesame oil","olive oil","食用油","油","植物油","香油","橄榄油"],
        "salt":["salt","盐","鹽"],"pepper":["white pepper","black pepper","pepper","白胡椒","白胡椒粉","黑胡椒","胡椒"],
        "chicken":["chicken breast","chicken breasts","chicken","鸡胸肉","雞胸肉","鸡肉"],
        "peanuts":["peanut","peanuts","花生"],"chilies":["dried chili","dried chilies","dried chilli","dried chillies","chili","chilies","干辣椒","乾辣椒","辣椒"],
        "soy-sauce":["light soy sauce","soy sauce","生抽","酱油","醬油"],
        "rice":["cooked chilled rice","cooked rice","rice","米饭","米飯","大米"],"noodles":["noodle","noodles","面条","麵條","面"],
        "bok-choy":["bok choy","pak choi","pak choy","青菜","小白菜","白菜","上海青"],"garlic":["garlic","garlic clove","garlic cloves","蒜","大蒜","蒜瓣"],
        "tofu":["tofu","bean curd","豆腐"],"pork":["ground pork","minced pork","pork","猪肉末","豬肉末","肉末","猪肉"],
        "bean-paste":["chili bean paste","chilli bean paste","doubanjiang","豆瓣酱","豆瓣醬"],
        "pan":["cooking pan","pan","平底锅"],"utensils":["cooking utensils","utensils","锅铲与筷子"]
    ]
    private static func normalized(_ value:String)->String{value.lowercased().replacingOccurrences(of:"-",with:" ").split(whereSeparator:{$0.isWhitespace}).joined(separator:" ")}
    static func assets(name:String,ingredientId:String?=nil,equipmentId:String?=nil)->[String] {
        if let equipmentId,let asset=catalogAssets["equipment:"+equipmentId]{return[asset]}
        if let ingredientId,let asset=ingredientAssets[ingredientId]{return[asset]}
        if let ingredientId,let asset=catalogAssets[ingredientId]{return[asset]}
        let key=normalized(name)
        if let asset=catalogAssets["name:"+key]{return[asset]}
        if key=="cooking pan and utensils"{return["pan","utensils"]}
        if let asset=aliases.first(where:{$0.value.contains(key)})?.key{return[asset]}
        return["ingredient"]
    }
    static func image(_ asset:String)->UIImage? {Bundle.main.path(forResource:asset,ofType:"png",inDirectory:"Content/icons").flatMap{UIImage(contentsOfFile:$0)}}
    var body:some View{HStack(spacing:4){ForEach(Self.assets(name:name,ingredientId:ingredientId,equipmentId:equipmentId),id:\.self){asset in
        if let ui=Self.image(asset){Image(uiImage:ui).renderingMode(.template).resizable().frame(width:24,height:24)}
        else{Image(systemName:"bag").resizable().scaledToFit().frame(width:24,height:24)}
    }}.foregroundStyle(Theme.sage).accessibilityHidden(true)}
}
struct FoodPhoto:View {
    var recipe:Recipe;var height:CGFloat=120;@State private var cloud:Data?
    private var image:UIImage? {
        if let cloud,let image=UIImage(data:cloud){return image}
        if let path=Bundle.main.path(forResource:recipe.bundledImage,ofType:nil,inDirectory:"Explore/assets"){return UIImage(contentsOfFile:path)}
        return nil
    }
    var body:some View{GeometryReader{g in if let image{Image(uiImage:image).resizable().scaledToFill().frame(width:g.size.width,height:height).clipped().accessibilityLabel(recipe.name)}else{Theme.surface.overlay(Text("Photo unavailable").font(.caption))}}.frame(height:height).clipShape(RoundedRectangle(cornerRadius:14)).task(id:recipe.imageKey){cloud=nil;let key=recipe.imageKey;let bytes=await RecipeImages.shared.image(key);guard !Task.isCancelled,recipe.imageKey==key else{return};cloud=bytes}}
}
struct IngredientLine:View {var name:String;var quantity:String;var ingredientId:String?=nil;var body:some View{HStack(spacing:10){FoodIcon(name:name,ingredientId:ingredientId);Text(name);Spacer();Text(quantity).foregroundStyle(Theme.muted)}.font(.system(size:13)).frame(minHeight:52).overlay(alignment:.bottom){Rectangle().fill(Theme.line).frame(height:1)}} }
struct CheckLine:View {
    @Environment(\.accessibilityReduceMotion) private var reduced
    var name:String;var quantity="";var checked:Bool;var stacked=false;var ingredientId:String?=nil;var equipmentId:String?=nil;var action:()->Void
    var body:some View{Button(action:action){HStack(spacing:11){
        ZStack{RoundedRectangle(cornerRadius:stacked ? 4:12).fill(checked ? Theme.sage : .clear);RoundedRectangle(cornerRadius:stacked ? 4:12).stroke(checked ? Theme.sage : Theme.muted,lineWidth:1.5);AppGlyph(name:"check").foregroundStyle(.white).mask(alignment:.leading){Rectangle().frame(width:checked ? 24:0)}}.frame(width:23,height:23)
        FoodIcon(name:name,ingredientId:ingredientId,equipmentId:equipmentId)
        if stacked{VStack(alignment:.leading,spacing:4){Text(name).foregroundStyle(Theme.ink);if !quantity.isEmpty{Text(quantity).font(.system(size:11)).foregroundStyle(Theme.muted)}};Spacer()}
        else{Text(name).foregroundStyle(Theme.ink);Spacer();if !quantity.isEmpty{Text(quantity).font(.system(size:11)).foregroundStyle(Theme.muted)}}
    }.font(.system(size:13)).padding(.vertical,7).frame(minHeight:44).contentShape(Rectangle()).animation(.easeOut(duration:reduced ? 0:0.18),value:checked)}.buttonStyle(.plain).accessibilityLabel(name+(quantity.isEmpty ? "" : ", "+quantity)).accessibilityValue(checked ? "Checked":"Unchecked").accessibilityAddTraits(checked ? .isSelected : [])}
}
struct EmptyState:View {var title:String;var text:String;var body:some View{VStack(spacing:12){Image(systemName:"leaf").font(.system(size:30)).foregroundStyle(Theme.sage).accessibilityHidden(true);Text(title).font(Theme.title(22));Copy(text:text)}.multilineTextAlignment(.center).frame(maxWidth:.infinity).padding(.vertical,48)} }
struct MainNavigation:View {
    @EnvironmentObject var store:KitchenStore;@Environment(\.accessibilityReduceMotion) var reduced
    @Namespace var nav
    let labels=["Explore","My Kitchen","Saved"],icons=["home","kitchen","heart"]
    var body:some View{HStack(spacing:0){ForEach(Array(labels.enumerated()),id:\.offset){i,label in Button{guard label != store.tab else{return};store.tab=label}label:{HStack(spacing:5){AppGlyph(name:icons[i]).frame(width:18,height:18);Text(label).font(.system(size:11,weight:.bold)).lineLimit(1).minimumScaleFactor(0.85)}.frame(maxWidth:.infinity,minHeight:46).foregroundStyle(store.tab==label ? .white : Theme.muted).background{if store.tab==label{if reduced{Capsule().fill(Theme.nav)}else{Capsule().fill(Theme.nav).matchedGeometryEffect(id:"selection",in:nav)}}}}.contentShape(Rectangle()).buttonStyle(.plain).accessibilityAddTraits(store.tab==label ? .isSelected : []).accessibilityIdentifier("tab-"+label)}}.padding(6).background(.regularMaterial,in:Capsule()).overlay(Capsule().stroke(Theme.line)).shadow(color:.black.opacity(0.08),radius:15,y:6).padding(.horizontal,22).padding(.bottom,12).animation(.easeOut(duration:reduced ? 0.1 : 0.28),value:store.tab)}
}

struct AppGlyph:View { var name:String;var body:some View {if let path=Bundle.main.path(forResource:"nav-"+name,ofType:"png",inDirectory:"Content/icons"),let image=UIImage(contentsOfFile:path){Image(uiImage:image).renderingMode(.template).resizable().aspectRatio(contentMode:.fit).frame(width:20,height:20).accessibilityHidden(true)}} }
struct KeyboardDone:ViewModifier {
    func body(content:Content)->some View{content.toolbar{ToolbarItemGroup(placement:.keyboard){Spacer();Button("Done"){UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),to:nil,from:nil,for:nil)}}}}
}
