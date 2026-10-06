# 蜜蜂账本 iOS 版：编译与安装说明

这份说明对应「自动续签」方案：**GitHub 免费 macOS 机器负责编译，Windows 电脑上的
AltServer 负责每 7 天自动帮你续签**。整条链路不需要 Mac 电脑，也不需要付费的
Apple 开发者账号（99 美元/年）。

---

## 一、整体流程

```
本仓库 (GitHub)
   │  push 代码自动触发
   ▼
GitHub Actions 的 macOS 机器
   │  执行 flutter build ios --release --no-codesign
   ▼
未签名 ipa  →  自动发布成 Release（可直接下载）
   │
   ▼
Windows：Sideloadly / AltStore 用免费 Apple ID 签名并安装到 iPhone
   │
   ▼
Windows：AltServer 常驻后台，每 7 天自动续签
```

## 二、免费账号的限制（先说清楚）

| 项目 | 限制 |
| --- | --- |
| 证书有效期 | 7 天，过期要续签（AltServer 可自动完成） |
| 同时安装的侧载 App | 最多 3 个 |
| 每 7 天可注册的 App ID | 最多 10 个 |
| iCloud 同步 | 免费证书不支持，本项目已移除相关权限 |
| iOS 桌面小组件 | 本项目已从 iOS 端移除（免费证书下签名最容易失败），Android 端不受影响 |
| 推送通知 | 免费证书不支持远程推送，App 内的本地提醒不受影响 |

## 三、仓库已经做的准备

1. Bundle ID 改为 `com.shz.beecount.personal`，和官方 App 不冲突，可以共存。
2. 移除了 iCloud 相关权限（`Runner.entitlements` 已清空，`Info.plist` 里的
   `NSUbiquitousContainers` 已删除）——免费证书不支持 iCloud。
3. iOS 小组件扩展不再打进安装包（`project.pbxproj` 里已去掉 Embed 与依赖）。
4. 清掉了原作者的 `DEVELOPMENT_TEAM`，避免签名时用到别人的团队。
5. `.github/workflows/ios-unsigned-ipa.yml`：push 到 main 就自动编译出
   `beecount-ios-unsigned.ipa`，并自动发一个 Release 方便下载。

## 四、怎么触发编译

把代码推到 GitHub 仓库的 `main` 分支即可，或到仓库页面
`Actions → Build iOS IPA (unsigned) → Run workflow` 手动触发。

编译大约 10~20 分钟。完成后：

- 在 `Actions` 里下载 artifact（需要登录），或
- 在仓库 `Releases` 里直接下载 `beecount-ios-unsigned.ipa`（不需要登录）。

## 五、在 iPhone 上安装

1. Windows 装好 `iTunes`（Apple 官网版，不要 Microsoft Store 版）和
   `iCloud for Windows`，再安装 `AltServer`。
2. iPhone 用数据线连电脑，信任此电脑。
3. 用 AltServer 把 `AltStore` 装进 iPhone（需要登录 Apple ID，用免费 ID 即可）。
4. iPhone 设置 → 通用 → VPN与设备管理 → 信任你的开发者证书。
5. 设置 → 通用 → 后台 App 刷新 → 打开。
6. 用 AltStore 打开 `beecount-ios-unsigned.ipa` 安装，或者用 Sideloadly 直接安装。
7. 只要电脑和手机连同一个 Wi-Fi，AltServer 保持运行，AltStore 会在后台自动续签。

## 六、想改回来时

- 想恢复 iOS 桌面小组件：把 `ios/Runner.xcodeproj/project.pbxproj` 里的
  `Embed Foundation Extensions` 那一项和 `PBXTargetDependency` 加回去，
  并恢复 `ios/Runner/Runner.entitlements` 里的 `group.com.shz.beecount.personal`
  （前提是你换成了付费开发者账号）。
- 想恢复 iCloud 同步：同上，需要付费账号。
