# CNrecipe API v1

开发项目：`mlrerdrnwuudjsnjodkp`（ap-southeast-1，PostgreSQL 17.11）。不使用 SelfForge。

API 根地址：`https://mlrerdrnwuudjsnjodkp.supabase.co/functions/v1/cnrecipe`。

| 方法与路径 | 用途 | 认证 |
| --- | --- | --- |
| GET /v1/health | 服务及版本 | 公开 |
| GET /v1/catalog?q=&filter=All | 搜索及筛选；返回完整离线菜谱 | 公开；当前 App 不附用户 JWT |
| GET /v1/recipes/{id}?version=1 | 指定不可变内容版本 | 公开 |
| POST /v1/sync | 保留的未来可选用户同步契约；当前 App 不调用 | 必须有真实用户 JWT |

网关 `apikey` 使用 publishable key。2026-11-01 的产品决定是当前 App 无需登录：登录/账号同步入口隐藏，不自动恢复已有会话，不调用用户同步或 Auth 登录端点。Supabase 继续提供菜谱、图片与数据库。客户端不持有 service role 或管理令牌；Explore 受限桥接不提供身份凭证或任意原生操作。

现有私有接口和 RLS 保留供未来可选同步使用：`Authorization: Bearer` 使用真实用户 access token，API 在私有路由验证 Auth 身份后以该用户权限执行 SQL。保留实现不代表已经对当前用户开放或完成真实双设备验收。

筛选：All / Quick（≤15 分钟）/ Beginner / Vegetarian / Noodles（原有 Rice & Noodles 分类）/ Pantry。The public catalog returns 50 recipes in the published display_order (2026-11-02).当前 App 将用户输入的搜索文字 `q` 和公共筛选条件发给菜谱 API；库存与过敏偏好在客户端匹配/标注，不随每次查询发到云端。库存匹配沿用名称精确匹配及已有标准食材 ID，不新增推荐或食材替换规则。

服务端保留的 `pantry`、`allergens` 参数契约以 `|` 分隔，供未来同步版本或其他经授权调用方使用；当前 App 不用这些参数上传本机库存或过敏偏好。

菜谱包含稳定 recipe / ingredient / step ID 和版本号。`quotes` 是服务端为 1–8 份、US / Metric 产生的 16 个用量投影。离线客户端选择对应投影，不另写换算规则。开始烹饪时保存完整菜谱、步骤、用量及版本快照；进行中的会话不随后台内容更改。

## 保留的未来同步契约（当前关闭）

以下请求和冲突处理规则保留，不是当前 App 的用户数据写入路径。当前收藏、库存、购物、偏好、历史与烹饪会话只保存在本地。

同步请求：

```json
{"cursor":0,"timezone":"Asia/Shanghai","operations":[{"id":"客户端操作 UUID","kind":"inventory","entityId":"稳定条目 ID","action":"put","baseRevision":0,"data":{"name":"Tomatoes","qty":"2","group":"Produce","storage":"Fridge","type":"Review on","added":"2026-10-31","until":""}}]}
```

kind：inventory / shopping / favorite / record / preferences。
action：put / delete / shopping.add / shopping.recipe。

同一操作 UUID 的重试返回原回执，不重复写入。`baseRevision` 失配返回 conflict，客户端保留本地编辑供用户选择；非法字段返回 rejected。离线连续编辑通过 `dependsOn` 指向前一个操作 UUID，服务端检查先前回执并解决购物条目的规范 ID。删除采用墓碑。每个用户的批次在事务级锁内串行处理，用户行由 RLS 隔离。响应包含 cursor、entities、receipts。单批最多 100 个操作、512 KB，失败项不影响同批其他有效操作。

购物添加按标准食材 ID 或规范名称去重，保留已购状态；重新添加已删除条目会产生新版本。烹饪记录由服务端装入可信的历史菜谱快照，并保持不可变。当前规则沿用旧版集合合并，不把两个配方的用量自动相加。

## 登录与同步的重新开放条件

Supabase Auth、PKCE/Magic Link 代码、账号隔离缓存和同步/RLS 保留供将来复用。此前 Magic Link 工作未完成实际邮件回跳或双设备验收；用户此前授权的一封测试邮件未发送。本轮不继续配置 SMTP、发送登录邮件或把登录作为启动门槛。

当前隐藏登录和账号同步入口，并停止自动会话恢复与用户数据上传；已有账号缓存和 Keychain 项保留，不删除、不擅自导入设备数据。后续只有用户确实提出换机数据恢复或多设备同步需求时，再安排开放，继续使用 Supabase Auth，不更换登录服务。

开放前必须全部完成：

1. **可靠 SMTP**：选定服务商、验证发信身份，验证真实投递、错误/过期/重放、重发及限流，不把默认团队邮件服务视为生产发信能力。
2. **真实双设备测试**：同账号两台设备的创建、编辑、删除、离线恢复、冲突、冷启动、退出/换号隔离；不能以 mock 或单模拟器代替。
3. **账号删除**：提供可用的删除入口，验证会话处置、云端用户数据删除和本地缓存处理，说明可保留数据与原因。
4. **隐私政策**：发布面向用户的政策与联系入口，内容和 App Store 披露须对应实际发布二进制与服务配置。
5. **数据生命周期说明**：明确本地导入、同步、保存时长、日志、备份、注销/删除及异常恢复规则，并验证旧数据迁移，不仅翻开配置开关。

SMTP、真实登录和双设备同步尚未完成，不阻塞本地核心菜谱体验的验收；它们仍是未来开放可选同步的前置条件。

图片桶 `recipe-images`：公开菜谱照片读取、5 MB JPEG 限制，无普通客户端写入策略。固定路径 `recipes/{recipeId}/v{version}.jpg`。原生缓存对象照片，V1 随包照片提供首次离线回退。六张 V1 照片已用管理登录上传，公开 URL 下载的 SHA-256 均与本地一致，见本次 `image-upload.log`。

当前使用设备本地 v2 文件；历史账号文件保持隔离，不自动恢复会话或合并数据。旧 v1 原文件不覆盖，迁移产生校验备份；坏文件阻止写入并显示恢复入口。计时器、当前会话和全部用户实体本地保存；关闭完成页不会自动保存历史。本地备份不等于已验证的换机、卸载恢复或 iCloud 备份能力。

验证命令与证据以 `docs/MIGRATION-PLAN.md` 和本次 artifacts 记录为准；旧整套 WebView 测试不代表原生页面已验收。

2026-11-02 release: 50 English recipes, 800 serving/unit projections, and 50 original typographic covers. Chinese names remain in chineseName. quantityMode=toTaste/asNeeded produces a text display and numeric zero; ordinary measured quantities remain positive. scalingMode=wholeBatch rounds up complete whole-item batches. No content-status badge is displayed. Release evidence and rollback: artifacts/classic-50-release/.

2026-11-02 media revision: all 50 active recipes now use individual generated food images on new immutable imageKey paths; the previous title-cover versions remain archived. Active batch: classic-50-en-photos.json. Equipment icons cover 20 types and ingredient icons cover all 119 canonical ingredients. Verification: artifacts/recipe-media-fix/.
