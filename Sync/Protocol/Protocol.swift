//
//  Copyright © 2019 Joakim Stien. All rights reserved.
//

import Foundation

func encode<T: ProtocolPacket>(value: T) -> Data {
    var mutable = value
    return withUnsafePointer(to: &mutable) { p in
        Data(bytes: p, count: MemoryLayout.size(ofValue: value))
    }
}

func decode<T: ProtocolPacket>(data: Data) -> T? {
    let expectedSize = MemoryLayout<T>.size
    if data.count != expectedSize {
        return nil
    }

    let pointer = UnsafeMutableBufferPointer<T>.allocate(capacity: 1)
    _ = data.copyBytes(to: pointer)

    let t: T = pointer[0]
    pointer.deallocate()

    guard t.magicNumber == Config.magicNumber else {
        print("Unexpected magic number encountered: \(t.magicNumber)")
        return nil
    }

    return t
}

protocol ProtocolPacket {
    var magicNumber: UInt64 { get }
}

struct MasterAvailabilityPacket: ProtocolPacket {
    let magicNumber: UInt64 = Config.magicNumber
    var uniqueId: UInt32
}

struct SlaveSyncRequest: ProtocolPacket {
    let magicNumber: UInt64 = Config.magicNumber
}

struct MasterSyncResponse: ProtocolPacket {
    let magicNumber: UInt64 = Config.magicNumber
    let t1: Date
    let t2: Date
}
