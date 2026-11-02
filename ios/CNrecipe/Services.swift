import Foundation
import Security
import UserNotifications
import Network
import ImageIO

enum AppConfig {
    // Optional account sync stays closed until the documented release gates pass.
    static let accountSyncEnabled = false
    static let projectURL = URL(string: "https://mlrerdrnwuudjsnjodkp.supabase.co")!
    static let publicKey = "sb_publishable_1D2inAHi-4ugJDH8fypl3g_uPo12aIJ"
    static let apiURL = projectURL.appendingPathComponent("functions/v1/cnrecipe")
    static let emailLinkCallbackURL = URL(string:"cnrecipe://auth/callback")!
}
struct APIError: LocalizedError { var message: String; var errorDescription: String? { message } }
enum HTTPTransport {
    static let session:URLSession = {
        let config=URLSessionConfiguration.ephemeral;config.timeoutIntervalForRequest=20;config.timeoutIntervalForResource=30
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.environment["SIMULATOR_UDID"]=="734C746B-F86E-436C-97B3-ABB2F39E06DD" && ProcessInfo.processInfo.environment["CNRECIPE_QA_OFFLINE"]=="1" {
            var proxy=ProxyConfiguration(httpCONNECTProxy:.hostPort(host:"127.0.0.1",port:9));proxy.allowFailover=false;config.proxyConfigurations=[proxy]
        }
        #endif
        return URLSession(configuration:config)
    }()
}
actor RecipeImages {
    static let shared=RecipeImages()
    private let session:URLSession
    private let folder:URL
    init(session:URLSession = HTTPTransport.session,folder:URL? = nil) {
        self.session=session
        self.folder=folder ?? FileManager.default.urls(for:.cachesDirectory,in:.userDomainMask)[0].appendingPathComponent("CNrecipePhotos")
    }
    private func validJPEG(_ data:Data)->Bool {
        guard !data.isEmpty,data.count<=5_000_000,
              let source=CGImageSourceCreateWithData(data as CFData,nil),
              CGImageSourceGetType(source) as String? == "public.jpeg",
              CGImageSourceGetStatus(source) == .statusComplete,
              let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{return false}
        return image.width>0 && image.height>0
    }
    func image(_ key:String) async -> Data? {
        guard key.range(of:"^recipes/[a-z0-9-]+/v[1-9][0-9]*\\.jpg$",options:.regularExpression) != nil else{return nil}
        let file=folder.appendingPathComponent(key.replacingOccurrences(of:"/",with:"_"))
        if let data=try? Data(contentsOf:file),validJPEG(data){return data}
        do {
            var request=URLRequest(url:AppConfig.projectURL.appendingPathComponent("storage/v1/object/public/recipe-images/"+key));request.timeoutInterval=15
            let(data,response)=try await session.data(for:request)
            guard let http=response as? HTTPURLResponse,http.statusCode==200,
                  http.value(forHTTPHeaderField:"Content-Type")?.split(separator:";").first?.trimmingCharacters(in:.whitespacesAndNewlines).lowercased()=="image/jpeg",
                  validJPEG(data) else{return nil}
            try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try data.write(to:file,options:.atomic);return data
        }catch{return nil}
    }
}
final class API {
    private let session: URLSession
    init(session:URLSession = HTTPTransport.session) {self.session=session}
    func call<T: Decodable>(_ path: String, body: Data? = nil, token: String? = nil, auth: Bool = false) async throws -> T {
        let base = auth ? AppConfig.projectURL.appendingPathComponent("auth/v1") : AppConfig.apiURL
        guard let url = URL(string: base.absoluteString + path) else { throw APIError(message: "Invalid API address") }
        var request = URLRequest(url: url); request.setValue(AppConfig.publicKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        if let body { request.httpMethod = "POST"; request.httpBody = body }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw APIError(message: "No server response") }
        guard (200..<300).contains(response.statusCode) else {
            let error = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            throw APIError(message: error?["error_description"] as? String ?? error?["msg"] as? String ?? error?["error"] as? String ?? "Request failed (\(response.statusCode))")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
    func requestCode(_ email: String) async throws { let _: [String: String?] = try await call("/otp", body: JSONSerialization.data(withJSONObject: ["email": email, "create_user": true]), auth: true) }
    func verify(_ email: String, _ code: String) async throws -> AuthSession { var result: AuthSession = try await call("/verify", body: JSONSerialization.data(withJSONObject: ["email":email,"token":code,"type":"email"]), auth:true); result.savedAt = Date(); return result }
    func requestEmailLink(_ attempt:EmailLinkAttempt) async throws {
        var components=URLComponents();components.queryItems=[URLQueryItem(name:"redirect_to",value:AppConfig.emailLinkCallbackURL.absoluteString)]
        let _: [String:String?] = try await call("/otp"+(components.string ?? ""),body:JSONSerialization.data(withJSONObject:["email":attempt.email,"create_user":true,"code_challenge":attempt.challenge,"code_challenge_method":"s256"]),auth:true)
    }
    func exchangeEmailLink(_ code:String,attempt:EmailLinkAttempt) async throws -> AuthSession {
        guard !attempt.isExpired(at:Date()) else {throw APIError(message:"This sign-in request has expired. Request a new link.")}
        var result:AuthSession = try await call("/token?grant_type=pkce",body:JSONSerialization.data(withJSONObject:["auth_code":code,"code_verifier":attempt.verifier]),auth:true)
        result.savedAt=Date();return result
    }
    func refresh(_ auth: AuthSession) async throws -> AuthSession { var result: AuthSession = try await call("/token?grant_type=refresh_token", body: JSONSerialization.data(withJSONObject: ["refresh_token":auth.refresh_token]), auth:true); result.savedAt = Date(); return result }
}
enum SessionVault {
    static let service = "com.cnrecipe.app.auth"
    static func read() throws -> AuthSession? {
        var value: CFTypeRef?; let status = SecItemCopyMatching([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"session",kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne] as CFDictionary,&value)
        if status == errSecItemNotFound { return nil }; guard status == errSecSuccess, let data = value as? Data else { throw APIError(message:"Unable to read secure sign-in storage") }; return try JSONDecoder().decode(AuthSession.self,from:data)
    }
    static func write(_ session: AuthSession?) throws {
        let query = [kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"session"] as CFDictionary
        guard let session else { let s=SecItemDelete(query); guard s == errSecSuccess || s == errSecItemNotFound else { throw APIError(message:"Unable to remove session") }; return }
        let data=try JSONEncoder().encode(session)
        let update=SecItemUpdate(query,[kSecValueData:data] as CFDictionary)
        if update == errSecItemNotFound { let s=SecItemAdd([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"session",kSecValueData:data,kSecAttrAccessible:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary,nil); guard s == errSecSuccess else { throw APIError(message:"Unable to save sign-in session") } }
        else if update != errSecSuccess { throw APIError(message:"Unable to update sign-in session") }
    }
    static func readEmailLinkAttempt() throws -> EmailLinkAttempt? {
        var value:CFTypeRef?
        let status=SecItemCopyMatching([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"email-link-attempt",kSecReturnData:true,kSecMatchLimit:kSecMatchLimitOne] as CFDictionary,&value)
        if status==errSecItemNotFound {return nil}
        guard status==errSecSuccess,let data=value as? Data else {throw APIError(message:"Unable to read pending sign-in storage")}
        return try JSONDecoder().decode(EmailLinkAttempt.self,from:data)
    }
    static func writeEmailLinkAttempt(_ attempt:EmailLinkAttempt?) throws {
        let query=[kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"email-link-attempt"] as CFDictionary
        guard let attempt else {let status=SecItemDelete(query);guard status==errSecSuccess || status==errSecItemNotFound else {throw APIError(message:"Unable to remove pending sign-in")};return}
        let data=try JSONEncoder().encode(attempt)
        let status=SecItemUpdate(query,[kSecValueData:data] as CFDictionary)
        if status==errSecItemNotFound {
            let added=SecItemAdd([kSecClass:kSecClassGenericPassword,kSecAttrService:service,kSecAttrAccount:"email-link-attempt",kSecValueData:data,kSecAttrAccessible:kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly] as CFDictionary,nil)
            guard added==errSecSuccess else {throw APIError(message:"Unable to save pending sign-in")}
        }else if status != errSecSuccess {throw APIError(message:"Unable to update pending sign-in")}
    }
}
@MainActor final class TimerNotifications {
    private var generation = UUID()
    private var pendingIdentifier:String?
    func cancel() {
        generation=UUID();let previous=pendingIdentifier;pendingIdentifier=nil
        let center=UNUserNotificationCenter.current();center.removePendingNotificationRequests(withIdentifiers:["cooking-timer"]+(previous.map{[$0]} ?? []))
        // Also remove timers left by a previous process. Recheck the current ID
        // after awaiting the daemon so a newer timer cannot be removed.
        Task{let pending=await center.pendingNotificationRequests();let stale=pending.map(\.identifier).filter{$0.hasPrefix("cooking-timer-") && $0 != pendingIdentifier};center.removePendingNotificationRequests(withIdentifiers:stale)}
    }
    func schedule(_ deadline: Date) async throws {
        cancel(); let current=generation;let identifier="cooking-timer-"+current.uuidString;pendingIdentifier=identifier; let center=UNUserNotificationCenter.current()
        let settings=await center.notificationSettings()
        let granted: Bool
        if settings.authorizationStatus == .notDetermined { granted=try await center.requestAuthorization(options:[.alert,.sound]) } else { granted=settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional }
        guard current == generation else { return }; guard granted else { throw APIError(message:"Notifications unavailable. The in-app timer still works.") }
        let interval=deadline.timeIntervalSinceNow; guard interval>0, interval<=86400 else { return }
        let content=UNMutableNotificationContent();content.title="PotSteam timer finished";content.body="Check your food before proceeding.";content.sound = .default
        try await center.add(UNNotificationRequest(identifier:identifier,content:content,trigger:UNTimeIntervalNotificationTrigger(timeInterval:interval,repeats:false)))
        if current != generation { center.removePendingNotificationRequests(withIdentifiers:[identifier]) }
    }
}
