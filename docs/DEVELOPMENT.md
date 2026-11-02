# CNrecipe iOS V1.1

当前开发架构：SwiftUI 原生导航、库存/购物/Saved/详情/烹饪/设置 + Explore WKWebView。Supabase 继续提供菜谱 API、图片和数据库；当前版本隐藏登录与账号同步入口，库存、收藏、购物、偏好、历史和烹饪状态保存在本机，核心体验无需账号。旧版整套 WebView 留在 `ios/CNrecipe/Web` 作为迁移参考，已不打入新版 App。原型不改，视觉基线见 `docs/design-handoff-2026-10-31/`。

这是开发验收版本，**尚非可上线版本**。2026-11-01 起，登录与云端用户同步移出当前核心体验的交付范围；SMTP 和账号同步未完成不再作为本地核心体验的验收门槛。视觉、平台验收、内容审核及其他尚未完成项，以本轮 [最新修复报告](artifacts/ingredient-icons-20261101/report.md) 和 [视觉核对](design-qa.md) 为准。2026-10-31 迁移报告中的登录计划为历史记录，本地模式的实际验证结果须以本轮新证据为准。

## Xcode 与实时预览

用 Xcode 打开 `ios/CNrecipe.xcodeproj`，选择 **CNrecipe** scheme、经典 iPhone Simulator。`ios/CNrecipe/App.swift` 含 SwiftUI `#Preview`；完整 Web/原生交互应在 Simulator 运行。

专用测试设备 **CNrecipe iPhone 16 QA 100**，iOS 27.0，UDID `734C746B-F86E-436C-97B3-ABB2F39E06DD`。DeviceHub/Xcode 中选择该名称即可查看。**禁止把测试目标改成 `booted` 或用户的 iPhone Duo**。原来的 `CNrecipe iPhone 16` 仍保留旧版本，未被本轮覆盖。

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
export PATH=/Users/alanli/nodejs/bin:$PATH
npm ci
npm run build:assets
xcodebuild -project ios/CNrecipe.xcodeproj -scheme CNrecipe -configuration Debug \
  -destination 'platform=iOS Simulator,id=734C746B-F86E-436C-97B3-ABB2F39E06DD' \
  -derivedDataPath artifacts/NativeSignedDerivedData \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build
xcrun simctl install 734C746B-F86E-436C-97B3-ABB2F39E06DD artifacts/NativeSignedDerivedData/Build/Products/Debug-iphonesimulator/CNrecipe.app
xcrun simctl launch 734C746B-F86E-436C-97B3-ABB2F39E06DD com.cnrecipe.app
```

模拟器使用本地 ad hoc 签名以支持 Keychain，不设置 DEVELOPMENT_TEAM、不使用 Personal Team。不执行真机、archive、TestFlight 或正式发布。不能把 Simulator `.app` 交给真机安装。

## 自动验证

```sh
export PATH=/Users/alanli/nodejs/bin:$PATH
export PLAYWRIGHT_BROWSERS_PATH=/private/tmp/cnrecipe-browsers
npx playwright install chromium
npm test
npm run test:ios
npm run test:ios:release
```

`npm test`：实际 PostgreSQL/PGlite 事务与 RLS、HTTP 契约、真实 Chromium 中的 Explore/云端查询/离线回退。PGlite 测试身份是本地 fixture，不能代替实际邮箱登录验收。

`test:ios`：只使用上述 QA 100。先构建/安装，在保留并备份 QA 原数据后建立两条相对日期样例，再跑原生单元与界面测试，输出 `artifacts/native-tests/`。脚本不会卸载 App 或操作其他设备。测试会在 QA 中创建库存、购物和烹饪记录。旧 `FlowTests` / `test:legacy` 对应旧整套 WebView，不代表新版原生页通过。

`test:ios:release`：同样仅使用 QA 100，先隔离备份原数据，结束时自动恢复并校验 SHA-256。直接构建优化后的 Release 测试目标，构建命令仅为 `@testable` 增加 `ENABLE_TESTABILITY=YES`，不启用 DEBUG。运行目录完整性、图片缓存、原生逻辑与界面回归，结果保存在 `artifacts/release-tests/`。UI 测试夹具由独立 runner 写入隔离目录；正式 App 没有清数据/夹具入口。依赖 Debug 离线传输开关的旧用例不在此 Release 套件中运行，不能因此宣称已完成 Release 弱网或真机验收。

## 云端与 Explore Web

独立开发项目 `mlrerdrnwuudjsnjodkp`，新加坡。API：`https://mlrerdrnwuudjsnjodkp.supabase.co/functions/v1/cnrecipe`。仅 publishable key 随客户端发布；管理凭证不进入客户端或 JS。契约与隔离规则见 `docs/API.md`。

`backend/schema.sql` 是累计 schema；`supabase/migrations/` 是已应用迁移，不回写历史。`backend/seeds/catalog.json` contains the 50 published English recipes (2026-11-02); see [release notes](docs/content/first-50/README.md). The old demo remains only in tests/fixtures/legacy-catalog.json for regression checks. Do not overwrite the released seed with extract-seed.`build:assets` 通过同一 SQL 生成 1–8 份、US/Metric 离线投影，并复制 Explore 与原始 SVG 资源。不要恢复从 HTML 数组直接供给运行时业务。

独立浏览器开发入口：

```sh
python3 -m http.server 4182 --bind 127.0.0.1 --directory ios/CNrecipe/Explore
```

访问 `http://127.0.0.1:4182`，菜谱链接有 Web 详情回退。App 使用随包 Explore + 同一实时 API；尚无公开部署的 Explore 站点。

## 数据保护

当前用户数据使用本机 v2 JSON 原子落盘，不自动恢复 Supabase 登录，也不上传用户实体。菜谱搜索文字仍会发往公共 API；库存名称和过敏偏好在本地匹配、标注，不随每次目录查询上传。旧 v1 文件不覆盖，迁移生成 SHA-256 备份；无法读取的存储不继续写入，重置先备份。开始烹饪冻结菜谱版本与用量，关闭完成页不会自动保存历史。通知权限拒绝不影响应用内计时。

已有账号缓存、待处理数据及 Keychain 项保留，不自动合并到设备数据，也不作为当前登录状态使用。换机、卸载或设备损坏后的恢复尚未验证；不要把本地恢复备份描述为 iCloud 备份或跨设备同步。

CLI 管理登录已恢复，六张云端图片已上传并下载校验。管理登录用于维护菜谱与云端资源，不是 App 启动门槛。Supabase Auth、同步和 RLS 实现保留作未来可选同步功能；此前 Magic Link 工作未验收，当前不发送登录邮件。

后续仅在用户确有换机恢复或多设备同步需求时重新开放登录。开放前必须完成可靠 SMTP、真实双设备测试、账号删除、已发布隐私政策及数据生命周期说明，并验证已有本地数据的导入与隔离；不能只打开入口或配置开关。继续使用 Supabase Auth，无需更换服务。具体边界见 `docs/API.md`。
