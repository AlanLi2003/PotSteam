# CNrecipe V1.1 开发交付记录

> 本文件记录旧版整套 WKWebView 的历史交付，不能认证 2026-10-31 原生/API 迁移。当前架构、运行方式、验证与阻塞见 `../README.md`、`MIGRATION-PLAN.md`、`../design-qa.md` 和 `../artifacts/architecture-migration-20261031/report.md`。

## 已实现
- 以 reference 中的 HTML 为设计基准，保留产品 CSS、布局和交互；移除设计评审侧栏和模拟设备外壳。
- 食材增删改、分类、数量和日期校验、日期比例条；Use soon / Expired / No date 分开。
- 搜索、分类筛选、收藏、购物清单新增/勾选/删除/清除已购。
- 1–8 份与 US/Metric 用量联动、备料清单、分步烹饪、计时暂停恢复、评分备注与历史。
- Swift 原子 JSON 存储；冷启动注入状态；读取失败保护原文件，写入失败持续提示，重置前备份。
- 原生本地通知桥接，权限仅在开始计时时请求；拒绝权限仍可使用前台计时。取消计时会阻止尚未完成授权的过期请求。
- 六张生成食物照片、图标和页面均在 App Bundle 内，无远程资源依赖。

## 已验证
- 浏览器集成测试 6 项通过：CRUD、搜索收藏购物清单、日期筛选、备料恢复、份数/烹饪记录/计时恢复、图片资源与原型样式检查。日志：artifacts/web-tests.log。
- iOS Release 设备目标无签名构建通过。日志：artifacts/ios-release-build.log。
- 实际 iOS 模拟器截图已取得，首页、菜谱浏览、详情已人工查看；最终 XCTest 两项全部通过：食材新增与冷启动恢复；菜谱浏览、调整份数、备料、启动/暂停计时与冷启动恢复。日志：artifacts/ios-tests.log，截图：artifacts/ios-final/，原始结果包：/private/tmp/cnrecipe-ios-final。

## 运行
打开 ios/CNrecipe.xcodeproj，选择 CNrecipe scheme 和 iPhone 模拟器，按 Run。修改 UI 后执行 python3 scripts/build-web.py 再运行。App 不需要启动 Web 服务。

## 发布前仍需完成
- 用户已要求先开发；Team ID、最终 Bundle ID、签名归档和 TestFlight 上传暂缓，尚未发布。
- 六道原型菜谱保留 demo 标识，配方与操作需要实际烹饪审核；未伪装成已审核内容。
- 通知拒绝、后台锁屏投递、存储故障注入及多机型/真机覆盖尚未全部验收。
- 隐私政策文稿见 PRIVACY.md，仍需真实发布者资料、支持地址及 App Store 元数据。
- 目前仅完成已检查页面的视觉核验，不宣称所有设备上的逐像素比较通过。

不能将以上开发构建等同于已签名、已通过 App Store 审核的上线包。

## 交付文件与后续顺序
- 源码入口：ios/CNrecipe.xcodeproj。模拟器应用包：artifacts/CNrecipe-Simulator.zip（不是可用于真机安装的 IPA）。
- 最终源码校验：artifacts/source-checksums.json。浏览器自动测试源：tests/app.spec.js；原生界面测试源：ios/UITests/FlowTests.swift。
- 下一步优先补齐后台通知、拒绝权限、损坏存储和多机型专项测试；随后完成菜谱内容审核及签名归档。不要增加新 MVP 功能。

## Cook UX 增量验收

对照口径：`docs/COOK-UX-ACCEPTANCE.md`。证据目录：`artifacts/ux-cook/`。本节省名回溯既有浏览器 6 + 模拟器 UI 2，并记录 UX-COOK-01～08 增量状态。

**不宣称「Cook 交互已验收」整包通过**；01–04 有模拟器证据，05–08 进行中/待复测。

### 既有具名回溯（UX-COOK-08）

**浏览器**（`artifacts/web-tests.log` / `tests/app.spec.js`）

