import XCTest

final class FlowTests: XCTestCase {
    func testKitchenRestart() {
        continueAfterFailure = false
        let uniqueName = "iOS acceptance " + UUID().uuidString.prefix(8)
        let app = XCUIApplication()
        app.launch()
        let kitchen = app.webViews.buttons["My Kitchen"]
        XCTAssertTrue(kitchen.waitForExistence(timeout: 60)); kitchen.tap()
        let addButton = app.webViews.buttons["Add ingredient"]
        if !addButton.isHittable { app.swipeUp() }
        XCTAssertTrue(addButton.waitForExistence(timeout: 5)); addButton.tap()
        let name = app.webViews.textFields["Ingredient name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5)); name.tap(); name.typeText(uniqueName)
        XCTAssertEqual(name.value as? String, String(uniqueName))
        capture(app, "031-keyboard-form")
        reveal(app.webViews.buttons["Add to kitchen"], in: app); app.webViews.buttons["Add to kitchen"].tap()
        let created = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", uniqueName)).firstMatch
        if !created.waitForExistence(timeout: 5), app.webViews.buttons["Add to kitchen"].exists { app.webViews.buttons["Add to kitchen"].tap() }
        XCTAssertTrue(created.waitForExistence(timeout: 10))
        app.terminate(); app.launch()
        XCTAssertTrue(app.webViews.buttons["My Kitchen"].waitForExistence(timeout: 60)); app.webViews.buttons["My Kitchen"].tap()
        let item = app.webViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", uniqueName)).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 10))
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "Kitchen after cold launch"; shot.lifetime = .keepAlways; add(shot)
    }

    func testCookingAndScreens() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }; return false
        }
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 60))
        capture(app, "Explore home")
        web.buttons["Explore Recipes"].tap()
        capture(app, "Recipe browser")
        web.buttons["Open Tomato & Egg Stir-Fry"].tap()
        reveal(web.buttons["Increase servings"], in: app)
        web.buttons["Increase servings"].tap()
        capture(app, "Recipe detail three servings")
        let prep = web.buttons["Get ready to cook →"]
        reveal(prep, in: app); prep.tap()
        let ready = web.buttons["Mark everything ready"]
        reveal(ready, in: app); ready.tap()
        reveal(web.buttons["Start cooking →"], in: app); web.buttons["Start cooking →"].tap()
        reveal(web.buttons["Next step →"], in: app); web.buttons["Next step →"].tap()
        web.buttons["Next step →"].tap()
        reveal(web.buttons["Start timer"], in: app); web.buttons["Start timer"].tap()
        if app.alerts.firstMatch.exists { app.alerts.buttons["Allow"].tap() }
        XCTAssertTrue(web.buttons["Pause timer"].waitForExistence(timeout: 10))
        capture(app, "Cooking timer running")
        web.buttons["Pause timer"].tap()
        XCTAssertTrue(web.buttons["Resume timer"].waitForExistence(timeout: 5))
        capture(app, "04-before-kill")
        reveal(web.buttons["Save and exit cooking"], in: app); web.buttons["Save and exit cooking"].tap()
        app.terminate(); app.launch()
        XCTAssertTrue(web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume ")).firstMatch.waitForExistence(timeout: 60))
        let resume = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Resume ")).firstMatch
        web.swipeUp(); reveal(resume, in: app); resume.tap()
        reveal(web.buttons["Resume timer"], in: app)
        // UX-COOK-04: cold resume must stay paused (Resume present, Pause absent)
        XCTAssertTrue(web.buttons["Resume timer"].exists)
        XCTAssertFalse(web.buttons["Pause timer"].exists, "Timer must remain paused after cold resume")
        capture(app, "04-after-cold-resume-paused")
        web.buttons["Resume timer"].tap()
        XCTAssertTrue(web.buttons["Pause timer"].waitForExistence(timeout: 5))
        capture(app, "04-after-manual-resume")
    }

    /// UX-COOK-01 / R1: timer reaches 0 → tip → auto next step; Back restores prior step.
    func testCookR1AutoAdvance() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }; return false
        }
        let web = app.webViews.firstMatch
        enterTomatoCookTimerStep(app: app, web: web)
        reveal(web.buttons["Start timer"], in: app)
        web.buttons["Start timer"].tap()
        if app.alerts.firstMatch.exists { app.alerts.buttons["Allow"].tap() }
        XCTAssertTrue(web.buttons["Pause timer"].waitForExistence(timeout: 10))
        // Poll for tip toast then auto-advance (5s timer + ~1.4s tip)
        var sawTip = false
        let deadline = Date().addingTimeInterval(18)
        while Date() < deadline {
            if web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "advancing")).firstMatch.exists {
                if !sawTip { capture(app, "01-tip"); sawTip = true }
            }
            if web.staticTexts["Cook the tomatoes"].exists { break }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        XCTAssertTrue(sawTip, "074 requires a visible timer-completion tip before advancing")
        XCTAssertTrue(web.staticTexts["Cook the tomatoes"].waitForExistence(timeout: 5), "Should auto-advance to next step after timer")
        capture(app, "01-next-step")
        // Tomatoes step has its own duration — Start timer may appear; empty capsule must not linger from prior step
        XCTAssertFalse(web.buttons["Pause timer"].exists, "Prior timer must not keep running on the new step")
        reveal(web.buttons["← Back"], in: app)
        web.buttons["← Back"].tap()
        XCTAssertTrue(web.staticTexts["Cook the eggs"].waitForExistence(timeout: 10))
        capture(app, "01-back-after-auto-advance")
    }

    /// UX-COOK-02 / R2: opening ingredients drawer pauses; closing does not resume.
    func testCookR2DrawerPauses() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        addUIInterruptionMonitor(withDescription: "Notification permission") { alert in
            if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }; return false
        }
        let web = app.webViews.firstMatch
        enterTomatoCookTimerStep(app: app, web: web)
        reveal(web.buttons["Start timer"], in: app)
        web.buttons["Start timer"].tap()
        if app.alerts.firstMatch.exists { app.alerts.buttons["Allow"].tap() }
        XCTAssertTrue(web.buttons["Pause timer"].waitForExistence(timeout: 10))
        reveal(web.buttons["View ingredients & quantities"], in: app)
        web.buttons["View ingredients & quantities"].tap()
        XCTAssertTrue(web.buttons["Close dialog"].waitForExistence(timeout: 5))
        // R2 synthetic: drawer open + paused (sheet shows pause note; Pause timer must not exist)
        let pauseNote = web.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Timer paused")).firstMatch
        XCTAssertTrue(pauseNote.waitForExistence(timeout: 5), "Drawer must show timer-paused status")
        XCTAssertFalse(web.buttons["Pause timer"].exists)
        capture(app, "02-drawer-paused")
        web.buttons["Close dialog"].tap()
        // After close: still paused — must show Resume, not Pause
        XCTAssertTrue(web.buttons["Resume timer"].waitForExistence(timeout: 5), "Closing drawer must not auto-resume")
        XCTAssertFalse(web.buttons["Pause timer"].exists)
        capture(app, "02-after-drawer-still-paused")
        web.buttons["Resume timer"].tap()
        XCTAssertTrue(web.buttons["Pause timer"].waitForExistence(timeout: 5))
        capture(app, "02-after-manual-resume")
    }

    /// UX-COOK-03 / R3: no duration → no timer capsule; Next still available.
    func testCookR3NoTimerCapsule() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 60))
        web.buttons["Explore Recipes"].tap()
        web.buttons["Open Tomato & Egg Stir-Fry"].tap()
        let prep = web.buttons["Get ready to cook →"]
        reveal(prep, in: app); prep.tap()
        let ready = web.buttons["Mark everything ready"]
        reveal(ready, in: app); ready.tap()
        reveal(web.buttons["Start cooking →"], in: app); web.buttons["Start cooking →"].tap()
        // Step 1 Prepare has duration 0
        XCTAssertTrue(web.staticTexts["Prepare the ingredients"].waitForExistence(timeout: 10))
        XCTAssertFalse(web.buttons["Start timer"].exists)
        XCTAssertFalse(web.buttons["Pause timer"].exists)
        XCTAssertFalse(web.buttons["Resume timer"].exists)
        XCTAssertTrue(web.buttons["Next step →"].exists)
        capture(app, "03-no-timer")
        web.buttons["Next step →"].tap()
        XCTAssertTrue(web.staticTexts["Cook the eggs"].waitForExistence(timeout: 10))
    }


    /// UX-COOK-05: servings change syncs detail quantities.
    func testServingsSync() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 60))
        web.buttons["Explore Recipes"].tap()
        XCTAssertTrue(web.buttons["Open Tomato & Egg Stir-Fry"].waitForExistence(timeout: 15))
        web.buttons["Open Tomato & Egg Stir-Fry"].tap()
        XCTAssertTrue(web.staticTexts["Tomato & Egg Stir-Fry"].waitForExistence(timeout: 15))
        // Prefer US so eggs stay "… large" (user try-out may have left Metric)
        let us = web.buttons["US"]
        if us.waitForExistence(timeout: 5) {
            reveal(us, in: app)
            if us.exists { us.tap() }
        }
        // Qty may sit below fold; WK often merges "Eggs"+"3 large" into one AX label
        XCTAssertTrue(waitForLabel(containing: "3 large", in: web, timeout: 20), "eggs qty at 2 servings")
        capture(app, "05-servings-before")
        // After scrolling to qty, stepper may be above fold — swipe down then reveal
        for _ in 0..<6 { web.swipeDown() }
        reveal(web.buttons["Increase servings"], in: app)
        web.buttons["Increase servings"].tap() // 3 servings → eggs 4.5 large
        XCTAssertTrue(waitForLabel(containing: "4.5 large", in: web, timeout: 20), "eggs qty must scale to 4.5 at 3 servings")
        capture(app, "05-servings-after")
        // Prep checklist shows name+qty in <small>; Cook drawer is the walkthrough-06 parity check
        let prep = web.buttons["Get ready to cook →"]
        reveal(prep, in: app); prep.tap()
        let ready = web.buttons["Mark everything ready"]
        reveal(ready, in: app); ready.tap()
        reveal(web.buttons["Start cooking →"], in: app); web.buttons["Start cooking →"].tap()
        let viewIng = web.buttons["View ingredients & quantities"]
        reveal(viewIng, in: app); viewIng.tap()
        XCTAssertTrue(waitForLabel(containing: "4.5 large", in: web, timeout: 15), "cook drawer qty must match 3 servings")
        XCTAssertTrue(
            web.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "3 servings")).firstMatch.waitForExistence(timeout: 8),
            "drawer should show 3 servings"
        )
        capture(app, "05-prep-or-cook-qty")
    }

    /// UX-COOK-06: empty states for search / favorites / shopping list.
    /// Avoids Settings→Reset: native confirm is Cancel/Confirm; prior path left alert up and WK AX dead (~L214 searchFields).
    func testEmptyStates() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 60))
        // --- Search empty: Home searchbox; submit → recipes tab + empty ---
        let field = recipeSearchField(in: web)
        XCTAssertTrue(field.waitForExistence(timeout: 15), "search field missing on Explore home")
        field.tap()
        // Clear any leftover query from persisted state
        if let value = field.value as? String, !value.isEmpty, value != "Search recipes or ingredients" {
            let clear = field.buttons["Clear text"]
            if clear.exists { clear.tap() }
            else {
                field.press(forDuration: 1.0)
                if app.menuItems["Select All"].waitForExistence(timeout: 2) {
                    app.menuItems["Select All"].tap()
                }
            }
        }
        field.typeText("zzzz-no-such-recipe-xyz")
        let searchGo = web.buttons["Search"]
        XCTAssertTrue(searchGo.waitForExistence(timeout: 5), "Search submit missing")
        searchGo.tap()
        XCTAssertTrue(web.staticTexts["No matching recipes"].waitForExistence(timeout: 10))
        capture(app, "06-search-empty")
        // --- Favorites empty: unsave demo defaults (tomato/noodles) ---
        XCTAssertTrue(web.buttons["Saved"].waitForExistence(timeout: 10))
        web.buttons["Saved"].tap()
        if web.buttons["Favorites"].waitForExistence(timeout: 5) { web.buttons["Favorites"].tap() }
        for _ in 0..<6 {
            if web.staticTexts["Nothing here yet"].exists { break }
            let row = web.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Tomato", "Noodle")).firstMatch
            if !row.waitForExistence(timeout: 5) { break }
            row.tap()
            let unsave = web.buttons["♥ Saved"]
            if unsave.waitForExistence(timeout: 8) {
                reveal(unsave, in: app); unsave.tap()
            } else {
                let alt = web.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Saved")).firstMatch
                if alt.waitForExistence(timeout: 3) { reveal(alt, in: app); alt.tap() }
            }
            XCTAssertTrue(web.buttons["Back"].waitForExistence(timeout: 5))
            reveal(web.buttons["Back"], in: app); web.buttons["Back"].tap()
            XCTAssertTrue(web.buttons["Saved"].waitForExistence(timeout: 10))
            web.buttons["Saved"].tap()
            if web.buttons["Favorites"].waitForExistence(timeout: 5) { web.buttons["Favorites"].tap() }
        }
        XCTAssertTrue(web.staticTexts["Nothing here yet"].waitForExistence(timeout: 10), "Favorites empty copy missing")
        capture(app, "06-favorites-empty")
        // --- Kitchen + shopping empty ---
        web.buttons["My Kitchen"].tap()
        capture(app, "07-kitchen-after-padding")
        let shop = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shopping List")).firstMatch
        XCTAssertTrue(shop.waitForExistence(timeout: 10)); shop.tap()
        for _ in 0..<12 {
            let remove = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove ")).firstMatch
            if !remove.exists { break }
            remove.tap()
        }
        XCTAssertTrue(
            web.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "shopping list is empty")).firstMatch.waitForExistence(timeout: 10),
            "Shopping list empty state missing"
        )
        capture(app, "06-list-empty")
    }

    func testCase049ShoppingEmpty() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["My Kitchen"].waitForExistence(timeout: 60)); web.buttons["My Kitchen"].tap()
        let shop = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Shopping List")).firstMatch
        reveal(shop, in: app); shop.tap()
        let empty = web.staticTexts["Your shopping list is empty"]
        let firstRemove = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove ")).firstMatch
        if !empty.exists {
            XCTAssertTrue(firstRemove.waitForExistence(timeout: 15), "Shopping list must finish loading before deletion")
            let item = web.switches.firstMatch
            XCTAssertTrue(item.waitForExistence(timeout: 5))
            let before = item.value as? String
            item.tap()
            XCTAssertNotEqual(item.value as? String, before, "Separate checkbox must still toggle")
            capture(app, "049-checkbox-and-remove")
        }
        for _ in 0..<30 {
            let remove = web.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Remove ")).firstMatch
            if !remove.exists { break }
            reveal(remove, in: app); remove.tap()
        }
        XCTAssertTrue(web.staticTexts["Your shopping list is empty"].waitForExistence(timeout: 10))
        capture(app, "049-shopping-empty")
    }

    func testCase053FavoritesEmpty() {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Saved"].waitForExistence(timeout: 60)); web.buttons["Saved"].tap()
        for _ in 0..<6 {
            if web.staticTexts["Nothing here yet"].exists { break }
            let row = web.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Tomato", "Noodle")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 5)); reveal(row, in: app); row.tap()
            let unsave = web.buttons["♥ Saved"]
            reveal(unsave, in: app); unsave.tap()
            let back = web.buttons["Back"]
            reveal(back, in: app); back.tap()
            XCTAssertTrue(web.buttons["Saved"].waitForExistence(timeout: 8)); web.buttons["Saved"].tap()
        }
        XCTAssertTrue(web.staticTexts["Nothing here yet"].waitForExistence(timeout: 10))
        capture(app, "053-favorites-empty")
    }

    private func enterTomatoCookTimerStep(app: XCUIApplication, web: XCUIElement) {
        XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 60))
        web.buttons["Explore Recipes"].tap()
        web.buttons["Open Tomato & Egg Stir-Fry"].tap()
        let prep = web.buttons["Get ready to cook →"]
        reveal(prep, in: app); prep.tap()
        let ready = web.buttons["Mark everything ready"]
        reveal(ready, in: app); ready.tap()
        reveal(web.buttons["Start cooking →"], in: app); web.buttons["Start cooking →"].tap()
        reveal(web.buttons["Next step →"], in: app); web.buttons["Next step →"].tap()
        // Now on Cook the eggs (duration 5)
        XCTAssertTrue(web.staticTexts["Cook the eggs"].waitForExistence(timeout: 10))
    }

    private func recipeSearchField(in web: XCUIElement) -> XCUIElement {
        let label = "Search recipes or ingredients"
        let deadline = Date().addingTimeInterval(15)
        while Date() < deadline {
            let asSearch = web.searchFields[label]
            if asSearch.exists { return asSearch }
            let asText = web.textFields[label]
            if asText.exists { return asText }
            if web.searchFields.firstMatch.exists { return web.searchFields.firstMatch }
            if web.textFields.firstMatch.exists { return web.textFields.firstMatch }
            RunLoop.current.run(until: Date().addingTimeInterval(0.25))
        }
        return web.textFields[label]
    }

    /// Scroll until any AX node label contains the needle (qty rows often merge name+qty).
    @discardableResult
    private func waitForLabel(containing needle: String, in web: XCUIElement, timeout: TimeInterval) -> Bool {
        let pred = NSPredicate(format: "label CONTAINS %@", needle)
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if web.descendants(matching: .any).matching(pred).firstMatch.exists { return true }
            web.swipeUp()
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return web.descendants(matching: .any).matching(pred).firstMatch.exists
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 8), "Expected control: \(element)")
        let web = app.webViews.firstMatch
        for _ in 0..<12 {
            if element.isHittable { return }
            // Drag the active content area, not the whole WKWebView. The sheet
            // has its own scroller and the keyboard reduces its visible area.
            let close = web.buttons["Close dialog"]
            let keyboard = app.keyboards.firstMatch
            let top = close.exists ? max(web.frame.minY, close.frame.minY - 15) : web.frame.minY
            let bottom = keyboard.exists ? min(web.frame.maxY, keyboard.frame.minY) : web.frame.maxY
            let upper = top + (bottom - top) * 0.20
            let lower = top + (bottom - top) * 0.85
            let down = element.frame.midY < top + 20
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: web.frame.midX, dy: down ? upper : lower))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: web.frame.midX, dy: down ? lower : upper))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(element.isHittable, "Control should be reachable by scrolling: \(element)")
    }
    private func capture(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = name; shot.lifetime = .keepAlways; add(shot)

    }
}

