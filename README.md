# Fitness

个人健身管理 iPhone App。代码可在 Windows 上编辑；每次推送到 GitHub 后，GitHub Actions 会使用 macOS 和 Xcode 构建 iOS Simulator 版本。

## 本地开发

Windows 不运行 Xcode。编辑 `Fitness` 中的 SwiftUI 源代码后，提交并推送到 GitHub 即可触发云端构建。

## 首次连接 GitHub

1. 在 GitHub 网站新建一个空仓库，仓库名建议为 `Fitness`，不要勾选 README、`.gitignore` 或许可证。
2. 在此目录执行：

   ```powershell
   git add .
   git commit -m "Initial SwiftUI app and iOS build workflow"
   git branch -M main
   git remote add origin https://github.com/<你的用户名>/Fitness.git
   git push -u origin main
   ```

3. 打开 GitHub 仓库的 **Actions** 页面，等待 **iOS Build** 变为绿色。

GitHub 会要求你通过浏览器完成一次身份验证或使用 Personal Access Token；这是 GitHub 的账号操作，不能由项目文件代替。

## 工作流说明

`.github/workflows/ios-build.yml` 会在 GitHub 的 macOS Runner 中安装 XcodeGen，生成 `Fitness.xcodeproj`，再使用 Xcode 构建 iOS Simulator 版本。当前未包含签名或发布步骤，因此不会创建 IPA、上传 TestFlight，也不需要 Apple Developer 账号。