| 用例名（spec） | 通过标准（摘要） |
|----------------|------------------|
| kitchen CRUD survives reload and filters do not overlap | 增删改后 reload 仍在；筛选区间不重叠 |
| servings, checklist, timer and completion draft persist | 份数/备料/计时/完成草稿持久化 |
| screens preserve prototype styles with no remote resources | 样式贴近原型；无远程资源 |
| expiry stays zero and generated food assets load offline from bundle | 过期计数逻辑正确；图片离线自 bundle |
| search, favorites and shopping list persist end to end | 搜索/收藏/清单端到端持久化 |
| date filters stay disjoint and preparation checklist restores | 日期筛选互斥；备料清单可恢复 |

**模拟器 UI**（`ios/UITests/FlowTests.swift` / `artifacts/ios-tests.log`）

| 用例名 | 通过标准（摘要） |
|--------|------------------|
| testKitchenRestart | 新增食材 → terminate → cold launch → Kitchen 仍可见；有截图附件 |
| testCookingAndScreens | Explore→详情调份→备料→Cook→计时启停→退出→cold launch→Resume 会话且存在 Resume timer；多帧截图 |

### UX-COOK-01～08 增量状态（2026-10-30）

| ID | 状态 | 说明 |
|----|------|------|
| UX-COOK-01 R1 | 模拟器 PASS | `artifacts/ux-cook/01-tip.png` 等 + `ios-tests-rerun2.log`；MOV 未录 |
| UX-COOK-02 R2 | 模拟器 PASS | 证据 `02-*.png`；关抽屉不自动 Resume |
| UX-COOK-03 R3 | 模拟器 PASS | 证据 `03-no-timer.png` |
| UX-COOK-04 | 模拟器 PASS | 冷启动仍暂停；`04-*.png` + rerun2 日志 |
| UX-COOK-05 | 代码/用例已准备，模拟器占用中未复跑 | `testServingsSync`（US + waitForLabel + Cook 抽屉）；等可用模拟器 |
| UX-COOK-06 | 代码/用例已准备，模拟器占用中未复跑 | `testEmptyStates`（避开 Reset/Confirm；Home search）；上次 FAIL 见 `ios-tests-05-06.log` |
| UX-COOK-07 | 草稿 | `artifacts/ux-cook/prototype-parity.md` |
| UX-COOK-08 | 本段已写入 | 上表具名；增量未整包验收 |

Open：Settings 入口（齿轮 vs 第四 Tab）；自动跳步动效精修。发布/签名/真机不在本口径。笔记：`artifacts/ux-cook/notes.md`。


## PM 50 条报告问题闭环（2026-10-30）

031/032/049/053 的受阻和 074 的提示验证缺口已分别复测通过。购物行的勾选区域和删除按钮现为并列控件，修复 iOS AX 合并隐藏删除按钮的问题；维持原有视觉。补充双向/弹层滚动定位与强制提示断言，购物和收藏空态独立测试。浏览器 10 项通过，Simulator Debug 构建通过；原生结果与数据还原记录见 [PM50 修复回执](../artifacts/pm-50-fixes/report.md)。本次未声称重跑全部 50 条，也未放行发布。

## 完整 100 条报告的增量修复

已补必填可见错误、过敏原和评分可访问语义、食材数量/储存可访问名称、保存警告避让导航，以及损坏数据恢复入口。17 项浏览器测试通过，10 个原生方法分批成功复测。仍未完成的通知允许、模拟器断网与真实 VoiceOver 条件，及各批次的失败/跳过，详见[逐项修复回执](../artifacts/pm-100-fixes/report.md)。没有把 100 条全部改为通过。

## 剩余专项重试

091 首次授权、待发请求及长计时联动通过；094 在 QA WebView 实际阻断网络后冷启动和六图加载通过，非 Wi-Fi 开关验证；096 实际 iOS 脚本载荷提交及冷启动检查通过。097 描述审计通过，实际 VoiceOver 仍需真机阶段。Release Simulator 构建及 QA 编译隔离已检查，见 [重试回执](../artifacts/remaining-retry/report.md)。

2026-11-02 update: the current bundle contains 50 English recipes, 50 original title covers and ingredient icons. The same covers are uploaded and verified in Storage. See [current delivery](content/first-50/README.md).
