import XCTest
import UIKit

final class NativeAcceptance: XCTestCase {
    let app=XCUIApplication()
    override func setUpWithError() throws {continueAfterFailure=false;app.launch();XCTAssertTrue(app.buttons["tab-My Kitchen"].waitForExistence(timeout:60))}
    func reveal(_ element:XCUIElement) {for _ in 0..<12{
        let nav=app.buttons["tab-My Kitchen"],cookNext=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH %@","cook-next-")).firstMatch
        let boundary=cookNext.exists ? cookNext.frame.minY : (nav.exists ? nav.frame.minY : CGFloat.greatestFiniteMagnitude)
        if element.isHittable && (element.identifier.hasPrefix("cook-next-") || element.frame.maxY<boundary){return};app.swipeUp()
    };XCTAssertTrue(element.isHittable,"Cannot reach \(element)")}
    func focus(_ field:XCUIElement){XCTAssertTrue(field.waitForExistence(timeout:5));field.tap();XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout:5));field.tap()}
    func capture(_ name:String){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
    func dismissBanner(){if app.buttons["Dismiss"].exists{app.buttons["Dismiss"].tap()}}
    func openRecipe(){app.buttons["tab-Explore"].tap();let web=app.webViews.firstMatch;XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout:60));web.buttons["Explore Recipes"].tap();let link=web.links["Open Tomato and Egg Stir-Fry"];XCTAssertTrue(link.waitForExistence(timeout:35));link.tap();XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout:10));XCTAssertEqual(app.webViews.count,0,"Details must be native")}
    func prepare(){openRecipe();let prep=app.buttons["Get ready to cook →"];reveal(prep);prep.tap();if app.buttons["Start this recipe"].exists{app.buttons["Start this recipe"].tap()};let start=app.buttons["Start cooking →"];reveal(start);XCTAssertFalse(start.isEnabled);let ready=app.buttons["Mark everything ready"];reveal(ready);ready.tap();XCTAssertTrue(start.isEnabled);start.tap();XCTAssertTrue(app.buttons["Next step →"].waitForExistence(timeout:10))}
    func test01NativeKitchenCRUDAndRelaunch(){
        app.buttons["tab-My Kitchen"].tap();XCTAssertEqual(app.webViews.count,0);capture("kitchen-before")
        let add=app.buttons["add-ingredient"];reveal(add);add.tap();let field=app.textFields["Ingredient name"];XCTAssertTrue(field.waitForExistence(timeout:5));field.tap();let name="Native acceptance "+UUID().uuidString.prefix(5);field.typeText(String(name));capture("ingredient-keyboard");if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};let submit=app.buttons["Add to kitchen"];reveal(submit);submit.tap();
        let item=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Edit "+name)).firstMatch;XCTAssertTrue(item.waitForExistence(timeout:10));capture("kitchen-created");app.terminate();app.launch();app.buttons["tab-My Kitchen"].tap();XCTAssertTrue(item.waitForExistence(timeout:10));item.tap();let qty=app.textFields["Quantity"];qty.tap();let value=qty.value as? String ?? "";qty.typeText(String(repeating:XCUIKeyboardKey.delete.rawValue,count:value.count)+"3 bags");if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};let save=app.buttons["Save changes"];reveal(save);save.tap();XCTAssertTrue(item.waitForExistence(timeout:5));item.tap();let remove=app.buttons["Remove ingredient"];reveal(remove);remove.tap();app.buttons.matching(identifier:"Remove ingredient").allElementsBoundByIndex.last!.tap();XCTAssertFalse(item.waitForExistence(timeout:2));capture("kitchen-after-delete")
    }
    func test02ShoppingCheckRemoveAndPersistence(){
        app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap();let add=app.buttons["＋ Add shopping item"];reveal(add);add.tap();let input=app.textFields["Item name"];XCTAssertTrue(input.waitForExistence(timeout:5));focus(input);let name="Sesame QA "+UUID().uuidString.prefix(5);input.typeText(String(name));if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};app.buttons["Add to list"].tap();let check=app.buttons[String(name)];XCTAssertTrue(check.waitForExistence(timeout:5));check.tap();XCTAssertEqual(check.value as? String,"Checked");capture("shopping-checked");add.tap();focus(input);input.typeText(String(name));if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};app.buttons["Add to list"].tap();XCTAssertEqual(check.value as? String,"Checked");XCTAssertEqual(app.buttons.matching(identifier:String(name)).count,1);capture("shopping-duplicate-preserved");app.terminate();app.launch();app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap();XCTAssertEqual(check.value as? String,"Checked");app.buttons["Remove "+name].tap();XCTAssertFalse(check.waitForExistence(timeout:2))
    }
    func test03ExploreNativeDetailServingsPrepAndFavorites(){
        XCTAssertTrue(app.webViews.buttons["Home"].waitForExistence(timeout:60));capture("home");openRecipe();capture("native-detail");app.buttons["Increase servings"].tap();app.buttons["Increase servings"].tap();app.swipeUp();capture("detail-four-servings");let save=app.buttons["Save recipe"];if save.exists{reveal(save);save.tap()};let prep=app.buttons["Get ready to cook →"];reveal(prep);prep.tap();if app.buttons["Start this recipe"].exists{app.buttons["Start this recipe"].tap()};reveal(app.buttons["Start cooking →"]);XCTAssertFalse(app.buttons["Start cooking →"].isEnabled);capture("native-prep");app.buttons["Mark everything ready"].tap();XCTAssertTrue(app.buttons["Start cooking →"].isEnabled);app.swipeDown();app.swipeDown();app.buttons["Back"].tap();app.buttons["Back"].tap();app.buttons["tab-Saved"].tap();XCTAssertEqual(app.webViews.count,0);XCTAssertTrue(app.staticTexts["Tomato and Egg Stir-Fry"].waitForExistence(timeout:5));capture("favorites-native")
    }
    func test04TimerDrawerPauseColdResumeAndManualNext(){
        prepare();XCTAssertFalse(app.buttons["Start timer"].exists);reveal(app.buttons["Next step →"]);app.buttons["Next step →"].tap();XCTAssertTrue(app.staticTexts["Cook the eggs"].waitForExistence(timeout:5));reveal(app.buttons["Next step →"]);app.buttons["Next step →"].tap();XCTAssertTrue(app.staticTexts["Cook the tomatoes"].waitForExistence(timeout:5));let start=app.buttons["Start timer"];reveal(start);start.tap();if app.alerts.buttons["Allow"].waitForExistence(timeout:2){app.alerts.buttons["Allow"].tap()};dismissBanner();let view=app.buttons["View ingredients & quantities"];reveal(view);view.tap();capture("ingredient-drawer-paused");app.buttons["Close"].tap();let resume=app.buttons["Resume timer"];reveal(resume);XCTAssertTrue(resume.exists);capture("timer-paused");let exit=app.buttons["Save and exit cooking"];reveal(exit);exit.tap();app.terminate();app.launch();app.buttons["tab-Saved"].tap();app.buttons["In progress"].tap();let ongoing=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Resume cooking")).firstMatch;XCTAssertTrue(ongoing.waitForExistence(timeout:5));ongoing.tap();reveal(resume);XCTAssertTrue(resume.exists);XCTAssertFalse(app.buttons["Pause timer"].exists);capture("timer-cold-paused");app.buttons["← Back"].tap();reveal(app.buttons["Start timer"]);capture("cook-back-resets-timer");XCTAssertTrue(app.staticTexts["Cook the eggs"].exists)
    }
    func test05TimerExpiryDoesNotDoubleAdvance(){
        prepare();reveal(app.buttons["Next step →"]);app.buttons["Next step →"].tap();reveal(app.buttons["Start timer"]);app.buttons["Start timer"].tap();if app.alerts.buttons["Allow"].waitForExistence(timeout:1){app.alerts.buttons["Allow"].tap()};dismissBanner();let third=app.staticTexts["Cook the tomatoes"];XCTAssertTrue(third.waitForExistence(timeout:12));capture("auto-advanced-once");sleep(2);XCTAssertTrue(third.exists);app.buttons["← Back"].tap();reveal(app.buttons["Start timer"]);XCTAssertTrue(app.buttons["Start timer"].exists)
    }
    func test12TimerDigitsStayStableWhileCountingDown(){
        prepare();for _ in 0..<2{reveal(app.buttons["Next step →"]);app.buttons["Next step →"].tap()}
        let start=app.buttons["Start timer"];reveal(start);start.tap()
        if app.alerts.buttons["Allow"].waitForExistence(timeout:1){app.alerts.buttons["Allow"].tap()};dismissBanner()
        let timer=app.descendants(matching:.any).matching(NSPredicate(format:"label MATCHES %@",".*(Running|Almost done).*[0-9]{2}:[0-9]{2}.*")).firstMatch
        XCTAssertTrue(timer.waitForExistence(timeout:5));let initial=timer.label
        // The combined accessibility frame includes the expanding halo; glyph dimensions are checked in StateTests.
        for index in 0..<13{capture(String(format:"timer-digits-%02d",index));sleep(1);XCTAssertTrue(timer.exists)}
        XCTAssertNotEqual(timer.label,initial,"The countdown must advance during the visual check")
        app.buttons["Pause timer"].tap();capture("timer-digits-paused");XCTAssertTrue(app.buttons["Resume timer"].exists)
    }
    func test13ManualShoppingIconsRemainVisibleAfterRelaunch(){
        func assertIcon(_ row:XCUIElement,file:StaticString=#filePath,line:UInt=#line) {
            reveal(row);let frame=row.frame;let image=app.screenshot().image.cgImage!
            let scale=CGFloat(image.width)/app.frame.width
            // Check the separate 24pt icon slot, immediately after the 23pt checkbox and 11pt gap.
            let rect=CGRect(x:(frame.minX+34)*scale,y:(frame.midY-12)*scale,width:24*scale,height:24*scale)
            guard let crop=image.cropping(to:rect)else{XCTFail("Icon slot is offscreen",file:file,line:line);return}
            let width=crop.width,height=crop.height;var pixels=[UInt8](repeating:0,count:width*height*4)
            pixels.withUnsafeMutableBytes{bytes in
                let context=CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(crop,in:CGRect(x:0,y:0,width:width,height:height))
            }
            let green=(0..<(width*height)).filter{let i=$0*4;return Int(pixels[i+1])>Int(pixels[i])+15 && Int(pixels[i+1])>Int(pixels[i+2])+10}.count
            XCTAssertGreaterThan(green,20,"Expected a visible sage food icon for \(row.label)",file:file,line:line)
        }
        app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap()
        let names=["雞蛋","bok-choy","Custom icon QA "+UUID().uuidString.prefix(5)];var created:[String]=[]
        for name in names {
            if !app.buttons[name].exists {
                let add=app.buttons["＋ Add shopping item"];reveal(add);add.tap();let input=app.textFields["Item name"];XCTAssertTrue(input.waitForExistence(timeout:5));input.tap();input.typeText(name)
                if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};app.buttons["Add to list"].tap();created.append(name)
            }
            let row=app.buttons[name];XCTAssertTrue(row.waitForExistence(timeout:5));assertIcon(row);capture("manual-icon-"+String(names.firstIndex(of:name)!))
        }
        app.terminate();app.launch();app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap()
        for name in names{let row=app.buttons[name];XCTAssertTrue(row.waitForExistence(timeout:5));assertIcon(row)}
        capture("manual-icons-after-relaunch")
        for name in created{let remove=app.buttons["Remove "+name];reveal(remove);remove.tap()}
    }
    func test06CompletionRequiresExplicitSave(){
        prepare();let titles=["Prepare the ingredients","Cook the eggs","Cook the tomatoes","Combine and serve"];for step in 0..<3{let next=app.buttons["cook-next-"+String(step)];reveal(next);next.tap();XCTAssertTrue(app.staticTexts[titles[step+1]].waitForExistence(timeout:5))};let finish=app.buttons["cook-next-3"];reveal(finish);finish.tap();XCTAssertTrue(app.staticTexts["You made it!"].waitForExistence(timeout:5));capture("completion-unsaved");app.buttons["5 stars"].tap();let note=app.textFields["cooking-note"];reveal(note);note.tap();note.typeText("Native acceptance note");sleep(3);XCTAssertEqual(note.value as? String,"Native acceptance note");app.buttons["4 stars"].tap();sleep(2);XCTAssertEqual(note.value as? String,"Native acceptance note");note.tap();note.typeText(" good");capture("note-retained-after-refresh");if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()}else{app.swipeDown()};let save=app.buttons["Save to cooking history"];reveal(save);save.tap();dismissBanner();XCTAssertFalse(app.buttons["Saved to cooking history"].isEnabled);capture("completion-saved");let explore=app.buttons["Explore more recipes →"];reveal(explore);explore.tap();app.terminate();app.launch();XCTAssertTrue(app.buttons["tab-Saved"].waitForExistence(timeout:60));app.buttons["tab-Saved"].tap();app.buttons["Cooking history"].tap();XCTAssertTrue(app.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Native acceptance note good")).firstMatch.waitForExistence(timeout:5));capture("history-native");let record=app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Native acceptance note good")).firstMatch;record.tap();XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout:5));XCTAssertEqual(app.webViews.count,0)
    }
    func test11ShoppingSuccessNoticeExpiresWithoutManualDismissal(){
        openRecipe();let add=app.buttons["Add ingredients to shopping list"];reveal(add);add.tap()
        let notice=app.staticTexts["Ingredients added to shopping list"]
        XCTAssertTrue(notice.waitForExistence(timeout:2));capture("shopping-success-notice")
        XCTAssertTrue(notice.waitForNonExistence(timeout:6));XCTAssertFalse(app.buttons["Dismiss"].exists);capture("shopping-success-notice-expired")
    }
    func test07SettingsStayLocalWithoutAccountEntry(){
        app.buttons["tab-My Kitchen"].tap();app.buttons["Settings"].tap()
        XCTAssertEqual(app.webViews.count,0);XCTAssertTrue(app.staticTexts["Preferences"].waitForExistence(timeout:5))
        XCTAssertFalse(app.buttons["Sign in with email"].exists);XCTAssertFalse(app.buttons["Sync now"].exists);XCTAssertFalse(app.staticTexts["Account & sync"].exists)
        let large=app.switches["Larger cooking text"];let original=large.value as? String;large.tap();let changed=large.value as? String
        XCTAssertNotEqual(original,changed);capture("settings-local-only")
        app.terminate();app.launch();XCTAssertTrue(app.buttons["tab-My Kitchen"].waitForExistence(timeout:60));app.buttons["tab-My Kitchen"].tap();app.buttons["Settings"].tap()
        XCTAssertEqual(large.value as? String,changed);XCTAssertFalse(app.buttons["Sign in with email"].exists)
        let storage=app.staticTexts["Your kitchen data is saved on this iPhone. Changing phones or removing the app may lose it."];reveal(storage);XCTAssertTrue(storage.exists);capture("settings-local-storage-disclosure")
        app.swipeDown();large.tap();XCTAssertEqual(large.value as? String,original)
    }
    func test08OfflineTransportAndNativeHitAreas(){
        for tab in ["Explore","My Kitchen","Saved"]{XCTAssertGreaterThanOrEqual(app.buttons["tab-"+tab].frame.height,44);XCTAssertGreaterThanOrEqual(app.buttons["tab-"+tab].frame.width,44)}
        app.terminate();app.launchEnvironment["CNRECIPE_QA_OFFLINE"]="1";app.launch();let web=app.webViews.firstMatch;XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout:60));web.buttons["Explore Recipes"].tap();let offline=web.staticTexts.matching(NSPredicate(format:"label BEGINSWITH %@","Offline ·")).firstMatch;XCTAssertTrue(offline.waitForExistence(timeout:35));capture("offline-downloaded-explore");let recipe=web.links["Open Tomato and Egg Stir-Fry"];XCTAssertTrue(recipe.exists);recipe.tap();XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout:5));XCTAssertEqual(app.webViews.count,0);capture("offline-native-detail");app.buttons["Back"].tap();app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap();let add=app.buttons["＋ Add shopping item"];reveal(add);add.tap();let name="Offline QA "+UUID().uuidString.prefix(5);let input=app.textFields["Item name"];input.tap();input.typeText(String(name));if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()};app.buttons["Add to list"].tap();XCTAssertTrue(app.buttons[String(name)].waitForExistence(timeout:5));app.terminate();app.launch();XCTAssertTrue(app.buttons["tab-My Kitchen"].waitForExistence(timeout:60));app.buttons["tab-My Kitchen"].tap();app.buttons["Shopping List"].tap();XCTAssertTrue(app.buttons[String(name)].waitForExistence(timeout:5));capture("offline-cold-relaunch");app.buttons["Remove "+name].tap();app.terminate();app.launchEnvironment.removeValue(forKey:"CNRECIPE_QA_OFFLINE");app.launch()
    }
    func test09SettingsUnitsAndLocalAllergenHighlight(){
        app.buttons["tab-My Kitchen"].tap();app.buttons["Settings"].tap();let units=app.buttons["settings-units"];XCTAssertTrue(units.waitForExistence(timeout:5));units.tap();app.buttons["Metric"].tap();let eggs=app.switches["Eggs"];reveal(eggs);let wasOn=eggs.value as? String=="1";if !wasOn{eggs.tap()};capture("settings-eggs-alert");app.buttons["Back"].tap();app.buttons["tab-Explore"].tap();let web=app.webViews.firstMatch;XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout:60));web.buttons["Explore Recipes"].tap();let alert=web.staticTexts.matching(NSPredicate(format:"label CONTAINS %@","Allergy alert")).firstMatch;XCTAssertTrue(alert.waitForExistence(timeout:30));capture("explore-local-allergen-highlight");web.links["Open Tomato and Egg Stir-Fry"].tap();let oil=app.staticTexts["15 mL"];reveal(oil);XCTAssertTrue(oil.exists);capture("native-metric-quantities");app.buttons["Back"].tap();app.buttons["tab-My Kitchen"].tap();app.buttons["Settings"].tap();app.buttons["settings-units"].tap();app.buttons["US"].tap();if !wasOn{reveal(eggs);eggs.tap()}
    }
    func test10TrackedDatesAndKitchenFilters(){
        app.buttons["tab-My Kitchen"].tap();let soon=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Edit Tomatoes, 1d left")).firstMatch;let expired=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Edit Eggs, Date passed")).firstMatch;XCTAssertTrue(soon.waitForExistence(timeout:5));XCTAssertTrue(expired.exists);capture("kitchen-tracked-dates");app.buttons["Use soon"].tap();XCTAssertTrue(soon.exists);XCTAssertFalse(expired.exists);capture("kitchen-use-soon");app.buttons["Expired"].tap();XCTAssertTrue(expired.exists);XCTAssertFalse(soon.exists);capture("kitchen-expired");app.buttons["No date"].tap();XCTAssertFalse(soon.exists);XCTAssertFalse(expired.exists);capture("kitchen-no-date");app.buttons["All items"].tap()
    }
}

