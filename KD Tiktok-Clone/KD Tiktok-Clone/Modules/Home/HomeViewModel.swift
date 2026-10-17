//
//  HomeViewModel.swift
//  KD Tiktok-Clone
//
//  Created by Sam Ding on 9/8/20.
//  Copyright © 2020 Kaishan. All rights reserved.
//
//  改：数据源由 Firebase Firestore 换成「本地视频库」HTTP 接口。
//  对外接口（isLoading / posts / error / getPosts / setAudioMode）保持不变，
//  HomeViewController 不需要跟着改。
//

import Foundation
import RxSwift
import AVFoundation

final class HomeViewModel: NSObject {

    // MARK: - 本地视频库地址

    /// 首次启动用这个；改过就记住
    static let defaultServerBase = "http://172.20.10.3:6688"

    static var serverBase: String {
        get {
            let v = (UserDefaults.standard.string(forKey: "dzc.serverBase") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? defaultServerBase : v
        }
        set {
            var t = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            while t.hasSuffix("/") { t.removeLast() }
            UserDefaults.standard.set(t, forKey: "dzc.serverBase")
        }
    }

    // MARK: - 对外状态

    private(set) var currentVideoIndex = 0

    let isLoading = BehaviorSubject<Bool>(value: true)
    let posts = PublishSubject<[Post]>()
    let error = PublishSubject<Error>()

    // MARK: - 内部

    private var docs = [Post]()
    private var offset = 0
    private var total = Int.max
    private var isFetching = false
    private let pageSize = 20
    private let session: URLSession

    enum LocalFeedError: LocalizedError {
        case badURL
        case badPayload

        var errorDescription: String? {
            switch self {
            case .badURL:
                return "服务器地址无效：\(HomeViewModel.serverBase)"
            case .badPayload:
                return "服务器返回的不是预期数据（\(HomeViewModel.serverBase)/api/videos）"
            }
        }
    }

    // MARK: - 生命周期

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.waitsForConnectivity = false
        session = URLSession(configuration: config)
        super.init()
        getPosts(pageNumber: 1, size: 20)
    }

    // Setup Audio
    func setAudioMode() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch (let err) {
            print("setAudioMode error:" + err.localizedDescription)
        }
    }

    // MARK: - 拉列表

    /// 原来的签名保留（调用方传 pageNumber/size），内部按 offset 翻页
    func getPosts(pageNumber: Int, size: Int = 20) {
        guard !isFetching else { return }
        guard offset < total else { return }

        let base = HomeViewModel.serverBase
        guard let url = URL(string: "\(base)/api/videos?limit=\(pageSize)&offset=\(offset)&sort=newest") else {
            isLoading.onNext(false)
            error.onNext(LocalFeedError.badURL)
            return
        }

        isFetching = true
        if offset == 0 {
            isLoading.onNext(true)
        }

        session.dataTask(with: url) { [weak self] data, _, err in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.isFetching = false

                if let err = err {
                    self.isLoading.onNext(false)
                    self.error.onNext(err)
                    return
                }

                guard let data = data,
                      let decoded = try? JSONDecoder().decode(LocalFeedResponse.self, from: data) else {
                    self.isLoading.onNext(false)
                    self.error.onNext(LocalFeedError.badPayload)
                    return
                }

                self.total = decoded.total
                self.offset += decoded.items.count

                for item in decoded.items {
                    self.docs.append(HomeViewModel.makePost(from: item))
                }

                self.posts.onNext(self.docs)
                self.isLoading.onNext(false)
            }
        }.resume()
    }

    /// 服务端 JSON → 这个项目原来的 Post 模型
    private static func makePost(from item: LocalFeedItem) -> Post {
        let base = serverBase
        let stream = URL(string: "\(base)/api/stream/\(item.id)")

        var caption = item.caption ?? ""
        if caption.isEmpty { caption = item.title ?? "" }

        var author = item.authorName ?? ""
        if author.isEmpty { author = "未知作者" }

        return Post(id: String(item.id),
                    video: "",
                    videoURL: stream,
                    videoFileExtension: "mp4",
                    videoHeight: item.height ?? 1920,
                    videoWidth: item.width ?? 1080,
                    autherID: item.authorId ?? "",
                    autherName: author,
                    caption: caption,
                    music: "原声",
                    likeCount: item.digg ?? 0,
                    shareCount: 0,
                    commentID: "")
    }
}

// MARK: - 服务端结构

struct LocalFeedResponse: Decodable {
    let total: Int
    let offset: Int
    let limit: Int
    let items: [LocalFeedItem]
}

struct LocalFeedItem: Decodable {
    let id: Int
    let title: String?
    let caption: String?
    let authorName: String?
    let authorId: String?
    let digg: Int?
    let width: Int?
    let height: Int?
    let duration: Double?
}

// MARK: - Manage User Interaction in the screen
extension HomeViewModel {
    func likeVideo() {
    }

    func commentVideo(comment: String) {
    }
}
