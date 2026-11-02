# Release 证据核对

2026-11-02。此次为历史结果与当前源码核对，没有重新运行 XCTest。

- 进程检查没有发现仍在执行的 xcodebuild 或 test-ios-release；旧 work-state 中的 session 不作为活跃任务证据。
- `artifacts/prelaunch-fixes-2026-11-01/release-tests/native.log` 以 TEST EXECUTE FAILED 结束。
- 原生单元套件记录57项、7次断言失败，涉及图片非法响应测试；此外 UI 套件的购物输入焦点与恢复设置测试失败。不能将57项当作整套 UI+单元总数。
- `restoration.json` 记录 identical=true，原始与恢复的三个文件哈希一致。这只证明该次脚本退出时的恢复，不证明当前设备数据仍等于当时数据。
- 当前 `RecipeImages.image` 的网络读取使用注入的 `session`，并检查200、JPEG MIME、完整可解码JPEG及5MB上限。旧日志出现440394字节返回与失败断言，不能仅凭当前源码认定已复测修复；日志中的测试行号也与当前文件不同。

下一步应使用当前源码重新构建 Release 测试，并先复测 PhotoCacheTests、购物与恢复设置三组，再决定是否扩大回归。只用专用 QA 100，并通过现有脚本隔离及恢复数据；不得复用旧 xctestrun 证明当前版本通过。

目前依然不放行 App Store 发布。此记录补充 APP-STORE-STATE.md，不替代真实候选包验收。

## 容器路径更正

2026-11-02 后续核对发现：历史 xctestrun 中的 QA 数据容器路径与当前 simctl 返回值不同。旧脚本安装前记录容器路径，安装可能使路径变化，因此此前 restoration.json 的 identical=true 只证明脚本指定目录与备份一致，不能证明当时 App 活跃数据容器已恢复。撤回将旧哈希记录等同于活跃容器恢复的结论。原始备份仍保留，不覆盖当前设备数据以免损失后续改动。脚本现于安装后重新取得容器路径，让夹具、UI runner 与退出恢复指向当前容器；正在定向复测恢复设置。

图片响应头修复已通过三项 Release PhotoCacheTests，证据：`artifacts/release-tests/photo-header-fix-20261102/`。该轮旧脚本的数据恢复限制同上。

## 定向闭环与组合回归

- 图片缓存：原始 Content-Type 响应头校验修复，`photo-header-fix-20261102` 三项通过。
- 恢复设置：UI 测试须在启动后重新解析当前容器；`recovery-launch-path-20261102` 原取消/备份断言通过，退出恢复哈希一致。
- 计时抽屉与食材边界：滚动点击条件补齐烹饪底部固定按钮及弹窗边界，`ui-hitarea-fix-20261102` 两项通过，退出恢复哈希一致。
- 当前源码组合回归已启动：`artifacts/release-tests/final-store-regression-20261102/`；源码指纹见该目录 source-manifest.json。测试尚未结束，不计为完整通过。

这些是模拟器 Release 测试证据，不证明真机通知、App Store 分发签名、内容审核或备案完成。
