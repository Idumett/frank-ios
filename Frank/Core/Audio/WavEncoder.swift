import Foundation

enum WavEncoder {
    static func encode(_ chunks: [CapturedAudioChunk]) -> Data? {
        guard let first = chunks.first, first.sampleRate > 0 else { return nil }
        let samples = chunks.flatMap(\.samples)
        guard !samples.isEmpty else { return nil }

        let pcm = CapturedAudioChunk(samples: samples, sampleRate: first.sampleRate).pcm16Data
        let sampleRate = UInt32(first.sampleRate.rounded())
        let byteRate = sampleRate * 2
        var data = Data()
        data.appendASCII("RIFF")
        data.appendLE(UInt32(36 + pcm.count))
        data.appendASCII("WAVEfmt ")
        data.appendLE(UInt32(16))
        data.appendLE(UInt16(1))
        data.appendLE(UInt16(1))
        data.appendLE(sampleRate)
        data.appendLE(byteRate)
        data.appendLE(UInt16(2))
        data.appendLE(UInt16(16))
        data.appendASCII("data")
        data.appendLE(UInt32(pcm.count))
        data.append(pcm)
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ value: String) {
        append(value.data(using: .ascii) ?? Data())
    }

    mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
