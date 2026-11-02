# CNrecipe Cook UX 验收口径（给 Codexx）

- 作者：Karina（UX）
- 状态：L3 出稿；**不代签发布**；发布须用户或 Jisoo 放行
- 对照：`docs/DELIVERY.md`、`artifacts/`、既有 `tests/app.spec.js` / `ios/UITests/FlowTests.swift`
- 范围：补交互态验收；不扩 MVP 功能
- Open（暂用默认，勿写入「已完成」）：Settings 入口（齿轮 vs 第四 Tab）；自动跳步过渡动效与文案细节

---

## A. 用户已拍板的 Cook 三条约定

| ID | 约定 |
|----|------|
| R1 | 计时到 0 → 出现短提示后**自动进入下一步**；可用 Back 回退 |
| R2 | 打开食材抽屉 → **先暂停**计时；**关闭抽屉不自动恢复**，须再点计时胶囊（Resume / 继续） |
| R3 | 无 `duration` 的步骤 → **不渲染计时器**（不留空胶囊）；主操作仍为 Next |

现有 `testCookingAndScreens` 覆盖「启动/暂停/冷启动后 Resume timer」，**未覆盖** R1 自动跳步、R2 抽屉合成态、R3 无计时态。下列用例为必补。

---

## B. 验收用例（用例名 · 通过标准 · 证据）

证据默认落：`artifacts/ux-cook/`（新建），截图 PNG + 关键路径短录屏 MOV/MP4；日志可附在同目录 `notes.md`。浏览器与模拟器各跑一遍优先；至少模拟器有完整证据。

### 缺口 1 — Cook 三条约定（各 ≥1 条）

#### UX-COOK-01 · 计时结束自动跳步（R1）
- **前置**：进入含短 duration 步骤的 Cook（可用测试用 3–5s 步骤，或调短现有计时）；计时运行中。
- **步骤**：等计时到 0，不点 Next。
- **通过标准**：
  1. 到 0 后出现短提示（文案可用暂用默认，须可见、可理解）。
  2. 随后**自动**进入下一步（步骤序号 / 文案变化）。
  3. 点 Back 可回到刚结束计时的那一步（或等价可撤销前进）。
  4. 不出现空/坏计时胶囊挂在下一步上（若下一步无 duration，见 UX-COOK-03）。
- **证据**：录屏「到 0 → 提示 → 自动下一步」全程；截图各一：提示态、跳步后。文件建议：`01-auto-advance.mov`、`01-tip.png`、`01-next-step.png`。

#### UX-COOK-02 · 抽屉打开且计时已暂停（R2 合成态）
- **前置**：Cook 中计时运行。
- **步骤**：打开食材抽屉 → 观察计时 → 关闭抽屉 → 观察计时 → 再点计时胶囊恢复。
- **通过标准**：
  1. 抽屉一开，计时立刻变为暂停态（文案/控件为 Pause 已生效或显示 Resume）。
  2. 抽屉打开期间剩余秒数**不再减少**（至少观察 3s）。
  3. **关闭抽屉后仍保持暂停**，不自动 Resume。
  4. 再点计时胶囊后才继续倒计时。
- **证据**：合成态截图（抽屉开 + 暂停）；录屏开/关抽屉与手动恢复。建议：`02-drawer-paused.png`、`02-drawer-cycle.mov`。

#### UX-COOK-03 · 无计时步骤空态（R3）
- **前置**：进入明确无 duration 的步骤（数据或原型中无计时步）。
- **步骤**：停留在该步，检查卡片区域与主操作。
- **通过标准**：
  1. **不出现**计时胶囊（含空胶囊、0:00 占位、灰显假控件）。
  2. Tip / 步骤说明正常收住，无大块空白「缺组件」感。
  3. 主操作仍为 **Next**（或产品既定的「下一步」），可进入下一步。
- **证据**：该步全屏截图。建议：`03-no-timer.png`。

---

### 缺口 2 — 关杀恢复专项（暂停语义）

#### UX-COOK-04 · 冷启动后仍为暂停且可续计
- **前置**：Cook 中计时运行 → 点 Pause（或经 R2 抽屉导致暂停）→ 记录步骤序号与剩余秒数 → 杀进程（terminate）→ 冷启动 → Resume 会话。
- **通过标准**：
  1. 恢复后仍在同一烹饪会话/步骤。
  2. 计时控件为 **Resume**（暂停态），**不是**自动在跑。
  3. 剩余秒数与杀前一致或符合时间戳设计（若用 wall-clock，须在报告注明规则；暂停期间墙钟流逝**不得**把暂停段扣掉后仍显示「在跑」）。
  4. 点 Resume 后秒数开始减少。
- **证据**：杀前暂停截图、冷启动后 Resume 截图、点 Resume 后运行截图；可选录屏。建议：`04-before-kill.png`、`04-after-cold-resume-paused.png`、`04-after-manual-resume.png`。
- **对照**：可扩展现有 `testCookingAndScreens`；DELIVERY 已有「暂停计时冷启动恢复」叙述时，本条要求**显式断言暂停态**，仅有 Resume 按钮存在不够。

---

