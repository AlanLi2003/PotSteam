import XCTest
import CoreText
import UIKit
@testable import CNrecipe

@MainActor final class StateTests:XCTestCase {
    var folder:URL!
    override func setUp()async throws{folder=FileManager.default.temporaryDirectory.appendingPathComponent("cnrecipe-test-"+UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)}
    override func tearDown()async throws{try FileManager.default.removeItem(at:folder)}
    func store()->KitchenStore{KitchenStore(folder:folder,monitor:false,loadAuth:false)}
    func testClassic50ReleasedCatalogAndProjections()throws {
        let url=try XCTUnwrap(Bundle.main.url(forResource:"catalog",withExtension:"json",subdirectory:"Content"))
        let catalog=try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:url)).validated()
        XCTAssertEqual(catalog.recipes.count,50)
        XCTAssertEqual(catalog.recipes.reduce(0){$0+$1.quotes.count},800)
        for recipe in catalog.recipes {
            XCTAssertFalse(recipe.demo)
            XCTAssertNotNil(Bundle.main.path(forResource:recipe.bundledImage,ofType:nil,inDirectory:"Explore/assets"))
            for step in recipe.steps {XCTAssertNil(step.instruction.range(of:"\\p{Han}",options:.regularExpression))}
            for quote in recipe.quotes {for item in quote.ingredients {XCTAssertTrue(item.quantity.isFinite);XCTAssertFalse(item.display.isEmpty)}}
        }
    }
    func testOfflineQueueSurvivesColdLaunchAndCausalEdits(){let s=store();s.online=false;s.enqueue("shopping",id:"eggs",data:Fields(name:"Eggs",checked:false),action:"shopping.add");s.enqueue("shopping",id:"eggs",data:Fields(name:"Eggs",checked:true));XCTAssertEqual(s.disk.outbox[1].dependsOn,s.disk.outbox[0].id);let reopened=store();XCTAssertEqual(reopened.disk.outbox.count,2);XCTAssertEqual(reopened.list("shopping").first?.data.checked,true)}
    func testCorruptionNeverOverwritesOriginal(){let file=folder.appendingPathComponent("state-v2-device.json"),bytes=Data("broken-json".utf8);try! bytes.write(to:file);let s=store();s.enqueue("inventory",id:"test",data:Fields(name:"Mushrooms"));XCTAssertEqual(try! Data(contentsOf:file),bytes);XCTAssertTrue(s.disk.outbox.isEmpty);XCTAssertTrue(s.message.contains("could not be saved"))}
    func testLegacyMigrationPreservesFileAndCreatesImmutableBackup()throws{
        let old:[String:Any] = ["version":1,"pantry":[["id":7,"name":"番茄","emoji":"🍅","group":"Produce","qty":"2","storage":"Fridge","type":"Best before","added":"2026-01-01","until":""]],"shopping":[["Soy sauce",false]],"saved":["tomato"],"history":["tomato"],"records":[],"units":"Metric","allergens":["Eggs"]]
        let bytes=try JSONSerialization.data(withJSONObject:old);let file=folder.appendingPathComponent("state.json");try bytes.write(to:file);let s=store();XCTAssertEqual(s.list("inventory").first?.data.name,"番茄");XCTAssertEqual(s.list("favorite").first?.data.recipeId,"tomato");XCTAssertEqual(s.list("record").count,1);XCTAssertEqual(s.preferences.units,"Metric");XCTAssertEqual(try Data(contentsOf:file),bytes);XCTAssertEqual(try Data(contentsOf:folder.appendingPathComponent("legacy-v1-\(s.disk.legacySHA256!).json")),bytes);XCTAssertEqual(store().list("inventory").count,1)
    }
    func testCookingSnapshotDoesNotFollowCatalogUpdates(){let s=store();s.selected=s.catalog[0];s.servings=4;s.beginPrep();let original=s.disk.session!.recipe.steps[0].instruction;s.selected=s.catalog[1];XCTAssertEqual(s.disk.session?.recipe.id,"tomato");XCTAssertEqual(s.disk.session?.recipe.steps[0].instruction,original);XCTAssertEqual(store().disk.session?.servings,4)}
    func testPausedTimerPersistsAndBackResets(){let s=store();s.selected=s.catalog[0];s.beginPrep();s.updateSession{$0.phase="cook";$0.step=2;$0.initialized=true;$0.deadline=Date().addingTimeInterval(80)};s.route="cook";s.pauseTimer();XCTAssertNil(store().disk.session?.deadline);XCTAssertGreaterThan(store().disk.session!.remaining,75);s.nextStep(-1);XCTAssertEqual(s.disk.session?.step,1);XCTAssertEqual(s.disk.session?.remaining,0);XCTAssertFalse(s.disk.session!.initialized)}
    func testExpiredTimerAdvancesOnceAndManualActionInvalidatesCallback()async throws{
        let s=store();s.selected=s.catalog[0];s.beginPrep();s.route="cook";s.updateSession{$0.phase="cook";$0.step=1;$0.initialized=true;$0.deadline=Date().addingTimeInterval(-1)};s.tick();s.nextStep(1);try await Task.sleep(for:.milliseconds(1600));XCTAssertEqual(s.disk.session?.step,2)
        s.updateSession{$0.step=1;$0.deadline=Date().addingTimeInterval(-1)};s.tick();try await Task.sleep(for:.milliseconds(1600));XCTAssertEqual(s.disk.session?.step,2);s.tick();try await Task.sleep(for:.milliseconds(1500));XCTAssertEqual(s.disk.session?.step,2)
    }
    func testOpeningDrawerCancelsExpiryCallback()async throws{let s=store();s.selected=s.catalog[0];s.beginPrep();s.route="cook";s.updateSession{$0.phase="cook";$0.step=1;$0.initialized=true;$0.deadline=Date().addingTimeInterval(-1)};s.tick();s.pauseTimer();s.drawer=true;try await Task.sleep(for:.milliseconds(1600));XCTAssertEqual(s.disk.session?.step,1);XCTAssertNil(s.disk.session?.deadline)}
    func testCompletionOnlySavesExplicitlyAndOnce(){let s=store();s.selected=s.catalog[0];s.beginPrep();s.updateSession{$0.phase="complete";$0.rating=5;$0.note="保留原文"};XCTAssertTrue(store().list("record").isEmpty);s.saveHistory();s.saveHistory();let records=store().list("record");XCTAssertEqual(records.count,1);XCTAssertEqual(records[0].data.note,"保留原文");XCTAssertEqual(records[0].data.recipeSnapshot?.version,s.catalog[0].version)}
    func testDateProportionAndUndatedAreDistinct(){XCTAssertNil(Dates.proportion(Fields(added:Dates.today,until:"")));let yesterday=Dates.format(Calendar.current.date(byAdding:.day,value:-1,to:Date())!);XCTAssertEqual(Dates.proportion(Fields(added:yesterday,until:Dates.today)),0);XCTAssertEqual(Dates.days(Dates.today),0)}
    func testServerAllergenAnnotationsSurviveNativeBridgeCoding()throws{var recipe=store().catalog[0];recipe.allergyAlerts=["Eggs"];let wire=try JSONEncoder().encode(recipe);let json=try JSONSerialization.jsonObject(with:wire) as! [String:Any];XCTAssertEqual(json["allergyAlerts"] as? [String],["Eggs"]);XCTAssertEqual(try JSONDecoder().decode(Recipe.self,from:wire).allergyAlerts,["Eggs"])}
    func testRefreshedRecipeCacheDoesNotChangeCookingSnapshotOrLeakPersonalAnnotations()throws{let s=store();let originalVersion=s.catalog[0].version;s.selected=s.catalog[0];s.beginPrep();var updated=s.catalog[0];updated.version=originalVersion+1;for i in updated.quotes.indices{updated.quotes[i].recipeVersion=updated.version};updated.name="Updated recipe";updated.allergyAlerts=["Eggs"];try s.cacheRecipes(Catalog(schemaVersion:1,recipes:[updated],catalogVersion:"new-version"),replace:false);XCTAssertEqual(s.catalog[0].version,updated.version);XCTAssertNil(s.catalog[0].allergyAlerts);XCTAssertEqual(s.disk.session?.recipe.version,originalVersion);let reopened=store();XCTAssertEqual(reopened.catalog[0].version,updated.version);XCTAssertNil(reopened.catalog[0].allergyAlerts);XCTAssertEqual(reopened.disk.session?.recipe.version,originalVersion)}
    func testValidJSONWithDuplicateEntitiesIsProtected()throws{let e=Entity(kind:"inventory",id:"duplicate",data:Fields(name:"Mushroom"));var bad=DiskState();bad.entities=[e,e];let bytes=try JSONEncoder().encode(bad),file=folder.appendingPathComponent("state-v2-device.json");try bytes.write(to:file);let s=store();XCTAssertTrue(s.storageNeedsRecovery);s.enqueue("inventory",id:"new",data:Fields(name:"Rice"));XCTAssertEqual(try Data(contentsOf:file),bytes)}
    func testResetBacksUpBeforeReplacingDeviceData()throws{let s=store();s.enqueue("shopping",id:"rice",data:Fields(name:"Rice",checked:true));let file=folder.appendingPathComponent("state-v2-device.json"),bytes=try Data(contentsOf:file);s.resetDeviceData();XCTAssertTrue(store().visible.isEmpty);let backups=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("reset-backup-")};XCTAssertEqual(backups.count,1);XCTAssertEqual(try Data(contentsOf:backups[0].appendingPathComponent("state-v2-device.json")),bytes)}
    func testNetworkBatchPreservesLocalSnapshotsAndRespectsByteLimit()throws{
        let s=store(),recipe=s.catalog[0];let edit=Edit(kind:"record",entityId:"history",data:Fields(recipeId:recipe.id,recipeVersion:recipe.version,rating:5,note:String(repeating:"内容",count:1000),completedAt:"2026-10-31T00:00:00Z",recipeSnapshot:recipe))
        let result=try SyncRequest.bounded(cursor:0,operations:Array(repeating:edit,count:100));XCTAssertLessThanOrEqual(try JSONEncoder().encode(result.request).count,450000);XCTAssertLessThan(result.request.operations.count,100);XCTAssertNil(result.request.operations[0].data.recipeSnapshot);XCTAssertNotNil(edit.data.recipeSnapshot)
        var giant=edit;giant.data.note=String(repeating:"长",count:200000);let blocked=try SyncRequest.bounded(cursor:0,operations:[giant]);XCTAssertEqual(blocked.blocked?.id,giant.id);XCTAssertTrue(blocked.request.operations.isEmpty)
    }
    func testTransientNoticesExpireWithoutClearingNewerErrors()async throws {
        let s=store();s.showNotice("First success")
        try await Task.sleep(for:.milliseconds(1200));s.showNotice("New success")
        try await Task.sleep(for:.milliseconds(2000));XCTAssertEqual(s.message,"New success")
        s.message="Changes could not be saved. Please retry."
        try await Task.sleep(for:.milliseconds(1300));XCTAssertEqual(s.message,"Changes could not be saved. Please retry.")
        s.showNotice("Short success");try await Task.sleep(for:.milliseconds(3200));XCTAssertTrue(s.message.isEmpty)
    }
    func testNavigationClearsOnlySuccessNoticesAndFailedShoppingDoesNotSucceed()throws {
        let s=store();s.showNotice("Saved");s.route="detail";XCTAssertTrue(s.message.isEmpty)
        s.showNotice("Added");s.tab="Saved";XCTAssertTrue(s.message.isEmpty)
        s.message="Storage needs recovery";s.route="settings";s.tab="My Kitchen";XCTAssertEqual(s.message,"Storage needs recovery")
        let bytes=Data("broken-json".utf8),file=folder.appendingPathComponent("state-v2-device.json");try bytes.write(to:file)
        let blocked=store();XCTAssertFalse(blocked.addRecipeShopping(blocked.catalog[0]));XCTAssertTrue(blocked.message.contains("could not be saved"));XCTAssertEqual(try Data(contentsOf:file),bytes)
    }
    func testStartingAndResumingTimerNeverAddsOneSecondFromStaleClock()throws {
        let s=store();s.selected=try XCTUnwrap(s.catalog.first);s.beginPrep();s.route="cook"
        s.updateSession{$0.phase="cook";$0.step=1}
        let duration=try XCTUnwrap(s.disk.session).recipe.steps[1].durationSeconds
        s.clock=Date().addingTimeInterval(-0.9);s.toggleTimer()
        XCTAssertEqual(s.disk.session?.seconds(at:s.clock),duration)
        s.pauseTimer();s.updateSession{$0.remaining=3;$0.initialized=true};s.clock=Date().addingTimeInterval(-0.9);s.toggleTimer()
        XCTAssertEqual(s.disk.session?.seconds(at:s.clock),3);s.pauseTimer()
    }
    func testTimerNumeralsKeepBaselineHeightAndWidth() {
        let font=TimerRing.digitFont
        var widths:[Double]=[];var tops:[CGFloat]=[]
        for digit in "0123456789" {
            let line=CTLineCreateWithAttributedString(NSAttributedString(string:String(digit),attributes:[.font:font]))
            let bounds=CTLineGetBoundsWithOptions(line,.useGlyphPathBounds)
            XCTAssertGreaterThan(bounds.minY,-2,"Digit \(digit) must not have an old-style descender")
            tops.append(bounds.maxY);widths.append(CTLineGetTypographicBounds(line,nil,nil,nil))
        }
        XCTAssertLessThan((widths.max() ?? 0)-(widths.min() ?? 0),0.1,"Countdown digits must have equal advance widths")
        XCTAssertLessThan((tops.max() ?? 0)-(tops.min() ?? 0),2,"Countdown digits must have consistent cap height")
    }
    func testIngredientIconsCoverEveryCatalogIngredientAndBundledAsset()throws {
        let ingredients=store().catalog.flatMap(\.ingredients)
        for item in ingredients {
            let assets=FoodIcon.assets(name:item.name,ingredientId:item.ingredientId)
            XCTAssertNotEqual(assets,["ingredient"],item.name)
            XCTAssertEqual(assets,FoodIcon.assets(name:item.name),item.name)
            for asset in assets {let image=try XCTUnwrap(FoodIcon.image(asset),"Missing or invalid bundled icon: \(asset)");XCTAssertGreaterThan(image.size.width,0);XCTAssertNotNil(image.cgImage)}
        }
        for asset in ["ingredient","pepper","pan","utensils"]{XCTAssertNotNil(FoodIcon.image(asset),asset)}
    }
    func testReleasedFoodImagesDecodeAndUseVersionedAssets()throws {
        let recipes=store().catalog
        XCTAssertEqual(recipes.count,50)
        for recipe in recipes {
            XCTAssertTrue(recipe.bundledImage.contains("-photo-v"),recipe.name)
            let path=try XCTUnwrap(Bundle.main.path(forResource:recipe.bundledImage,ofType:nil,inDirectory:"Explore/assets"),recipe.name)
            let image=try XCTUnwrap(UIImage(contentsOfFile:path),recipe.name)
            XCTAssertGreaterThan(image.size.width,500,recipe.name)
            XCTAssertGreaterThan(image.size.height,500,recipe.name)
            XCTAssertNotNil(image.cgImage,recipe.name)
        }
    }
    func testEquipmentIconsCoverEveryReleasedEquipment()throws {
        let catalog=store().catalog
        for recipe in catalog {for equipment in recipe.equipment {
            let assets=FoodIcon.assets(name:equipment.name,equipmentId:equipment.id)
            XCTAssertNotEqual(assets,["ingredient"],equipment.name)
            XCTAssertEqual(assets,FoodIcon.assets(name:equipment.name),equipment.name)
            XCTAssertEqual(assets,FoodIcon.assets(name:"Localized equipment",equipmentId:equipment.id))
            for asset in assets {let image=try XCTUnwrap(FoodIcon.image(asset),equipment.name);XCTAssertNotNil(image.cgImage)}
        }}
        XCTAssertEqual(FoodIcon.assets(name:"香菇"),["mushroom"])
        XCTAssertEqual(FoodIcon.assets(name:"牛肉"),["beef"])
        XCTAssertEqual(FoodIcon.assets(name:"food thermometer"),["equipment-thermometer"])
    }
    func testIngredientIconAliasesAndUnknownNames() {
        for name in ["egg","Eggs","  EGG \n","鸡蛋","雞蛋"]{XCTAssertEqual(FoodIcon.assets(name:name),["egg"])}
        for name in ["Bok choy","bok-choy","  BOK   CHOY ","上海青"]{XCTAssertEqual(FoodIcon.assets(name:name),["bok-choy"])}
        for name in ["Garlic","蒜瓣","大蒜"]{XCTAssertEqual(FoodIcon.assets(name:name),["garlic"])}
        for name in ["eggplant stew","garlic bread","Custom item","香菇酱",""]{XCTAssertEqual(FoodIcon.assets(name:name),["ingredient"],"Unknown names must not be guessed from a substring")}
        XCTAssertEqual(FoodIcon.assets(name:"eggplant"),["eggplant"])
        XCTAssertEqual(FoodIcon.assets(name:"Localized name",ingredientId:"eggs"),["egg"])
        XCTAssertEqual(FoodIcon.assets(name:"egg",ingredientId:"future-id"),["egg"])
        XCTAssertEqual(FoodIcon.assets(name:"Cooking pan and utensils"),["pan","utensils"])
    }
    func testManualItemIconsResolveAfterColdLaunchAndRename()throws {
        let s=store();s.addShopping(name:"egg");s.enqueue("inventory",id:"manual-icon",data:Fields(name:"Garlic",group:"Produce"))
        let reopened=store();let shopping=try XCTUnwrap(reopened.list("shopping").first);XCTAssertNil(shopping.data.ingredientId);XCTAssertEqual(FoodIcon.assets(name:shopping.data.name ?? "",ingredientId:shopping.data.ingredientId),["egg"])
        var data=try XCTUnwrap(reopened.list("inventory").first).data;data.name="Bok choy";reopened.enqueue("inventory",id:"manual-icon",data:data)
        let edited=try XCTUnwrap(store().list("inventory").first);XCTAssertEqual(FoodIcon.assets(name:edited.data.name ?? "",ingredientId:edited.data.ingredientId),["bok-choy"])
    }
    func testCompletedNotePersistsWithoutImplicitlySavingHistory()throws {
        let s=store();s.selected=s.catalog[0];s.beginPrep();s.updateSession{$0.phase="complete"};s.route="complete"
        XCTAssertTrue(s.updateSession{$0.note="good 中文备注"});s.updateSession{$0.rating=4}
        let reopened=store();XCTAssertEqual(reopened.disk.session?.note,"good 中文备注");XCTAssertEqual(reopened.disk.session?.rating,4);XCTAssertTrue(reopened.list("record").isEmpty)
        reopened.saveHistory();XCTAssertEqual(store().list("record").first?.data.note,"good 中文备注")
    }
    func testIdleEditorDoesNotReceiveTimerClockUpdates() {
        let s=store();s.clock=Date().addingTimeInterval(-2);let before=s.clock;s.route="complete";s.tick();XCTAssertEqual(s.clock,before)
        s.route="cook";s.clock=before;s.tick();XCTAssertGreaterThan(s.clock,before)
    }
    func testSecureSessionAndAccountQueuesStaySeparate()throws{
        let previous=try SessionVault.read(),pending=try SessionVault.readEmailLinkAttempt()
        addTeardownBlock{try SessionVault.write(previous);try SessionVault.writeEmailLinkAttempt(pending)}
        let s=KitchenStore(folder:folder,monitor:false,loadAuth:false,accountSyncEnabled:true);s.enqueue("inventory",id:"device-item",data:Fields(name:"Device only"));let a=AuthSession(access_token:"unit-test-a",refresh_token:"unit-test-refresh-a",expires_in:3600,user:AuthUser(id:"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa",email:"a@example.invalid"),savedAt:Date());let b=AuthSession(access_token:"unit-test-b",refresh_token:"unit-test-refresh-b",expires_in:3600,user:AuthUser(id:"bbbbbbbb-bbbb-4bbb-bbbb-bbbbbbbbbbbb",email:"b@example.invalid"),savedAt:Date())
        try s.signedIn(a);XCTAssertTrue(s.list("inventory").isEmpty);XCTAssertTrue(s.importAvailable);s.importDeviceData();s.enqueue("inventory",id:"account-a",data:Fields(name:"Alice only"));XCTAssertEqual(try SessionVault.read()?.user.id,a.user.id)
        try s.signedIn(b);XCTAssertTrue(s.list("inventory").isEmpty);XCTAssertTrue(s.disk.outbox.isEmpty);XCTAssertEqual(try SessionVault.read()?.user.id,b.user.id)
        try s.signedIn(a);XCTAssertTrue(s.list("inventory").contains{$0.data.name=="Alice only"});XCTAssertTrue(s.list("inventory").contains{$0.data.name=="Device only"});try s.signOut();XCTAssertEqual(s.list("inventory").count,1);XCTAssertNil(try SessionVault.read())
    }
}

