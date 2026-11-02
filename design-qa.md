# CNrecipe V1.1 原生/API 迁移视觉核对

final result: blocked

当前不是“全页面像素级一致已验收”或上线声明。静态视觉已完成多轮对照与修正；用户解锁后已完成系统减弱动态效果开启条件下的 3 项原生回归与计时连续帧复核，并恢复设置。常规动效精确时长和大字体/小机型覆盖仍未完成。

## 比较对象与口径

- 源视觉真值：`docs/design-handoff-2026-10-31/CNrecipe-修改说明.md`，`assets/preview-a-discover.png`（1705×923）、`preview-b-cook-corrected.png`（1536×1024）、`preview-c-support.png`（1536×1024），及八个原始 SVG。原 HTML 仍保留在 `reference/CNrecipe_v1.1_interactive.html`。
- 实现：`artifacts/architecture-migration-20261031/screens/` 中实际 XCTest 附件；独立 Web 在 `browser/` 中有真实 Chromium 截图和视频。
- 设备：CNrecipe iPhone 16 QA 100，iOS 27.0，`734C746B-F86E-436C-97B3-ABB2F39E06DD`。浅色主题、设备匿名样例数据，非登录账号数据。
- 实现图片为 1178×2556 像素，约 @3x，按逻辑视口 393×852 归一化；全页比较去掉真实系统顶部 59pt 和底部 34pt，内容 393×759。没有在 App 中绘制假状态栏或设备外框。
- A 板每屏约 384×814，没有与真实 iPhone 相同的系统安全区；B、C 的示意面板宽高比也不同。源面板只按宽度等比缩放，**不纵向拉伸到 iPhone 比例**。因此不能把整图高度差、自然换行或滚动位置差当作像素误差百分比。
- 原生页面使用真实六道 demo 菜谱、当前份数、日期和条数。白胡椒、特殊锅型、200 字备注限制、收藏行额外按钮均不从示意图新增。源图的生成食物画面不是实际配方结果，当前使用项目已有生成照片。
- 用户明确的原生/API 迁移覆盖 ZIP 中“此次不改后端/架构”的旧实施限制；其页面框架、视觉与交互要求仍适用。

## 证据

`scripts/compare-design.py` 生成源与实现**同一张图**的对照，参数写入 `comparisons/metadata.json`，不是只分别打开两张图后声称并排核对。

以下路径均相对 `artifacts/architecture-migration-20261031/`：

| 页面/状态 | 合并对照 |
| --- | --- |
| Home，有进行中会话入口 | `comparisons/home.png` |
| My Kitchen，日期临近与已过日期 | `comparisons/kitchen-tracked-dates.png` |
| Shopping，已购行 | `comparisons/shopping-checked.png` |
| 详情，2 份与只读食材 | `comparisons/native-detail.png` |
| 备料，4 份且未勾选 | `comparisons/native-prep.png` |
| Cook，步骤 3 暂停 | `comparisons/timer-paused.png` |
| 完成，5 星、备注、已保存 | `comparisons/completion-saved.png` |
| Favorites，原生卡片 | `comparisons/favorites-native.png` |
| Cooking history，独立记录 | `comparisons/history-native.png`、`comparisons/focus-history.png` |
| Settings，上半页 | `comparisons/settings-native-top.png` |
| Add ingredient，字段聚焦/系统输入附件 | `comparisons/ingredient-keyboard.png` |
| 食材抽屉，暂停提示 | `comparisons/ingredient-drawer-paused.png` |
| 食品/设备 SVG、计时数字细节 | `comparisons/focus-food-icons.png`、`comparisons/focus-timer.png` |

状态差异已明确：计时源图为 Running、实现为 Paused；完成截图是保存后且向下滚动，源图为未保存；食材表单源图为编辑且无键盘，实现为新增且字段聚焦（本轮最终截图只显示系统输入附件，未展示软键盘）；Favorites 的示例条数与真实 QA 数据不同。历史全页左侧是 C 板共同页面框架，具体历史条目另用 C 板 supporting state 的局部对照。不能用这些截图宣称相同状态整图逐像素通过。

## 必需视觉表面

| 表面 | 已核对结果与边界 |
| --- | --- |
| 字体与层级 | Georgia 衬线标题/计时数字，系统正文；Home 两行标题，原生页标题、说明、状态区分清晰。计时数字 52pt 等宽数字；保持 190pt 环。部分 B/C 图本身比例与生成字形不一致，不据此编造精确字体匹配率。 |
| 间距与布局 | 三个固定主入口、顶部子页、任务页无主导航；设置分组、Saved 居中标题及卡片、备料设备段落、完成评分卡已修正。小屏允许滚动，自动测试验证主操作可达；图中被安全区/滚动裁掉的按钮不被描述为不存在。 |
| 配色与可访问性 | paper/ink/line/accent/sage/nav 保留规范值；次要文字、琥珀文字与必要进度图形为达到明示对比度要求而加深。`contrast.json` 记录 8 个实际配色组合，文字均 ≥4.5、必要图形均 ≥3。 |
| 图片与图标 | 使用项目六张生成照片，V1 随包离线回退；食品/设备使用 ZIP SVG 原稿直接渲染的 @3x PNG，不描摹位图。主导航与设置使用原项目矢量路径。云端照片尚未上传，不能把本地回退当作对象存储验收。 |
| 文案与内容 | 各条数量、份数、用量、日期来自真实状态/API；No date 不显示伪血量；无重复 Needs attention。历史按每次烹饪独立显示，点击取该次版本快照。Account & sync 是用户此次明确要求的新增区。 |

