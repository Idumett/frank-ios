@preconcurrency import AVFoundation
import Foundation

@MainActor
protocol ResponseAudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    func play(_ data: Data, finished: @escaping () -> Void) throws
    func stop()
}

enum ResponseAudioError: Error, Equatable {
    case emptyResponse
}

@MainActor
final class ResponseAudioPlayer: NSObject, ResponseAudioPlaying, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var finished: (() -> Void)?

    var isPlaying: Bool { player?.isPlaying == true }

    func play(_ data: Data, finished: @escaping () -> Void) throws {
        guard !data.isEmpty else { throw ResponseAudioError.emptyResponse }
        stop()
        let player = try AVAudioPlayer(data: data)
        self.finished = finished
        self.player = player
        player.delegate = self
        player.prepareToPlay()
        player.play()
    }

    func stop() {
        player?.stop()
        player = nil
        finished = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finish() }
    }

    private func finish() {
        self.player = nil
        let callback = finished
        finished = nil
        callback?()
    }
}
