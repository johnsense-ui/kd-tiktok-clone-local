//
//  VideoPostRequest.swift
//  KD Tiktok-Clone
//
//  Created by Sam Ding on 10/4/20.
//  Copyright © 2020 Kaishan. All rights reserved.
//
//  改：Firebase Storage 上传已移除。本地视频库是只读的，
//  发视频请把文件丢进库目录后让服务端重新扫描。
//

import Foundation

class VideoPostRequest: NetworkModel {

    struct LocalLibraryReadOnly: LocalizedError {
        var errorDescription: String? {
            return "本地视频库是只读的：请把视频放进库目录，服务端会自己扫描"
        }
    }

    static func publishPost(post: Post,
                            videoURL: URL,
                            success: @escaping Success,
                            failure: @escaping Failure) {
        failure(LocalLibraryReadOnly())
    }
}
