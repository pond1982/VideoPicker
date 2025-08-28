//
//  ContentView.swift
//  VideoPicker
//
//  Created by Pondd Air on 29/8/2568 BE.
//

import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct ContentView: View {
    @State private var selectedVideo: PhotosPickerItem? = nil
    @State private var isPickingVideo = false
    @State private var videoInfo: String? = nil
    @State private var videoURL: URL? = nil
    @State private var player: AVPlayer? = nil
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let player {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.width * 9 / 16)
                        .cornerRadius(0)
                }
                Spacer(minLength: 24)
                Button("Open Video") {
                    openVideo()
                }
                .font(.title)
                .photosPicker(isPresented: $isPickingVideo, selection: $selectedVideo, matching: .videos)
                .onChange(of: selectedVideo) { item in
                    if let item {
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [])
                                try? AVAudioSession.sharedInstance().setActive(true)
                                
                                let sizeMB = Double(data.count) / 1_048_576.0
                                let info = String(format: "Size: %.2f MB", sizeMB)
                                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                                try? data.write(to: tempURL)
                                
                                let asset = AVAsset(url: tempURL)
                                let item = makePixelatedPlayerItem(for: asset)
                                let newPlayer = AVPlayer(playerItem: item)
                                newPlayer.play()
                                await MainActor.run {
                                    videoInfo = info
                                    videoURL = tempURL
                                    player = newPlayer
                                }
                            }
                        }
                    }
                }
                if let videoInfo {
                    Text(videoInfo)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                Spacer()
            }
            .padding()
        }
    }
    
    private func openVideo() {
        isPickingVideo = true
    }
    
    private func makePixelatedPlayerItem(for asset: AVAsset, scale: Float = 24) -> AVPlayerItem {
        let item = AVPlayerItem(asset: asset)
        let composition = AVVideoComposition(asset: asset) { request in
            let source = request.sourceImage.clampedToExtent()
            guard let filter = CIFilter(name: "CIPixellate") else {
                request.finish(with: request.sourceImage, context: nil)
                return
            }
            filter.setValue(source, forKey: kCIInputImageKey)
            filter.setValue(scale, forKey: kCIInputScaleKey)
            let output = filter.outputImage!.cropped(to: request.sourceImage.extent)
            request.finish(with: output, context: nil)
        }
        item.videoComposition = composition
        return item
    }
}

#Preview {
    ContentView()
}
