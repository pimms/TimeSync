//
//  Copyright © 2019 Joakim Stien. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

protocol SyncSlaveDelegate {
    func syncSlave(_ slave: SyncSlave, master masterId: UInt32, becameAvailable address: Data)
}

class SyncSlave: NSObject {
    var delegate: SyncSlaveDelegate?

    private var udpSocket: GCDAsyncUdpSocket?
    private var ignoredMasters: [UInt32] = []

    override init() {
        super.init()

        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        udpSocket?.setIPv6Enabled(false)

        do {
            try udpSocket?.bind(toPort: Config.broadcastPort)
            try udpSocket?.beginReceiving()
            try udpSocket?.enableBroadcast(true)
        } catch {
            print("Failed to initialize broadcast listening-socket: \(error)")
        }
    }

    deinit {
        udpSocket?.close()
    }

    func ignoreMaster(withId id: UInt32) {
        ignoredMasters.append(id)
    }

    func synchronize(withMaster address: Data) {
        let request = SlaveSyncRequest()
        udpSocket?.send(encode(value: request), toAddress: address, withTimeout: 0.0, tag: 0)
    }
}

extension SyncSlave: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) { }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        if let packet: MasterSyncResponse = decode(data: data) {
            print("woo, received sync response :D \(packet)")
        } else if let packet: MasterAvailabilityPacket = decode(data: data) {
            if !ignoredMasters.contains(packet.uniqueId) {
                print("Received availability notice from master \(packet.uniqueId)")
                delegate?.syncSlave(self, master: packet.uniqueId, becameAvailable: address)
            }
        } else {
            print("Received packet we're unable to parse :(")
        }
    }
}
