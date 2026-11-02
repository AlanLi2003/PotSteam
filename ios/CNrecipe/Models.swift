import Foundation
import CryptoKit
import Security

struct Catalog: Codable {
    var schemaVersion: Int; var recipes: [Recipe]; var catalogVersion: String
    func validated() throws -> Catalog {
        guard schemaVersion == 1, Set(recipes.map(\.id)).count == recipes.count else {
            throw APIError(message:"Unsupported or invalid recipe catalog.")
        }
        for recipe in recipes {
            guard !recipe.id.isEmpty, recipe.version > 0, !recipe.name.isEmpty,
                  !recipe.ingredients.isEmpty, !recipe.steps.isEmpty,
                  Set(recipe.ingredients.map(\.id)).count == recipe.ingredients.count,
                  Set(recipe.steps.map(\.id)).count == recipe.steps.count,
                  recipe.steps.allSatisfy({!$0.id.isEmpty && !$0.instruction.isEmpty && $0.durationSeconds >= 0}),
                  recipe.quotes.count == 16 else {
                throw APIError(message:"Recipe content is incomplete. Your downloaded recipes are preserved.")
            }
            let ingredients = Dictionary(uniqueKeysWithValues:recipe.ingredients.map{($0.id,$0.ingredientId)})
            for servings in 1...8 { for units in ["US","Metric"] {
                let matches = recipe.quotes.filter{$0.servings == servings && $0.units == units}
                guard matches.count == 1, let quote = matches.first,
                      quote.recipeId == recipe.id, quote.recipeVersion == recipe.version,
                      quote.ingredients.count == ingredients.count,
                      Set(quote.ingredients.map(\.id)).count == ingredients.count,
                      quote.ingredients.allSatisfy({ item in
                          !item.id.isEmpty && !item.ingredientId.isEmpty && ingredients[item.id] == item.ingredientId &&
                          !item.name.isEmpty && !item.display.isEmpty && item.quantity.isFinite && item.quantity >= 0
                      }) else {
                    throw APIError(message:"Ingredient quantities are incomplete. Your downloaded recipes are preserved.")
                }
            } }
        }
        return self
    }
}
struct Recipe: Codable, Identifiable {
    var id: String; var version: Int; var name: String; var chineseName: String
    var minutes: Int; var difficulty: String; var vegetarian: Bool; var category: String; var demo: Bool
    var imageKey: String; var bundledImage: String; var allergens: [String]; var baseServings: Int
    var ingredients: [RecipeIngredient]; var equipment: [Equipment]; var steps: [CookingStep]; var quotes: [QuantityQuote]
    var allergyAlerts: [String]?
    func quote(_ servings: Int, _ units: String) -> QuantityQuote? { quotes.first { $0.servings == servings && $0.units == units } }
}
struct RecipeIngredient: Codable, Identifiable { var id: String; var ingredientId: String; var name: String }
struct Equipment: Codable, Identifiable { var id: String; var name: String }
struct CookingStep: Codable, Identifiable { var id: String; var title: String; var instruction: String; var tip: String; var durationSeconds: Int }
struct QuantityQuote: Codable { var recipeId: String; var recipeVersion: Int; var servings: Int; var units: String; var ingredients: [QuantityItem] }
struct QuantityItem: Codable, Identifiable { var id: String; var ingredientId: String; var name: String; var quantity: Double; var unit: String; var display: String }