## 修正历史

| 问题 | 修正与复核证据 |
| --- | --- |
| P1：设置单位选项无标签且值未正确绑定 | 添加明确 Region/Measurement units 标签与 US/Metric tag；真实 API 的公制 15mL 和过敏原高亮在模拟器通过；设置白卡分组已复拍。 |
| P1：Web 图片/设置图标的浏览器证据尚未加载 | 测试服务补上 SVG MIME；浏览器断言可见图片完成且 naturalWidth>0 后截图；最新 `browser/explore.png` 及 12 项测试通过。 |
| P2：原生 Saved 标题与列表缺少源稿层级 | 恢复居中标题、说明和白色列表卡；`comparisons/favorites-native.png` 复核；原生 UI 03 通过。 |
| P1：历史把同菜的多次记录挤在一个卡片且打开当前目录版本 | 改为每次记录一张卡、评分/备注/日期独立显示、打开保存快照；`native-history-final.xcresult` 的 UI 06 与 15 项状态测试通过，`comparisons/history-native.png` 复核。 |
| P2：计时字体、设置 emoji、购物白卡、备料设备分组与原稿不一致 | 改为 Georgia 数字、原路径图标、购物白卡、独立 Equipment 标题；实际截图与对应 UI 流程通过。 |
| P2：日期琥珀进度对比不足、厨房提示卡缺少边界/操作面 | 图形加深为 #A1762B（对 track 3.36），恢复提示卡边界和白色 Review 按钮；`native-final-polish.xcresult` 日期场景通过并复拍。 |
| P2：完成评分卡/食材表单/抽屉的细节差异 | 评分白卡、180ms 星级、步骤淡入、表单单列、原稿关闭图标及 44pt 点击区、表单深绿提交、抽屉暖色暂停提示已实现；最终 25/25 原生回归通过，最终表单/抽屉/评分/历史截图已重新合并核对，见 `reproducible-ios-final-summary.json` 及本次 report。 |

早期比较图和失败结果包保留以供追溯；不能将旧图中的已修正问题算作最终版本仍存在，也不能将尚未复拍的改动仅凭代码标记视觉通过。

## 剩余阻塞与验证限制

- **原生系统减弱动态效果已补验（20:32–20:40）**：在 QA 100 的系统设置实际由关闭切为开启，运行 UI03/UI04/UI05，3/3 通过、0 跳过、0 运行警告；详情/份数/备料/收藏、抽屉暂停/冷恢复、到时仅一次前进可用。`reduce-motion-enabled.png`、`native-reduced-motion-summary.json`、`reduced-motion-evidence/` 保存证据。已查看 `reduced-motion-timer-detail.png` 的连续帧：00:05→00:00 后进入步骤 3，环外无呼吸光圈。测试后实际恢复关闭，见 `reduce-motion-restored.png`。这不等同于全部动效逐帧时长通过。
- **P2 验收缺口：连续动效与精确时长**。原生抽屉使用系统 sheet，未逐帧证实规范 280/220ms；常规模式计时光圈、快速连续点击中断仍需专项录屏；本次补充的 `reduced-motion-xctest.mp4` 含有效原生操作，末段 `reduced-motion-timer.mp4` 为开启减弱动态效果的计时证据。`native-motion-acceptance.mp4` 含长时间系统桌面/启动画面，已查看联系表，**不能作为动效通过证据**。
- 原生 320pt 机型/系统最大文字、通知拒绝/锁屏投递没有在本轮完整覆盖。不能把 iPhone 16 的截图、源代码或旧 WebView 的通知测试等同于通过。
- 表单首次聚焦时，XCTest 实际记录 `Invalid frame dimension (negative or non-finite)` 运行警告。与键盘工具栏出现同时发生，功能用例可完成；尚未证明具体来源，不把它无依据归咎系统或隐藏警告。保留为待定位事项。

下一步：只在 QA 100 继续常规动效、通知与多尺寸复核；如发现不符合时长或可达性，再修正并复拍。不新增 Profile、第四 Tab、页面或其他 MVP 功能。云端 OTP 与照片另见交付报告，不以静态视觉代替联调。

## 2026-11-01 本地使用方案调整

用户最新指令优先：当前隐藏登录、Account & sync、导入与冲突解决入口；设置保留原有偏好、过敏提示和 About，并说明本机保存及换机/卸载风险。三主入口与现有原型视觉继续沿用。SMTP、真实双设备、账号删除、隐私政策与数据生命周期属于未来开放可选同步的门槛，不再阻塞当前无需账号的核心体验。原有通知/小屏/常规动效专项的未验证项仍保留。本次实际截图及验证见 `artifacts/local-first-20261101/`，不以旧含账号区截图认证新设置。

本地模式复核结果：已实际查看本轮 Settings 顶部与 About 截图、Explore 本地过敏标注截图；账户区确已移除，原偏好/alerts 组件不重做，本机保存说明可达。对应原生 UI07/UI09 通过；全量39/39，最后购物合并补齐后31/31通过。仅关闭本轮本地模式的视觉/流程项，其他动效/通知/尺寸验收限制仍不变。

## 手工录屏跟进

完整查看用户 02.14.41 录屏后，只修复有证据的成功提示生命周期与计时起/续一拍增加1秒，保持原有视觉。未证实滚动继承问题，不改滚动逻辑。新 UI11 通过实际等待提示消失；38/38 原生测试、Debug/Release 构建通过。备注组合输入仍待用户确认与真实验收，不由英文 typeText 断言覆盖。证据见 `artifacts/manual-recording-20261101/report.md`。
