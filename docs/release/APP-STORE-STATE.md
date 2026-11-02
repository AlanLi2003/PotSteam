# 海内外 App Store 发布状态

核验日期：2026-11-02。目标：CNrecipe 在中国大陆及海外 App Store 实际可下载；当前未达到。

## 已确认

- 工程版本 1.1 / build 1，Bundle ID `com.cnrecipe.app`，未配置 DEVELOPMENT_TEAM。
- 本机 Xcode 27.1；钥匙串代码签名查询返回 0 valid identities。不能据此生成有效分发签名。
- 当前仅有模拟器验证；模拟器 .app 不可上传 App Store。
- `docs/PRIVACY.md` 是实现披露草稿，尚缺发布主体、支持联系方式、公开政策地址及供应商日志保留核查。
- 现有六道菜为 demo；50 道内容方案尚未完成逐菜审核及实作验证，不应当作已发布目录。
- 上线前50条报告不放行。后续修复记录位于 `artifacts/prelaunch-fixes-2026-11-01/`；work-state 是历史运行记录，不证明进程仍活跃或测试最终通过。

## 按依赖推进

1. 确认开发者会员主体、Team ID、最终 Bundle ID 和 App Store Connect 应用记录；通过 Xcode/官方登录完成授权，不在聊天中传私钥或密码。
2. 完成现有 P0 修复的 Release 复测与原始 QA 数据恢复核对；补齐最低支持系统、真实设备通知/锁屏、真实网络切换和完整候选分发包验收。
3. 完成菜谱原创来源、图片权利、过敏信息、操作与用量审核；以实际通过审核的目录作为发布范围。
4. 准备发布主体与支持信息、公开隐私政策、中英文商店描述、真实候选包截图、年龄分级、隐私标签与出口合规回答。隐私标签须结合实际请求及服务端日志，不直接选择“不收集数据”。
5. 中国大陆：核实并填写有效 App ICP 备案及主体一致信息。海外：确定发行地区，并按地区完成 App Store Connect 所要求的声明。不可用海外上线替代国内上线目标。
6. 签名 Archive → 验证 → TestFlight 真机验收 → 最终提交材料复核 → 用户确认正式提审/发布 → 审核通过 → 核对海内外商店可下载状态。

## 当前需要外部提供的条件

- 开发者账号的主体/会员状态、Team ID，以及可用的 App Store Connect 访问。
- 发布者公开名称、支持邮箱、隐私政策托管地址；中国大陆 App 备案进度。
- 真机验收条件。仓库记录用户当前只有模拟器，不能将模拟器证据替代真机验收。

## 官方依据

- SDK：2026-04-28 起至少 Xcode 26 / iOS 26 SDK。https://developer.apple.com/news/upcoming-requirements/?id=04282026a
- App 信息与中国大陆备案：https://developer.apple.com/help/app-store-connect/reference/app-information/app-information
- 商店状态与备案失效：https://developer.apple.com/help/app-store-connect/reference/app-information/app-and-submission-statuses/

本文件只记录检查和下一步依赖，不构成签名、上传、审核通过或正式发布的证明。