private final class EmailLinkURLProtocol:URLProtocol {
    static var handler:((URLRequest)throws->(Int,Data))?
    override class func canInit(with request:URLRequest)->Bool {true}
    override class func canonicalRequest(for request:URLRequest)->URLRequest {request}
    override func startLoading() {
        do {
            guard let handler=Self.handler else {throw URLError(.badServerResponse)}
            let(status,data)=try handler(request)
            client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":"application/json"])!,cacheStoragePolicy:.notAllowed)
            client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)
        }catch {client?.urlProtocol(self,didFailWithError:error)}
    }
    override func stopLoading() {}
}
final class EmailLinkServiceTests:XCTestCase {
    private func api()->API {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[EmailLinkURLProtocol.self]
        return API(session:URLSession(configuration:config))
    }
    private func body(_ request:URLRequest)throws->[String:Any] {
        var data=request.httpBody ?? Data()
        if data.isEmpty,let stream=request.httpBodyStream {
            stream.open();defer{stream.close()};var bytes=[UInt8](repeating:0,count:1024)
            while stream.hasBytesAvailable {let count=stream.read(&bytes,maxLength:bytes.count);guard count>=0 else {throw URLError(.cannotDecodeRawData)};if count==0{break};data.append(contentsOf:bytes.prefix(count))}
        }
        return try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
    }
    override func tearDown() {EmailLinkURLProtocol.handler=nil;super.tearDown()}
    func testPKCEChallengeUsesRFC7636VectorAndRandomVerifier()throws {
        let vector=EmailLinkAttempt(id:UUID(),email:"qa@example.invalid",verifier:"dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk",createdAt:Date())
        XCTAssertEqual(vector.challenge,"E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
        let a=try EmailLinkAttempt.make(email:"  qa@example.invalid \n"),b=try EmailLinkAttempt.make(email:"qa@example.invalid")
        XCTAssertEqual(a.email,"qa@example.invalid");XCTAssertEqual(a.verifier.count,43);XCTAssertNotEqual(a.verifier,b.verifier)
        XCTAssertNotNil(a.verifier.range(of:"^[A-Za-z0-9_-]{43}$",options:.regularExpression))
        XCTAssertFalse(a.isExpired(at:a.createdAt.addingTimeInterval(3599)));XCTAssertTrue(a.isExpired(at:a.createdAt.addingTimeInterval(3600)))
        XCTAssertThrowsError(try EmailLinkAttempt.make(email:"invalid"))
    }
    func testEmailLinkCallbackAcceptsOnlyExactCodeCallback()throws {
        XCTAssertEqual(try EmailLinkCallback.code(from:URL(string:"cnrecipe://auth/callback?code=abc-123")!),"abc-123")
        for value in ["https://auth/callback?code=a","cnrecipe://evil/callback?code=a","cnrecipe://auth/wrong?code=a","cnrecipe://user@auth/callback?code=a","cnrecipe://auth:80/callback?code=a","cnrecipe://auth/callback?code=a&code=b","cnrecipe://auth/callback?code=a&extra=b","cnrecipe://auth/callback?code=","cnrecipe://auth/callback?code=a#access_token=untrusted","cnrecipe://auth/callback#access_token=untrusted","cnrecipe://auth/callback?code=a&error=denied"] {
            XCTAssertThrowsError(try EmailLinkCallback.code(from:URL(string:value)!),value)
        }
        XCTAssertThrowsError(try EmailLinkCallback.code(from:URL(string:"cnrecipe://auth/callback?error=access_denied&error_description=Link%20expired")!)){XCTAssertEqual($0.localizedDescription,"Link expired")}
    }
    func testPendingEmailLinkKeychainIsSeparateFromSession()throws {
        let previous=try SessionVault.readEmailLinkAttempt(),session=try SessionVault.read()
        addTeardownBlock{try SessionVault.writeEmailLinkAttempt(previous)}
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        XCTAssertEqual(try SessionVault.readEmailLinkAttempt(),attempt)
        var next=attempt;next.id=UUID();try SessionVault.writeEmailLinkAttempt(next);XCTAssertEqual(try SessionVault.readEmailLinkAttempt(),next)
        try SessionVault.writeEmailLinkAttempt(nil);XCTAssertNil(try SessionVault.readEmailLinkAttempt())
        XCTAssertEqual(try SessionVault.read()?.access_token,session?.access_token)
    }
    func testEmailLinkRequestSendsPKCEAndExactRedirectWithoutVerifier()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid")
        EmailLinkURLProtocol.handler={request in
            XCTAssertEqual(request.url?.host,"mlrerdrnwuudjsnjodkp.supabase.co");XCTAssertEqual(request.url?.path,"/auth/v1/otp");XCTAssertEqual(request.httpMethod,"POST")
            XCTAssertEqual(URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems,[URLQueryItem(name:"redirect_to",value:"cnrecipe://auth/callback")])
            let data=try self.body(request);XCTAssertEqual(data["email"] as? String,attempt.email);XCTAssertEqual(data["create_user"] as? Bool,true);XCTAssertEqual(data["code_challenge"] as? String,attempt.challenge);XCTAssertEqual(data["code_challenge_method"] as? String,"s256");XCTAssertNil(data["code_verifier"])
            XCTAssertEqual(request.value(forHTTPHeaderField:"apikey"),AppConfig.publicKey);XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
            return(200,Data("{}".utf8))
        }
        try await api().requestEmailLink(attempt)
    }
    func testPKCEExchangeSendsVerifierAndDecodesSession()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid")
        EmailLinkURLProtocol.handler={request in
            XCTAssertEqual(request.url?.path,"/auth/v1/token");XCTAssertEqual(URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems,[URLQueryItem(name:"grant_type",value:"pkce")])
            let data=try self.body(request);XCTAssertEqual(data["auth_code"] as? String,"test-auth-code");XCTAssertEqual(data["code_verifier"] as? String,attempt.verifier)
            return(200,Data(#"{"access_token":"fixture-access","refresh_token":"fixture-refresh","expires_in":3600,"user":{"id":"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa","email":"qa@example.invalid"}}"#.utf8))
        }
        let session=try await api().exchangeEmailLink("test-auth-code",attempt:attempt)
        XCTAssertEqual(session.user.email,attempt.email);XCTAssertEqual(session.refresh_token,"fixture-refresh");XCTAssertNotNil(session.savedAt);XCTAssertGreaterThan(session.expiry.timeIntervalSinceNow,3590)
    }
    func testPKCEExchangeRejectsBadCodeAndPropagatesRateLimit()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid")
        for(status,message) in [(400,"Link is invalid or expired"),(429,"Email rate limit exceeded")] {
            EmailLinkURLProtocol.handler={_ in (status,try JSONSerialization.data(withJSONObject:["msg":message]))}
            do {_ = try await api().exchangeEmailLink("test-auth-code",attempt:attempt);XCTFail("Expected authentication rejection")}
            catch {XCTAssertEqual(error.localizedDescription,message)}
        }
        var expired=attempt;expired.createdAt=Date().addingTimeInterval(-3601)
        EmailLinkURLProtocol.handler={_ in XCTFail("Expired attempts must not make a request");return(500,Data())}
        do {_ = try await api().exchangeEmailLink("test-auth-code",attempt:expired);XCTFail("Expected expiry rejection")}
        catch {XCTAssertTrue(error.localizedDescription.contains("expired"))}
    }
}

