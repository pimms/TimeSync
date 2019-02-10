//
//  SyncMaster.swift
//  Sync
//
//  Created by pimms on 10/02/2019.
//  Copyright © 2019 Joakim Stien. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

class SyncMaster: NSObject {
    let uniqueId: UInt32 = arc4random()

    private var broadcastSocket: GCDAsyncUdpSocket?

    override init() {
        super.init()

        broadcastSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        broadcastSocket?.setIPv6Enabled(false)

        do {
            try broadcastSocket?.enableBroadcast(true)
            try broadcastSocket?.bind(toPort: Config.masterPort)
            try broadcastSocket?.beginReceiving()
        } catch {
            print("Failed to initialize broadcast-sending socket: \(error)")
        }
    }

    deinit {
        broadcastSocket?.close()
    }

    func broadcastAvailability() {
        let packet = MasterAvailabilityPacket(uniqueId: uniqueId)

        broadcastSocket?.send(encode(value: packet),
                              toHost: "255.255.255.255",
                              port: Config.broadcastPort,
                              withTimeout: 0.0,
                              tag: 123)
    }
}

extension SyncMaster: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) { }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let t1 = Date()

        if let _ : SlaveSyncRequest = decode(data: data) {
            print("Responding to sync-request")
            respondToSyncRequest(fromSlave: address, withT1: t1)
        } else {
            print("Failed to decode SlaveSyncRequest")
        }
    }

    private func respondToSyncRequest(fromSlave address: Data, withT1 t1: Date) {
        let response = MasterSyncResponse(t1: t1, t2: Date())
        broadcastSocket?.send(encode(value: response), toAddress: address, withTimeout: 0.0, tag: 0)
    }
}
