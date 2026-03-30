import NIO
import Foundation

extension ByteBuffer {
    init(data: Data) {
        var buffer = ByteBufferAllocator().buffer(capacity: data.count)
        buffer.writeBytes(data)
        self = buffer
    }

    var data: Data {
        Data(readableBytesView)
    }
}