// Wire data has one validated shape per kind. Optional fields allow old files and
// tombstones to survive migration without throwing away unknown user content.
struct Fields: Codable {
    var name: String?; var qty: String?; var group: String?; var storage: String?; var type: String?
    var added: String?; var until: String?; var ingredientId: String?; var checked: Bool?
    var recipeId: String?; var recipeVersion: Int?; var rating: Int?; var note: String?; var completedAt: String?
    var recipeSnapshot: Recipe?; var units: String?; var region: String?; var largeText: Bool?; var allergens: [String]?
    var servings: Int?; var ingredientIds: [String]?
}
struct Entity: Codable, Identifiable {
    var kind: String; var id: String; var data: Fields; var revision: Int64 = 0; var deleted: Bool = false
    var key: String { kind + ":" + id }
}
struct Edit: Codable, Identifiable {
    var id = UUID().uuidString; var kind: String; var entityId: String; var action = "put"
    var baseRevision: Int64 = 0; var data: Fields; var dependsOn: String?
}
struct Receipt: Codable { var id: String; var status: String; var message: String?; var entities: [Entity]; var duplicate: Bool? }
struct SyncResponse: Codable { var cursor: Int64; var entities: [Entity]; var receipts: [Receipt] }
struct SyncRequest: Encodable { var cursor: Int64; var operations: [Edit]; var timezone = TimeZone.current.identifier }
extension SyncRequest {
    static func bounded(cursor:Int64,operations:[Edit],maximumBytes:Int=450_000)throws ->(request:SyncRequest,blocked:Edit?) {
        var result=SyncRequest(cursor:cursor,operations:[])
        for original in operations.prefix(100) {
            var wire=original;wire.data.recipeSnapshot=nil
            var candidate=result;candidate.operations.append(wire)
            if try JSONEncoder().encode(candidate).count>maximumBytes {return(result,result.operations.isEmpty ? original:nil)}
            result=candidate
        }
        return(result,nil)
    }
}
struct Conflict: Codable, Identifiable { var id: String { edit.id }; var edit: Edit; var receipt: Receipt }
struct CookSession: Codable, Identifiable {
    var id = UUID().uuidString; var recipe: Recipe; var servings: Int; var units: String
    var phase = "prep"; var checked: Set<String> = []; var step = 0
    var remaining = 0; var deadline: Date?; var initialized = false
    var rating = 0; var note = ""; var historySaved = false
    func seconds(at now: Date = Date()) -> Int { deadline.map { max(0, Int(ceil($0.timeIntervalSince(now)))) } ?? remaining }
}
struct DiskState: Codable {
    var version = 2; var entities: [Entity] = []; var outbox: [Edit] = []; var conflicts: [Conflict] = []
    var cursor: Int64 = 0; var session: CookSession?; var legacySHA256: String?
    var deviceImportDecision: String?
}
struct AuthSession: Codable {
    var access_token: String; var refresh_token: String; var expires_in: Int; var user: AuthUser
    var savedAt: Date?; var expiry: Date { (savedAt ?? .distantPast).addingTimeInterval(Double(expires_in)) }
}
struct AuthUser: Codable { var id: String; var email: String? }
struct EmailLinkAttempt: Codable, Equatable {
    var id: UUID; var email: String; var verifier: String; var createdAt: Date
    static func make(email: String) throws -> Self {
        let value=email.trimmingCharacters(in:.whitespacesAndNewlines)
        guard value.count<=254,value.range(of:"^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$",options:.regularExpression) != nil else {throw APIError(message:"Enter a valid email address")}
        var bytes=[UInt8](repeating:0,count:32)
        guard SecRandomCopyBytes(kSecRandomDefault,bytes.count,&bytes)==errSecSuccess else {throw APIError(message:"Unable to prepare a secure sign-in link")}
        return Self(id:UUID(),email:value,verifier:base64URL(Data(bytes)),createdAt:Date())
    }
    var challenge: String {Self.base64URL(Data(SHA256.hash(data:Data(verifier.utf8))))}
    func isExpired(at now:Date)->Bool {now.timeIntervalSince(createdAt)>=3600 || createdAt.timeIntervalSince(now)>60}
    private static func base64URL(_ data:Data)->String {data.base64EncodedString().replacingOccurrences(of:"+",with:"-").replacingOccurrences(of:"/",with:"_").replacingOccurrences(of:"=",with:"")}
}
enum EmailLinkCallback {
    static func code(from url:URL) throws -> String {
        guard let c=URLComponents(url:url,resolvingAgainstBaseURL:false),c.scheme=="cnrecipe",c.host=="auth",c.path=="/callback",c.user==nil,c.password==nil,c.port==nil,c.fragment==nil else {throw APIError(message:"This is not a PotSteam sign-in link")}
        let items=c.queryItems ?? []
        guard Set(items.map(\.name)).count==items.count else {throw APIError(message:"The sign-in link has repeated parameters")}
        if items.contains(where:{$0.name=="error" || $0.name=="error_description" || $0.name=="error_code"}) {
            guard items.allSatisfy({["error","error_description","error_code"].contains($0.name)}) else {throw APIError(message:"The sign-in link is invalid")}
            let description=items.first(where:{$0.name=="error_description"})?.value
            throw APIError(message:description.map{String($0.replacingOccurrences(of:"+",with:" ").prefix(500))} ?? "The sign-in link is invalid or has expired. Request a new link.")
        }
        guard items.count==1,items[0].name=="code",let code=items[0].value,!code.isEmpty,code.count<=1024,code.range(of:"^[A-Za-z0-9._-]+$",options:.regularExpression) != nil else {throw APIError(message:"The sign-in link does not contain a valid code")}
        return code
    }
}
enum Dates {
    static var today: String { format(Date()) }
    static func format(_ date: Date) -> String { let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f.string(from: date) }
    static func parse(_ value: String?) -> Date? { guard let value, !value.isEmpty else { return nil }; let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian); f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; f.isLenient = false; return f.date(from: value) }
    static func days(_ value: String?) -> Int? { guard let date = parse(value) else { return nil }; return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: date).day }
    static func proportion(_ fields: Fields) -> Double? { guard let until = parse(fields.until), let added = parse(fields.added), let days = days(fields.until) else { return nil }; let span = max(1, Calendar.current.dateComponents([.day], from: added, to: until).day ?? 1); return min(1,max(0,Double(days)/Double(span))) }
}