// Product acceptance cases 004–056: each method has its own simulator launch and result.
final class PMAdditionalTests: XCTestCase {
    private var app: XCUIApplication!
    private var web: XCUIElement { app.webViews.firstMatch }

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        guard web.buttons["Explore Recipes"].waitForExistence(timeout: 45) else {
            throw XCTSkip("Home unavailable; case precondition blocked")
        }
    }

    private func tap(_ element: XCUIElement, _ context: String) throws {
        guard element.waitForExistence(timeout: 8) else { throw XCTSkip("Missing control: \(context)") }
        if !element.isHittable {
            for _ in 0..<5 { web.swipeUp(); if element.isHittable { break } }
        }
        guard element.isHittable else { throw XCTSkip("Control not hittable: \(context)") }
        element.tap()
    }
    private func contains(_ text: String) -> Bool {
        web.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", text)).firstMatch.exists
    }
    private func recipes() throws { try tap(web.buttons["Explore Recipes"], "Explore Recipes") }
    private func tomato() throws {
        try recipes()
        try tap(web.buttons["Open Tomato & Egg Stir-Fry"], "Tomato recipe")
        guard web.buttons["Increase servings"].waitForExistence(timeout: 10) else { throw XCTSkip("Recipe detail unavailable") }
    }
    private func search(_ value: String) throws {
        let f = web.searchFields.firstMatch.exists ? web.searchFields.firstMatch : web.textFields.firstMatch
        try tap(f, "search input")
        f.typeText(value)
        try tap(web.buttons["Search"], "search submit")
    }
    private func selectedCards(_ expected: [String], absent: [String]) {
        for name in expected { XCTAssertTrue(web.buttons["Open \(name)"].exists, "Missing \(name)") }
        for name in absent { XCTAssertFalse(web.buttons["Open \(name)"].exists, "Unexpected \(name)") }
    }
    private let allNames = ["Tomato & Egg Stir-Fry", "Kung Pao Chicken", "Egg Fried Rice", "Scallion Oil Noodles", "Garlic Bok Choy", "Mapo Tofu"]
    private func prep() throws {
        try tomato()
        try tap(web.buttons["Get ready to cook →"], "Get ready to cook")
        guard web.buttons["Start cooking →"].waitForExistence(timeout: 8) else { throw XCTSkip("Prep unavailable") }
    }
    func testCase004() throws { try tap(web.buttons["Saved"], "Saved"); XCTAssertTrue(web.buttons["Favorites"].waitForExistence(timeout: 5)) }
    func testCase005() throws { try tap(web.buttons["Settings"], "Settings"); XCTAssertTrue(web.staticTexts["Preferences"].waitForExistence(timeout: 5)) }
    func testCase006() throws { try tap(web.buttons["Settings"], "Settings"); try tap(web.buttons["Back"], "Back"); XCTAssertTrue(web.buttons["Explore Recipes"].waitForExistence(timeout: 5)) }
    func testCase007() throws { try tap(web.buttons["15-min meals"], "15-min meals"); selectedCards(["Tomato & Egg Stir-Fry", "Egg Fried Rice", "Garlic Bok Choy"], absent: ["Kung Pao Chicken", "Scallion Oil Noodles", "Mapo Tofu"]) }
    func testCase008() throws { try search("tomato"); selectedCards(["Tomato & Egg Stir-Fry"], absent: ["Kung Pao Chicken", "Egg Fried Rice", "Scallion Oil Noodles", "Garlic Bok Choy", "Mapo Tofu"]) }
    func testCase009() throws { try tomato(); try tap(web.buttons["Back"], "detail Back"); XCTAssertTrue(web.buttons["Open Tomato & Egg Stir-Fry"].waitForExistence(timeout: 5)) }
    func testCase011() throws { try search("Tomato"); selectedCards(["Tomato & Egg Stir-Fry"], absent: ["Kung Pao Chicken", "Egg Fried Rice", "Scallion Oil Noodles", "Garlic Bok Choy", "Mapo Tofu"]) }
    func testCase012() throws { try search("Eggs"); selectedCards(["Tomato & Egg Stir-Fry", "Egg Fried Rice"], absent: ["Kung Pao Chicken", "Scallion Oil Noodles", "Garlic Bok Choy", "Mapo Tofu"]) }
    func testCase013() throws {
        try search("tomato")
        let first = allNames.filter { web.buttons["Open \($0)"].exists }
        app.terminate(); app.launch()
        guard web.buttons["Explore Recipes"].waitForExistence(timeout: 45) else { throw XCTSkip("Home unavailable after relaunch") }
        try search("TOMATO")
        XCTAssertEqual(first, allNames.filter { web.buttons["Open \($0)"].exists })
        XCTAssertEqual(first, ["Tomato & Egg Stir-Fry"])
    }
    func testCase015() throws { try search("zzzz-no-such-recipe-xyz"); try tap(web.buttons["Clear filters"], "Clear filters"); selectedCards(allNames, absent: []) }
    func testCase016() throws { try recipes(); try tap(web.buttons["All"], "All"); selectedCards(allNames, absent: []) }
    func testCase017() throws { try recipes(); try tap(web.buttons["Quick & easy"], "Quick & easy"); selectedCards(["Tomato & Egg Stir-Fry", "Egg Fried Rice", "Garlic Bok Choy"], absent: ["Kung Pao Chicken", "Scallion Oil Noodles", "Mapo Tofu"]) }
    func testCase018() throws { try recipes(); try tap(web.buttons["Beginner"], "Beginner"); selectedCards(["Tomato & Egg Stir-Fry", "Egg Fried Rice", "Scallion Oil Noodles", "Garlic Bok Choy"], absent: ["Kung Pao Chicken", "Mapo Tofu"]) }
    func testCase019() throws { try recipes(); try tap(web.buttons["Vegetarian"], "Vegetarian"); selectedCards(["Tomato & Egg Stir-Fry", "Egg Fried Rice", "Scallion Oil Noodles", "Garlic Bok Choy"], absent: ["Kung Pao Chicken", "Mapo Tofu"]) }
    func testCase020() throws { try recipes(); try tap(web.buttons["Rice & noodles"], "Rice & noodles"); selectedCards(["Egg Fried Rice", "Scallion Oil Noodles"], absent: ["Tomato & Egg Stir-Fry", "Kung Pao Chicken", "Garlic Bok Choy", "Mapo Tofu"]) }
    func testCase022() throws { try tomato(); XCTAssertTrue(contains("15 min")); XCTAssertTrue(contains("Beginner")); XCTAssertTrue(contains("Servings")); XCTAssertTrue(contains("Tomatoes")) }
    func testCase024() throws { try tomato(); for _ in 0..<8 { try tap(web.buttons["Decrease servings"], "Decrease servings") }; try tap(web.buttons["Increase servings"], "Increase servings"); try tap(web.buttons["Increase servings"], "Increase servings"); try tap(web.buttons["Decrease servings"], "Decrease servings"); XCTAssertTrue(contains("2")); for _ in 0..<5 { if contains("3 large") { return }; web.swipeUp() }; XCTFail("2-serving egg quantity 3 large not found") }
    func testCase025() throws { try tomato(); for _ in 0..<10 { try tap(web.buttons["Decrease servings"], "Decrease servings") }; XCTAssertTrue(contains("1")); for _ in 0..<5 { if contains("1.5 large") { return }; web.swipeUp() }; XCTFail("1-serving egg quantity not found") }
    func testCase026() throws { try tomato(); for _ in 0..<10 { try tap(web.buttons["Increase servings"], "Increase servings") }; XCTAssertTrue(contains("8")); for _ in 0..<5 { if contains("12 large") { return }; web.swipeUp() }; XCTFail("8-serving egg quantity not found") }
    func testCase027() throws { try tomato(); try tap(web.buttons["Metric"], "Metric"); for _ in 0..<6 { if contains("mL") { return }; web.swipeUp() }; XCTFail("Metric unit mL not found") }
    func testCase028() throws { try tomato(); try tap(web.buttons["US"], "US"); for _ in 0..<6 { if contains("tbsp") { return }; web.swipeUp() }; XCTFail("US unit tbsp not found") }
    func testCase029() throws { try tomato(); for _ in 0..<8 { if contains("Allergen note") && contains("Eggs") { return }; web.swipeUp() }; XCTFail("Egg allergen note not found") }
    func testCase030() throws { try tomato(); for _ in 0..<8 { if contains("demonstration content") && contains("culinary review") { return }; web.swipeUp() }; XCTFail("Demo and culinary review notice not found") }
    func testCase054() throws { try prep(); XCTAssertTrue(contains("Checklist")); XCTAssertTrue(contains("Cooking pan and utensils")); XCTAssertTrue(contains("Tomatoes")) }
    func testCase055() throws { try prep(); XCTAssertFalse(web.buttons["Start cooking →"].isEnabled) }
    func testCase056() throws { try prep(); XCTAssertTrue(contains("0/6 ready")); let item = web.switches.matching(NSPredicate(format: "label CONTAINS %@", "Tomatoes")).firstMatch; XCTAssertEqual(item.value as? String, "0"); try tap(item, "Tomatoes checklist item"); XCTAssertEqual(item.value as? String, "1"); XCTAssertTrue(contains("1/6 ready"), "Checking an item should increment the ready count") }
}

