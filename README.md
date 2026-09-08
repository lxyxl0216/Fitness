# Fitness

供个人使用的离线 iPhone 健身记录 App，支持 iOS 17 及以上。Windows 编辑源码，GitHub Actions 的 macOS/Xcode 负责编译与测试。

## 第一版功能

- **今日**：本周训练次数与完成组数、最近体重、从模板开始或继续未结束的训练。
- **计划**：3 个预置推/拉/腿模板、20 个常见动作；新建、编辑、排序、删除模板，调整每个动作的默认组数。
- **训练**：重量与次数逐组输入、完成勾选、增删组、上次训练参考；每次编辑自动保存，重启可继续。
- **历史**：结束训练时仅归档已完成组；查看动作明细、容量与时长，支持确认后删除。
- **身体**：体重、可选体脂和腰围、测量日期；修改和删除记录，展示最近 30 条体重趋势。

首次使用：打开「今日」→ 开始一个模板 → 输入重量和次数 → 勾选已完成组 → 结束训练 → 保存到历史。体重在「身体」页录入。需要自己的动作组合时，到「计划」页点 +。

重量统一为 kg。自重动作填 0；哑铃按单只重量记录，并始终使用相同口径。容量为已完成组的录入重量乘以次数之和，不代表运动消耗或自重动作负荷。

## 数据与限制

数据在设备的 Application Support/Fitness/fitness.json 中，以 Codable JSON 原子保存。写入成功后才更新内存；读取失败会保留原文件并提示重试，不会自动清空。无需账号或服务器。此版本未提供独立备份导出；卸载 App 可能丢失本机记录。

尚未接入 3D 人体、动作 GIF、照片、自动加重建议、HealthKit、iCloud 同步、Apple Watch。没有下载图片中第三方仓库的资源。

## 开发与验证

GitHub 仓库：https://github.com/lxyxl0216/Fitness

核心模型与存储位于 `Fitness/Core`，SwiftUI 页面位于 `Fitness/Views`。根目录 `Package.swift` 只编译同一份核心代码，供 macOS 执行数据与持久化测试。

在 macOS 上：

```sh
brew install xcodegen
swift test
xcodegen generate
xcodebuild -project Fitness.xcodeproj -scheme Fitness -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Windows 上提交并推送到 main 后，Actions 自动执行核心测试、iOS 编译和 iPhone 模拟器 UI 测试。UI 用例覆盖训练草稿恢复、归档、重启后读取历史和身体数据、自建模板。构建记录中的 `Fitness-test-results` 下载包包含 `.xcresult` 与导出的页面截图，保留 7 天。

当前工作流构建和测试模拟器版本，没有签名、IPA 或 TestFlight 发布步骤；构建通过不等于已安装到 iPhone。
