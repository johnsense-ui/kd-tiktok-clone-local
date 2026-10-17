# KD Tiktok-Clone · 接本地视频库

原项目：[dks333/Tiktok-Clone](https://github.com/dks333/Tiktok-Clone)（MIT，Swift + Firebase）。
这个副本只做了一件事：**把数据源从 Firebase 换成你自己的视频库**，其余 UI、动画、播放逻辑原样保留。

## 改了什么

| 文件 | 改动 |
| --- | --- |
| `Modules/Home/HomeViewModel.swift` | Firestore → `GET /api/videos?limit=&offset=&sort=newest`；保留 `isLoading / posts / error / getPosts()` 这几个对外接口，`HomeViewController` 一行没动 |
| `Modules/Home/HomeViewController.swift` | `prefetchRowsAt` 里加了续页（原来这个方法是空的），滑到倒数 3 条自动拉下一批 |
| `MainApplication/AppDelegate.swift` | 删掉 `FirebaseApp.configure()` |
| `Network/GetRequests/PostsRequest.swift` | 清空（Firebase 版已不用） |
| `Network/GetRequests/UserRequest.swift` | 清空 |
| `Network/PostRequests/VideoPostRequest.swift` | 改成返回「本地库只读」错误（原先是往 Firebase Storage 上传） |
| `Entity/VideoCache/VideoCacheManager.swift` | 删掉没用到的 `import FirebaseStorage` |
| `Info.plist` | 加 `NSAppTransportSecurity`（http 明文）、`NSLocalNetworkUsageDescription` |
| `Podfile` | 删 Firebase 三个 pod；SnapKit/RxSwift/MarqueeLabel/lottie 全部锁版本 |
| `Pods/`、`Podfile.lock`、`.xcworkspace` | 删除，由 CI 跑 `pod install` 重新生成 |
| `KD Tiktok-Clone.xcodeproj/xcshareddata/xcschemes/KD Tiktok-Clone.xcscheme` | 新增共享 scheme（原项目只有 xcuserdata 私有 scheme，CI 找不到 scheme） |
| `.github/workflows/build-ipa.yml` | 新增，macOS runner 出未签名 ipa |

## 服务器地址

`HomeViewModel.swift` 顶部：

```swift
static let defaultServerBase = "http://172.20.10.3:6688"
```

也可以在运行时改（写进 UserDefaults）：

```swift
HomeViewModel.serverBase = "http://100.78.220.84:6688"
```

## 接口对照

| 用途 | 接口 |
| --- | --- |
| 列表 | `/api/videos?limit=20&offset=0&sort=newest` |
| 播放 | `/api/stream/{id}`（Range，AVPlayer 边下边播） |
| 封面 | `/api/poster/{id}`（原项目走 `VideoCacheManager` 的本地缓存） |
| 连通 | `/api/health` |

## 出 ipa

**方式一：自动化脚本（推荐）**

```powershell
cd F:\新建文件夹\TiktokClone
.\push_and_build.ps1
```

它会：装 gh（没装的话）→ 让你在浏览器授权一次 → 建私有仓库并推送 → 触发 Actions →
等编译完成 → 把 `KD-Tiktok-Clone-unsigned.ipa` 下载到 `F:\新建文件夹\dist\`。

**方式二：手动**

1. 把整个目录传到你的 GitHub 仓库（网页拖拽也行）。
2. Actions → `build-ipa` → Run workflow。
3. 下 Artifacts 里的 `KD-Tiktok-Clone-unsigned-ipa`。

**装到手机**：Sideloadly 选 ipa → 免费 Apple ID → Start → 手机「设置-通用-VPN与设备管理」信任证书。

## 可能踩的坑

- 这是 2020 年的工程（Xcode 12 时代），在 Xcode 15/16 上如果报错，日志里有 `build.log`，Action 失败时也会把它传成 artifact。
- `lottie-ios` 必须留在 3.x：4.x 把 `AnimationView` 改名成 `LottieAnimationView`，`HomeViewController` 会编不过。
- 视频是 HEVC 的也能放（iOS 原生支持）；`compat` 字段为 `broken` 的建议在列表里过滤掉。