### 缺口 3 — 份量变更同步

#### UX-COOK-05 · 调份后用量与清单一致
- **前置**：菜谱详情；默认份数记为 N。
- **步骤**：Increase/Decrease 到 N±1（或 1→3）；查看详情用量、备料清单、若已进 Cook 则步骤内食材量；购物清单若从该菜写入则抽查一条。
- **通过标准**：
  1. 详情展示用量随份数变化。
  2. 备料 / 步骤内食材量与详情一致（同单位制 US/Metric 下）。
  3. 无旧份数残留文案或「份数与克数对不上」的误导。
- **证据**：调份前/后详情各一；备料或 Cook 内食材一帧。建议：`05-servings-before.png`、`05-servings-after.png`、`05-prep-or-cook-qty.png`。

---

### 缺口 4 — 空态

#### UX-COOK-06 · 搜索无结果 / 收藏空 / 清单空
- **步骤**：搜索必无命中关键词；清空或新装态打开收藏；清空购物清单（或新装）。
- **通过标准**：各有明确空态（文案或插画），**非**白屏、未捕获错误、无限 loading。
- **证据**：三张截图。建议：`06-search-empty.png`、`06-favorites-empty.png`、`06-list-empty.png`。
- **说明**：Cook 无计时空态已由 UX-COOK-03 覆盖，此处不重复。

---

### 缺口 5 — HTML 原型 vs 模拟器对照

#### UX-COOK-07 · 关键路径对照表
- **路径**（至少）：Tonight/首页 → 菜谱浏览 → 详情 → 备料 → Cook；Cook 内打开食材抽屉；收藏开关（或 Saved）。
- **通过标准**：
  1. 产出对照表（可附本文件或 `artifacts/ux-cook/prototype-parity.md`）：每路径一行 — 原型截图路径 | 模拟器截图路径 | 一致 / 可接受差异说明。
  2. 「保留 HTML 原型」≠ 免检；布局、主按钮文案、计时/抽屉入口须可辨认为同一产品。
  3. 不要求逐像素；差异须写明（字体、安全区、系统控件等）。
- **证据**：对照表 + 成对截图。建议目录：`artifacts/ux-cook/parity/`。

---

### 缺口 6 — 既有「浏览器 6 + 模拟器 UI 2」具名回溯

#### UX-COOK-08 · 用例清单与通过标准入报告
将下列名称与标准写回 `DELIVERY.md`「已验证」或本文件附录，避免只写「6 项 / 2 项」。

**浏览器（`artifacts/web-tests.log`）**

| 用例名（spec） | 通过标准（摘要） |
|----------------|------------------|
| kitchen CRUD survives reload and filters do not overlap | 增删改后 reload 仍在；筛选区间不重叠 |
| servings, checklist, timer and completion draft persist | 份数/备料/计时/完成草稿持久化 |
| screens preserve prototype styles with no remote resources | 样式贴近原型；无远程资源 |
| expiry stays zero and generated food assets load offline from bundle | 过期计数逻辑正确；图片离线自 bundle |
| search, favorites and shopping list persist end to end | 搜索/收藏/清单端到端持久化 |
| date filters stay disjoint and preparation checklist restores | 日期筛选互斥；备料清单可恢复 |

**模拟器 UI（`FlowTests.swift` / `artifacts/ios-tests.log`）**

| 用例名 | 通过标准（摘要） |
|--------|------------------|
| testKitchenRestart | 新增食材 → terminate → cold launch → Kitchen 仍可见该食材；有截图附件 |
| testCookingAndScreens | Explore→详情调份→备料→Cook→计时启动/暂停→退出→cold launch→Resume 会话且存在 Resume timer；多帧截图 |

- **通过标准（本条）**：DELIVERY 或本口径中出现上表具名；并注明 **UX-COOK-01～07 为增量，当前未宣称通过**。
- **证据**：更新后的 `DELIVERY.md` 片段或本文件勾选记录；无需新截图。

---

## C. Open / 暂用默认（勿标完成）

| 项 | 口径 |
|----|------|
| Settings 入口 | 齿轮 vs 第四 Tab **未定**；实现可暂用当前默认，报告写 `open` |
| 自动跳步动效与提示文案 | 有可见短提示即可；动效精修 **暂用默认** |
| 发布 / 签名 / TestFlight | **不在本口径放行范围**；不能将开发构建等同上架包 |

---

## D. Codexx 执行顺序建议

1. 实现或核对 R1–R3 与产品行为一致（若现状不符，先改行为再测）。
2. 补 UX-COOK-01～04（Cook 核心）；再 05～07。
3. UX-COOK-08 文档回溯（低成本）。
4. 证据写入 `artifacts/ux-cook/`，在 `DELIVERY.md` 增一节「Cook UX 增量验收」链到本文件；**不要**在未完成 01–04 时把 Cook 交互标成已验收。

---

## E. 签字栏（仅记录，非发布令）

| 角色 | 动作 |
|------|------|
| Karina | 出稿本口径（L3） |
| Codexx | 实现/补测与证据 |
| Jisoo / 用户 | 是否采纳本口径、是否放行后续发布 |

**Karina 不代签发布。**