// Release UI fixtures are written by the test runner only on the reserved QA phone.
// No fixture/reset launch hooks are included in the shipping App.
final class ReleaseReadinessUI:XCTestCase {
 let app=XCUIApplication();var folder:URL!
 override func setUpWithError()throws{
  continueAfterFailure=false
  guard let path=ProcessInfo.processInfo.environment["CNRECIPE_QA_CONTAINER"],path.contains("734C746B-F86E-436C-97B3-ABB2F39E06DD") else{throw NSError(domain:"QA fixture requires dedicated phone",code:1)}
  app.terminate()
  let containers=URL(fileURLWithPath:path).deletingLastPathComponent()
  let matches=try FileManager.default.contentsOfDirectory(at:containers,includingPropertiesForKeys:nil).filter { candidate in
   guard let bytes=try? Data(contentsOf:candidate.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")),let metadata=(try? PropertyListSerialization.propertyList(from:bytes,format:nil)) as? [String:Any] else{return false}
   return metadata["MCMMetadataIdentifier"] as? String == "com.cnrecipe.app"
  }
  XCTAssertEqual(matches.count,1,"Resolve the currently installed QA app container")
  folder=try XCTUnwrap(matches.first).appendingPathComponent("Library/Application Support/CNrecipe");try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true);try Data("{\"version\":2,\"entities\":[],\"outbox\":[],\"conflicts\":[],\"cursor\":0}".utf8).write(to:folder.appendingPathComponent("state-v2-device.json"),options:.atomic);XCUIDevice.shared.orientation = .portrait
 }
 func refreshFolder(){
  guard let path=ProcessInfo.processInfo.environment["CNRECIPE_QA_CONTAINER"],path.contains("734C746B-F86E-436C-97B3-ABB2F39E06DD") else{XCTFail("Missing reserved QA container");return}
  do {
   let root=URL(fileURLWithPath:path).deletingLastPathComponent()
   let matches=try FileManager.default.contentsOfDirectory(at:root,includingPropertiesForKeys:nil).filter { candidate in
    guard let data=try? Data(contentsOf:candidate.appendingPathComponent(".com.apple.mobile_container_manager.metadata.plist")),let info=(try? PropertyListSerialization.propertyList(from:data,format:nil)) as? [String:Any] else{return false}
    return info["MCMMetadataIdentifier"] as? String == "com.cnrecipe.app"
   }
   XCTAssertEqual(matches.count,1);folder=try XCTUnwrap(matches.first).appendingPathComponent("Library/Application Support/CNrecipe")
  }catch{XCTFail("Cannot resolve current QA container: \(error)")}
 }
 func launch(){app.launch();XCTAssertTrue(app.buttons["tab-My Kitchen"].waitForExistence(timeout:40));refreshFolder()}
 func tap(_ e:XCUIElement){for _ in 0..<12{let nav=app.buttons["tab-My Kitchen"];if e.isHittable && (app.buttons["Close"].exists || !nav.exists || e.frame.maxY<nav.frame.minY){break};app.swipeUp()};e.tap()}
 func done(){if app.toolbars.buttons["Done"].exists{app.toolbars.buttons["Done"].tap()}}
 func shot(_ name:String){let a=XCTAttachment(screenshot:app.screenshot());a.name=name;a.lifetime = .keepAlways;add(a)}
 func openRecipe(){app.buttons["tab-Explore"].tap();let web=app.webViews.firstMatch;XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout:30));web.buttons["Explore Recipes"].tap();let link=web.links["Open Tomato and Egg Stir-Fry"];XCTAssertTrue(link.waitForExistence(timeout:30));link.tap();XCTAssertTrue(app.buttons["Increase servings"].waitForExistence(timeout:10))}
 func testRecoverySettingsResetCancelAndBackup()throws{
  var file=folder.appendingPathComponent("state-v2-device.json");let bad=Data("broken-json".utf8);try bad.write(to:file);launch();file=folder.appendingPathComponent("state-v2-device.json");XCTAssertTrue(app.buttons["Recovery settings"].waitForExistence(timeout:5));app.buttons["Recovery settings"].tap();let reset=app.buttons["Reset device kitchen"];tap(reset);XCTAssertTrue(app.staticTexts.containing(NSPredicate(format:"label CONTAINS %@","recovery backup")).firstMatch.waitForExistence(timeout:3));app.coordinate(withNormalizedOffset:CGVector(dx:0.05,dy:0.2)).tap();XCTAssertEqual(try Data(contentsOf:file),bad);tap(reset);let choices=app.buttons.matching(identifier:"Reset device kitchen");choices.element(boundBy:choices.count-1).tap();XCTAssertTrue(app.buttons["tab-My Kitchen"].waitForExistence(timeout:5));let backups=try FileManager.default.contentsOfDirectory(at:folder,includingPropertiesForKeys:nil).filter{$0.lastPathComponent.hasPrefix("reset-backup-")};XCTAssertEqual(backups.count,1);XCTAssertEqual(try Data(contentsOf:backups[0].appendingPathComponent("state-v2-device.json")),bad);shot("release-recovery-reset-backed-up")
 }
 func testIngredientNameBoundariesAndStorageRoundtrip()throws{
  launch();app.buttons["tab-My Kitchen"].tap()
  for text in ["   ",String(repeating:"b",count:71)]{tap(app.buttons["add-ingredient"]);let f=app.textFields["Ingredient name"];XCTAssertTrue(f.waitForExistence(timeout:5));f.tap();f.typeText(text);done();tap(app.buttons["Add to kitchen"]);XCTAssertTrue(app.staticTexts["Enter a name up to 70 characters."].exists);app.buttons["Close"].tap()}
  for text in [String(repeating:"a",count:70),"香菇🍄", "<script>test</script>"]{tap(app.buttons["add-ingredient"]);let f=app.textFields["Ingredient name"];XCTAssertTrue(f.waitForExistence(timeout:5));f.tap();f.typeText(text);done();let storage=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Storage, ")).firstMatch;tap(storage);app.buttons["Freezer"].tap();tap(app.buttons["Add to kitchen"]);app.terminate();launch();app.buttons["tab-My Kitchen"].tap();let row=app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@","Edit "+text+", ")).firstMatch;XCTAssertTrue(row.exists);tap(row);XCTAssertTrue(app.buttons.matching(NSPredicate(format:"label CONTAINS %@","Storage, Freezer")).firstMatch.exists);tap(app.buttons["Remove ingredient"]);let choices=app.buttons.matching(identifier:"Remove ingredient");choices.element(boundBy:choices.count-1).tap()};shot("release-ingredient-boundaries")
 }
 func testPrepAllReadyThenUncheckDisablesStart(){launch();openRecipe();tap(app.buttons["Get ready to cook →"]);if app.buttons["Start this recipe"].exists{app.buttons["Start this recipe"].tap()};let start=app.buttons["Start cooking →"];tap(app.buttons["Mark everything ready"]);XCTAssertTrue(start.isEnabled);let ready=app.buttons.matching(NSPredicate(format:"value == %@","Checked")).firstMatch;XCTAssertTrue(ready.exists);tap(ready);XCTAssertFalse(start.isEnabled);shot("prep-uncheck-disables-start")}
}