@MainActor final class EmailLinkStoreTests:XCTestCase {
    private var folder:URL!
    private var previousSession:AuthSession?
    private var previousAttempt:EmailLinkAttempt?
    override func setUp()async throws {
        previousSession=try SessionVault.read();previousAttempt=try SessionVault.readEmailLinkAttempt()
        try SessionVault.write(nil);try SessionVault.writeEmailLinkAttempt(nil)
        folder=FileManager.default.temporaryDirectory.appendingPathComponent("cnrecipe-link-tests-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    }
    override func tearDown()async throws {
        EmailLinkURLProtocol.handler=nil
        try SessionVault.write(previousSession);try SessionVault.writeEmailLinkAttempt(previousAttempt)
        if let folder {try FileManager.default.removeItem(at:folder)}
    }
    private func store(loadAuth:Bool=true)->KitchenStore {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[EmailLinkURLProtocol.self]
        return KitchenStore(folder:folder,monitor:false,loadAuth:loadAuth,api:API(session:URLSession(configuration:config)),accountSyncEnabled:true)
    }
    private func sessionData(email:String="qa@example.invalid")->Data {
        Data("{\"access_token\":\"fixture-access\",\"refresh_token\":\"fixture-refresh\",\"expires_in\":3600,\"user\":{\"id\":\"aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa\",\"email\":\"\(email)\"}}".utf8)
    }
    func testPendingLinkRestoresOnlyWhenAuthLoadingIsEnabled()throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        XCTAssertNil(store(loadAuth:false).emailLinkAttempt);XCTAssertEqual(try SessionVault.readEmailLinkAttempt(),attempt)
        XCTAssertEqual(store().emailLinkAttempt,attempt)
        var expired=attempt;expired.createdAt=Date().addingTimeInterval(-3601);try SessionVault.writeEmailLinkAttempt(expired)
        XCTAssertNil(store().emailLinkAttempt);XCTAssertNil(try SessionVault.readEmailLinkAttempt())
    }
    func testMissingPendingAndForgedCallbackNeverExchange()async throws {
        EmailLinkURLProtocol.handler={_ in XCTFail("Unsolicited callbacks must not make an exchange request");return(500,Data())}
        let s=store();await s.completeEmailLink(URL(string:"cnrecipe://auth/callback?code=unsolicited")!);XCTAssertNil(s.auth)
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        let pending=store();await pending.completeEmailLink(URL(string:"cnrecipe://wrong/callback?code=forged")!)
        XCTAssertNil(pending.auth);XCTAssertEqual(pending.emailLinkAttempt,attempt);XCTAssertNil(try SessionVault.read())
    }
    func testCancelledExchangeCannotSignInAfterLateResponse()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        let s=store(),entered=expectation(description:"Exchange started"),gate=DispatchSemaphore(value:0),response=sessionData()
        EmailLinkURLProtocol.handler={_ in entered.fulfill();guard gate.wait(timeout:.now()+5) == .success else {throw URLError(.timedOut)};return(200,response)}
        let exchange=Task{await s.completeEmailLink(URL(string:"cnrecipe://auth/callback?code=delayed")!)}
        await fulfillment(of:[entered],timeout:3)
        try s.cancelEmailLink();gate.signal();await exchange.value
        XCTAssertNil(s.auth);XCTAssertNil(s.emailLinkAttempt);XCTAssertFalse(s.emailLinkBusy);XCTAssertNil(try SessionVault.read())
    }
    func testExchangeForDifferentEmailPreservesPendingAndDoesNotSignIn()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        let response=sessionData(email:"someone-else@example.invalid")
        EmailLinkURLProtocol.handler={_ in (200,response)}
        let s=store();await s.completeEmailLink(URL(string:"cnrecipe://auth/callback?code=wrong-account")!)
        XCTAssertNil(s.auth);XCTAssertEqual(s.emailLinkAttempt,attempt);XCTAssertTrue(s.emailLinkError.contains("does not match"));XCTAssertNil(try SessionVault.read())
    }
    func testSuccessfulExchangeStoresSessionClearsPendingAndRejectsReplay()async throws {
        let attempt=try EmailLinkAttempt.make(email:"qa@example.invalid");try SessionVault.writeEmailLinkAttempt(attempt)
        let response=sessionData();EmailLinkURLProtocol.handler={_ in (200,response)}
        let s=store(),url=URL(string:"cnrecipe://auth/callback?code=valid-code")!
        await s.completeEmailLink(url)
        XCTAssertEqual(s.auth?.user.email,attempt.email);XCTAssertEqual(try SessionVault.read()?.user.email,attempt.email);XCTAssertNil(s.emailLinkAttempt);XCTAssertNil(try SessionVault.readEmailLinkAttempt())
        EmailLinkURLProtocol.handler={_ in XCTFail("A consumed callback must not be exchanged again");return(500,Data())}
        await s.completeEmailLink(url);XCTAssertEqual(s.auth?.user.email,attempt.email)
    }
}


@MainActor final class LocalModeTests:XCTestCase {
    private var folder:URL!
    private var previousSession:AuthSession?
    private var previousAttempt:EmailLinkAttempt?
    private var sessions:[URLSession]=[]
    private var monitoredStores:[KitchenStore]=[]
    private let accountID="cccccccc-cccc-4ccc-cccc-cccccccccccc"
    override func setUp()async throws {
        previousSession=try SessionVault.read();previousAttempt=try SessionVault.readEmailLinkAttempt()
        try SessionVault.write(nil);try SessionVault.writeEmailLinkAttempt(nil)
        folder=FileManager.default.temporaryDirectory.appendingPathComponent("cnrecipe-local-tests-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
    }
    override func tearDown()async throws {
        for store in monitoredStores {await store.stopNetworkMonitoring()}
        monitoredStores=[]
        sessions.forEach{$0.invalidateAndCancel()};sessions=[]
        EmailLinkURLProtocol.handler=nil
        try SessionVault.write(previousSession);try SessionVault.writeEmailLinkAttempt(previousAttempt)
        if let folder {try FileManager.default.removeItem(at:folder)}
    }
    private func store(monitor:Bool=false)->KitchenStore {
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[EmailLinkURLProtocol.self]
        let session=URLSession(configuration:config);sessions.append(session)
        let result=KitchenStore(folder:folder,monitor:monitor,api:API(session:session))
        if monitor {monitoredStores.append(result)}
        return result
    }
    private func oldSession()->AuthSession {
        AuthSession(access_token:"preserved-account-access",refresh_token:"preserved-account-refresh",expires_in:3600,user:AuthUser(id:accountID,email:"old@example.invalid"),savedAt:Date())
    }
    func testDefaultLocalModeIgnoresOldAccountAndPreservesItsFilesAndKeychain()throws {
        let session=oldSession(),attempt=try EmailLinkAttempt.make(email:"pending@example.invalid")
        try SessionVault.write(session);try SessionVault.writeEmailLinkAttempt(attempt)
        var device=DiskState();device.entities=[Entity(kind:"inventory",id:"device-food",data:Fields(name:"Device tomatoes"))]
        var account=DiskState();account.entities=[Entity(kind:"shopping",id:"account-food",data:Fields(name:"Account rice"))]
        let deviceBytes=try JSONEncoder().encode(device),accountBytes=try JSONEncoder().encode(account)
        let deviceFile=folder.appendingPathComponent("state-v2-device.json"),accountFile=folder.appendingPathComponent("state-v2-"+accountID+".json")
        try deviceBytes.write(to:deviceFile);try accountBytes.write(to:accountFile)
        let s=store()
        XCTAssertFalse(AppConfig.accountSyncEnabled);XCTAssertFalse(s.accountSyncEnabled)
        XCTAssertNil(s.auth);XCTAssertNil(s.emailLinkAttempt);XCTAssertFalse(s.importAvailable)
        XCTAssertEqual(s.list("inventory").map{$0.data.name},["Device tomatoes"]);XCTAssertTrue(s.list("shopping").isEmpty)
        XCTAssertEqual(s.syncStatus,"On this device")
        XCTAssertEqual(try Data(contentsOf:deviceFile),deviceBytes);XCTAssertEqual(try Data(contentsOf:accountFile),accountBytes)
        XCTAssertEqual(try SessionVault.read()?.access_token,session.access_token);XCTAssertEqual(try SessionVault.read()?.refresh_token,session.refresh_token)
        XCTAssertEqual(try SessionVault.readEmailLinkAttempt(),attempt)
    }
    func testDisabledAccountPathsCannotAuthenticateOrUploadAndLocalEditsReopen()async throws {
        let session=oldSession(),attempt=try EmailLinkAttempt.make(email:"pending@example.invalid")
        try SessionVault.write(session);try SessionVault.writeEmailLinkAttempt(attempt)
        let source=store(),catalogBytes=try JSONEncoder().encode(Catalog(schemaVersion:1,recipes:source.catalog,catalogVersion:"test-public"))
        EmailLinkURLProtocol.handler={request in
            XCTAssertEqual(request.url?.path,"/functions/v1/cnrecipe/v1/catalog","Only public recipe requests are allowed")
            XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"))
            return(200,catalogBytes)
        }
        let s=store(monitor:true)
        do {try await s.sendEmailLink(to:"qa@example.invalid");XCTFail("Hidden account sync must not send a login email")}
        catch {XCTAssertTrue(error.localizedDescription.contains("not available"))}
        await s.completeEmailLink(URL(string:"cnrecipe://auth/callback?code=previous-email-link")!)
        XCTAssertThrowsError(try s.signedIn(session));XCTAssertNil(s.auth)
        // Even a stale in-memory session must not bypass the feature gate.
        s.auth=session
        s.enqueue("inventory",id:"local-food",data:Fields(name:"Local mushrooms",qty:"2"))
        await s.sync()
        let count=s.disk.outbox.count;s.importDeviceData();XCTAssertEqual(s.disk.outbox.count,count)
        let reopened=store()
        XCTAssertNil(reopened.auth);XCTAssertEqual(reopened.list("inventory").first?.data.name,"Local mushrooms")
        XCTAssertEqual(reopened.disk.outbox.count,1)
        XCTAssertTrue(FileManager.default.fileExists(atPath:folder.appendingPathComponent("state-v2-device.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:folder.appendingPathComponent("state-v2-"+accountID+".json").path))
        XCTAssertEqual(try SessionVault.read()?.access_token,session.access_token);XCTAssertEqual(try SessionVault.readEmailLinkAttempt(),attempt)
    }
    func testLocalShoppingMergePreservesCheckedStateAndQuantityAcrossNamesAndIDs()throws {
        let s=store()
        s.addShopping(name:"Tomatoes",ingredientId:"tomato",qty:"2 medium")
        let item=try XCTUnwrap(s.list("shopping").first);var fields=item.data;fields.checked=true
        s.enqueue("shopping",id:item.id,data:fields)
        s.addShopping(name:"  TOMATOES  ",qty:"5 medium")
        s.addShopping(name:"Different display name",ingredientId:"tomato",qty:"8 medium")
        var rows=store().list("shopping")
        XCTAssertEqual(rows.count,1);XCTAssertEqual(rows[0].data.checked,true);XCTAssertEqual(rows[0].data.qty,"2 medium")
        s.remove(try XCTUnwrap(s.list("shopping").first));s.addShopping(name:"Tomatoes",ingredientId:"tomato",qty:"3 medium")
        rows=store().list("shopping");XCTAssertEqual(rows.count,1);XCTAssertEqual(rows[0].data.checked,false);XCTAssertEqual(rows[0].data.qty,"3 medium")
    }
    func testPublicRecipeQueryKeepsInventoryAndAlertsLocalAndOfflineFilteringMatches()async throws {
        let s=store(),base=try XCTUnwrap(s.catalog.first)
        var byName=base;byName.id="local-name-match";byName.ingredients=[RecipeIngredient(id:"name-row",ingredientId:"ingredient-private-tomato",name:"Hidden Tomato")];byName.allergens=["Eggs"];byName.allergyAlerts=["Peanuts"]
        var byID=base;byID.id="local-id-match";byID.ingredients=[RecipeIngredient(id:"id-row",ingredientId:"ingredient-private-tofu",name:"Different label")];byID.allergens=["Soy sauce"];byID.allergyAlerts=["Peanuts"]
        var partial=base;partial.id="partial-name-must-not-match";partial.ingredients=[RecipeIngredient(id:"partial-row",ingredientId:"unmatched",name:"Hidden Tomato sauce")]
        // Keep synthetic recipes consistent with the same public quantity contract.
        func project(_ recipe:Recipe)->Recipe {var r=recipe;r.quotes=base.quotes.map{q in var q=q;q.recipeId=r.id;q.ingredients=r.ingredients.map{i in QuantityItem(id:i.id,ingredientId:i.ingredientId,name:i.name,quantity:1,unit:"item",display:"1 item")};return q};return r}
        byName=project(byName);byID=project(byID);partial=project(partial)
        let response=Catalog(schemaVersion:1,recipes:[byName,byID,partial],catalogVersion:"local-personalization-fixture")
        let bytes=try JSONEncoder().encode(response)
        s.enqueue("inventory",id:"private-name",data:Fields(name:"  HIDDEN TOMATO  "))
        s.enqueue("inventory",id:"private-id",data:Fields(name:"My private protein",ingredientId:"ingredient-private-tofu"))
        s.savePreferences{$0.allergens=["Eggs","Soy"]}
        EmailLinkURLProtocol.handler={request in
            XCTAssertEqual(request.url?.path,"/functions/v1/cnrecipe/v1/catalog")
            let items=URLComponents(url:request.url!,resolvingAgainstBaseURL:false)?.queryItems ?? []
            XCTAssertEqual(Set(items.map(\.name)),Set(["q","filter"]))
            XCTAssertEqual(items.first{$0.name=="q"}?.value,"");XCTAssertEqual(items.first{$0.name=="filter"}?.value,"All")
            XCTAssertNil(request.value(forHTTPHeaderField:"Authorization"));XCTAssertEqual(request.httpMethod,"GET")
            return(200,bytes)
        }
        let result=try await s.query("",filter:"Pantry")
        XCTAssertEqual(result.recipes.map(\.id),[byName.id,byID.id])
        XCTAssertEqual(result.recipes[0].allergyAlerts,["Eggs"]);XCTAssertEqual(result.recipes[1].allergyAlerts,["Soy sauce"])
        let cached=try JSONDecoder().decode(Catalog.self,from:Data(contentsOf:folder.appendingPathComponent("catalog-v1.json")))
        XCTAssertEqual(cached.recipes.count,3);XCTAssertTrue(cached.recipes.allSatisfy{$0.allergyAlerts==nil})
        let reopened=store(),downloaded=reopened.downloadedCatalog(filter:"Pantry")
        XCTAssertEqual(downloaded.recipes.map(\.id),result.recipes.map(\.id))
        XCTAssertEqual(downloaded.recipes.map(\.allergyAlerts),result.recipes.map(\.allergyAlerts))
        XCTAssertEqual(reopened.downloadedCatalog(query:"Hidden Tomato",filter:"Pantry").recipes.map(\.id),[byName.id])
    }
}

@MainActor final class PrelaunchChecks:XCTestCase {
 var folder:URL!; var session:URLSession!
 override func setUp()async throws{folder=FileManager.default.temporaryDirectory.appendingPathComponent("prelaunch-"+UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[EmailLinkURLProtocol.self];session=URLSession(configuration:c)}
 override func tearDown()async throws{session.invalidateAndCancel();EmailLinkURLProtocol.handler=nil;try FileManager.default.removeItem(at:folder)}
 func store()->KitchenStore{KitchenStore(folder:folder,monitor:false,loadAuth:false,api:API(session:session))}
 func testINT005WriteFailureDoesNotAdvanceOrLoseData()throws{let s=store();s.addShopping(name:"Preserved");let f=folder.appendingPathComponent("state-v2-device.json"),saved=try Data(contentsOf:f);try FileManager.default.removeItem(at:f);try FileManager.default.createDirectory(at:f,withIntermediateDirectories:false);XCTAssertFalse(s.addShopping(name:"Must fail"));s.selected=s.catalog[0];s.beginPrep();XCTAssertNil(s.disk.session);XCTAssertNotEqual(s.route,"prep");XCTAssertEqual(s.list("shopping").count,1);try FileManager.default.removeItem(at:f);try saved.write(to:f);XCTAssertEqual(store().list("shopping").first?.data.name,"Preserved")}
 func testINT010APIErrorAndRecoveryPreserveCache()async throws{let s=store(),original=s.catalog;let response=try JSONEncoder().encode(Catalog(schemaVersion:1,recipes:original,catalogVersion:"good"));try s.cacheRecipes(Catalog(schemaVersion:1,recipes:original,catalogVersion:"good"),replace:true);for code in [500,503]{EmailLinkURLProtocol.handler={_ in(code,Data("{}".utf8))};await s.refresh();XCTAssertEqual(s.catalog.map(\.id),original.map(\.id))};EmailLinkURLProtocol.handler={_ in throw URLError(.timedOut)};await s.refresh();XCTAssertEqual(store().catalog.map(\.id),original.map(\.id));EmailLinkURLProtocol.handler={_ in(200,response)};await s.refresh();XCTAssertEqual(s.catalog.count,original.count)}
 func testINT011MalformedJSONPreservesCache()async throws{let s=store(),ids=s.catalog.map(\.id);EmailLinkURLProtocol.handler={_ in(200,Data("bad-json".utf8))};await s.refresh();XCTAssertEqual(s.catalog.map(\.id),ids)}
 func testINT011IncompleteQuotesCannotReplaceValidCache()async throws{let s=store();var broken=s.catalog[0];broken.quotes=[];let data=try JSONEncoder().encode(Catalog(schemaVersion:1,recipes:[broken],catalogVersion:"broken"));EmailLinkURLProtocol.handler={_ in(200,data)};await s.refresh();XCTAssertNotNil(s.catalog.first?.quote(2,"US"),"Incomplete API recipe must not replace usable cache")}
 func testINT013QueryEncoding()async throws{let s=store(),data=try JSONEncoder().encode(Catalog(schemaVersion:1,recipes:s.catalog,catalogVersion:"encoding"));for text in ["番茄","  ToFu  ","Tomato & \"Egg\"","🍄"]{EmailLinkURLProtocol.handler={r in let q=URLComponents(url:r.url!,resolvingAgainstBaseURL:false)!.queryItems!;XCTAssertEqual(q.first{$0.name=="q"}?.value,text);XCTAssertEqual(q.count,2);return(200,data)};_ = try await s.query(text,filter:"All")}}
 func testINT015OfflineFilterRules(){let s=store();for r in s.downloadedCatalog(filter:"Quick").recipes{XCTAssertLessThanOrEqual(r.minutes,15)};for r in s.downloadedCatalog(filter:"Beginner").recipes{XCTAssertEqual(r.difficulty,"Beginner")};for r in s.downloadedCatalog(filter:"Vegetarian").recipes{XCTAssertTrue(r.vegetarian)};for r in s.downloadedCatalog(filter:"Noodles").recipes{XCTAssertEqual(r.category,"Rice & Noodles")}}
 func testINT023024031AllQuotesShoppingAndSnapshot()throws{let s=store();for r in s.catalog{for n in 1...8{for u in ["US","Metric"]{let quote=try XCTUnwrap(r.quote(n,u));XCTAssertEqual(quote.recipeId,r.id);XCTAssertEqual(quote.recipeVersion,r.version);let item=try XCTUnwrap(quote.ingredients.first);XCTAssertTrue(s.addRecipeShopping(r,missing:[item.id],sessionServings:n,sessionUnits:u));let saved=try XCTUnwrap(s.list("shopping").first{$0.data.ingredientId==item.ingredientId});XCTAssertEqual(saved.data.qty,item.display);for e in s.list("shopping"){s.remove(e)}}}};s.savePreferences{$0.units="Metric"};s.selected=s.catalog[0];s.servings=8;s.beginPrep();XCTAssertEqual(store().disk.session?.units,"Metric");XCTAssertEqual(store().disk.session?.servings,8)}
 func testINT025FavoriteOfflineRoundtrip(){let s=store(),r=s.catalog[0];s.toggleFavorite(r);XCTAssertEqual(store().list("favorite").count,1);s.toggleFavorite(r);XCTAssertTrue(store().list("favorite").isEmpty)}
 func testINT036AllPhasesPersist(){let s=store();s.selected=s.catalog[0];s.beginPrep();for phase in ["prep","cook","complete"]{s.updateSession{$0.phase=phase;$0.checked=["ingredient"];$0.step=1};let reopened=store();reopened.resume();XCTAssertEqual(reopened.route,phase);XCTAssertEqual(reopened.disk.session?.checked,["ingredient"]);XCTAssertEqual(reopened.disk.session?.step,1)}}
 func testINT038BackgroundDeadlineMath(){let s=store();s.selected=s.catalog[0];s.beginPrep();s.route="cook";s.active=false;s.updateSession{$0.phase="cook";$0.step=1;$0.deadline=Date().addingTimeInterval(-10)};s.tick();XCTAssertEqual(s.disk.session?.step,1);XCTAssertEqual(s.disk.session?.seconds(),0);let reopened=store();XCTAssertEqual(reopened.disk.session?.seconds(),0)}
}

@MainActor final class CatalogGuardTests:XCTestCase {
 var folder:URL!
 override func setUp()async throws{folder=FileManager.default.temporaryDirectory.appendingPathComponent("catalog-guard-"+UUID().uuidString);try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)}
 override func tearDown()async throws{try FileManager.default.removeItem(at:folder)}
 func store()->KitchenStore{KitchenStore(folder:folder,monitor:false,loadAuth:false)}
 func testInvalidCatalogsNeverChangeMemoryOrDisk()throws{
  let s=store(),good=Catalog(schemaVersion:1,recipes:s.catalog,catalogVersion:"good");try s.cacheRecipes(good,replace:true)
  let file=folder.appendingPathComponent("catalog-v1.json"),bytes=try Data(contentsOf:file)
  var cases:[Catalog]=[];var bad=good;bad.schemaVersion=2;cases.append(bad);bad=good;bad.recipes.append(good.recipes[0]);cases.append(bad)
  for mutate:(inout Recipe)->Void in [{$0.quotes=[]},{$0.steps=[]},{$0.ingredients.append($0.ingredients[0])},{$0.steps.append($0.steps[0])},{$0.quotes[0].recipeVersion += 1},{$0.quotes[0]=$0.quotes[1]},{$0.quotes[0].ingredients[0].quantity = -1},{$0.quotes[0].ingredients[0].ingredientId="wrong"},{$0.quotes[0].ingredients.removeLast()}] {
   bad=good;mutate(&bad.recipes[0]);cases.append(bad)
  }
  for c in cases{XCTAssertThrowsError(try s.cacheRecipes(c,replace:true));XCTAssertEqual(try Data(contentsOf:file),bytes);XCTAssertEqual(s.catalog.count,good.recipes.count)}
  XCTAssertNoThrow(try Catalog(schemaVersion:1,recipes:[],catalogVersion:"empty").validated())
  var rounded=good;rounded.recipes[0].quotes[0].ingredients[0].quantity=0;XCTAssertNoThrow(try rounded.validated(),"Server rounding can legitimately produce zero; do not recalculate quantities")
 }
 func testPreviouslyPoisonedCacheFallsBackWithoutLosingKitchen()throws{
  let s=store();s.addShopping(name:"Keep this item");var bad=Catalog(schemaVersion:1,recipes:s.catalog,catalogVersion:"poisoned");bad.recipes[0].quotes=[]
  let file=folder.appendingPathComponent("catalog-v1.json");let bytes=try JSONEncoder().encode(bad);try bytes.write(to:file)
  let reopened=store();XCTAssertNotNil(reopened.catalog.first?.quote(2,"US"));XCTAssertEqual(reopened.list("shopping").count,1);XCTAssertFalse(reopened.storageNeedsRecovery);XCTAssertEqual(try Data(contentsOf:file),bytes)
 }
 func testAllInventoryFieldsRoundTripAndDelete()throws{
  let s=store();let fields=Fields(name:"Mushrooms",qty:"3 bags",group:"Produce",storage:"Freezer",type:"Review on",added:"2026-10-31",until:"2026-11-02");s.enqueue("inventory",id:"full-field",data:fields)
  let reopened=store(),item=try XCTUnwrap(reopened.list("inventory").first);XCTAssertEqual(item.data.name,fields.name);XCTAssertEqual(item.data.qty,fields.qty);XCTAssertEqual(item.data.group,fields.group);XCTAssertEqual(item.data.storage,fields.storage);XCTAssertEqual(item.data.type,fields.type);XCTAssertEqual(item.data.added,fields.added);XCTAssertEqual(item.data.until,fields.until);reopened.remove(item);XCTAssertTrue(store().list("inventory").isEmpty)
 }
 func testAllCatalogAllergensAreMarkedLocally()throws{
  let s=store();for alert in ["Peanuts","Soy","Eggs","Wheat","Sesame"]{s.savePreferences{$0.allergens=[alert]};let c=s.downloadedCatalog();for r in c.recipes{XCTAssertEqual(r.allergyAlerts,r.allergens.filter{String($0.split(separator:" ").first ?? "")==alert})}}
 }
 func testDateRoundTripAcrossTimezonesMonthAndDST(){
  let original=NSTimeZone.default;defer{NSTimeZone.default=original}
  for zone in ["Asia/Shanghai","America/Los_Angeles","Pacific/Auckland"]{NSTimeZone.default=TimeZone(identifier:zone)!;for value in ["2026-01-31","2026-02-01","2024-02-29","2026-03-08","2026-11-01","2026-12-31"]{let parsed=Dates.parse(value);XCTAssertNotNil(parsed);if let parsed{XCTAssertEqual(Dates.format(parsed),value)}}}
 }
}

private final class PhotoURLProtocol:URLProtocol {
 static var handler:((URLRequest)throws->(Int,String,Data))?
 override class func canInit(with request:URLRequest)->Bool{true}
 override class func canonicalRequest(for request:URLRequest)->URLRequest{request}
 override func startLoading(){do{let(status,mime,data)=try Self.handler!(request);print("Photo fixture response: status=\(status), mime=\(mime), bytes=\(data.count)");client?.urlProtocol(self,didReceive:HTTPURLResponse(url:request.url!,statusCode:status,httpVersion:nil,headerFields:["Content-Type":mime])!,cacheStoragePolicy:.notAllowed);client?.urlProtocol(self,didLoad:data);client?.urlProtocolDidFinishLoading(self)}catch{client?.urlProtocol(self,didFailWithError:error)}}
 override func stopLoading(){}
}
@MainActor final class PhotoCacheTests:XCTestCase {
 var folder:URL!;var session:URLSession!;var photos:RecipeImages!
 override func setUp()async throws{folder=FileManager.default.temporaryDirectory.appendingPathComponent("photo-guard-"+UUID().uuidString);let c=URLSessionConfiguration.ephemeral;c.protocolClasses=[PhotoURLProtocol.self];session=URLSession(configuration:c);photos=RecipeImages(session:session,folder:folder)}
 override func tearDown()async throws{session.invalidateAndCancel();PhotoURLProtocol.handler=nil;if FileManager.default.fileExists(atPath:folder.path){try FileManager.default.removeItem(at:folder)}}
 func jpeg()throws->Data{let path=try XCTUnwrap(Bundle.main.url(forResource:"0",withExtension:"jpg",subdirectory:"Explore/assets"));return try Data(contentsOf:path)}
 func testDownloadedImageSurvivesOfflineRestart()async throws{let bytes=try jpeg();PhotoURLProtocol.handler={_ in(200,"image/jpeg",bytes)};let online=await photos.image("recipes/tomato/v1.jpg");XCTAssertEqual(online,bytes);PhotoURLProtocol.handler={_ in throw URLError(.notConnectedToInternet)};let reopened=RecipeImages(session:session,folder:folder);let offline=await reopened.image("recipes/tomato/v1.jpg");XCTAssertEqual(offline,bytes)}
 func testInvalidImageResponsesNeverPoisonCache()async throws{let bytes=try jpeg();for (status,mime,data) in [(404,"image/jpeg",bytes),(200,"text/plain",bytes),(200,"image/jpeg",Data("broken".utf8)),(200,"image/jpeg",Data(repeating:0,count:5_000_001))]{PhotoURLProtocol.handler={_ in(status,mime,data)};let result=await photos.image("recipes/tomato/v1.jpg");XCTAssertNil(result);XCTAssertFalse(FileManager.default.fileExists(atPath:folder.appendingPathComponent("recipes_tomato_v1.jpg").path))};PhotoURLProtocol.handler={_ in throw URLError(.timedOut)};let timedOut=await photos.image("recipes/tomato/v1.jpg");XCTAssertNil(timedOut)}
 func testCorruptCachedImageRefetches()async throws{try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try Data("poisoned".utf8).write(to:folder.appendingPathComponent("recipes_tomato_v1.jpg"));let bytes=try jpeg();PhotoURLProtocol.handler={_ in(200,"image/jpeg",bytes)};let recovered=await photos.image("recipes/tomato/v1.jpg");XCTAssertEqual(recovered,bytes)}
}
