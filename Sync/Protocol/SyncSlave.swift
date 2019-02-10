//
//  Copyright © 2019 Joakim Stien. All rights reserved.
//

import Foundation
import CocoaAsyncSocket

protocol SyncSlaveDelegate {
    func syncSlave(_ slave: SyncSlave, masterBecameAvailable master: MasterReference)
    func syncSlave(_ slave: SyncSlave, finishedWithOffset offset: TimeInterval, roundTripTime: TimeInterval)
}

struct MasterReference {
    let uniqueId: UInt32
    let address: Data
}

fileprivate struct SyncState {
    let masterUniqueId: UInt32
    let t0: Date
}

class SyncSlave: NSObject {
    var delegate: SyncSlaveDelegate?

    private var udpSocket: GCDAsyncUdpSocket?
    private var ignoredMasters: [UInt32] = []
    private let dispatchQueue = DispatchQueue(label: "syncslave")

    private var syncState: SyncState?

    override init() {
        super.init()

        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: dispatchQueue)
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

    func synchronize(withMaster master: MasterReference) {
        syncState = SyncState(masterUniqueId: master.uniqueId, t0: Date())
        let request = SlaveSyncRequest()
        udpSocket?.send(encode(value: request), toAddress: master.address, withTimeout: 0.0, tag: 0)
    }

    private func handle(syncResponse response: MasterSyncResponse, withT3 t3: Date) {
        guard let state = syncState else {
            print("Unexpected MasterSyncResponse")
            return
        }

        guard state.masterUniqueId == response.uniqueId else {
            print("Unexpected master-ID")
            return
        }

        let ti0 = state.t0.timeIntervalSince1970
        let ti1 = response.t1.timeIntervalSince1970
        let ti2 = response.t2.timeIntervalSince1970
        let ti3 = t3.timeIntervalSince1970

        let offset = ((ti1 - ti0) + (ti2 - ti3)) / 2.0

        let ti1adj = ti1 + offset
        let ti2adj = ti2 + offset
        let rtt = ((ti3 - ti0) - (ti2adj - ti1adj))

        print("----------------------")
        print("Offset:     \(offset)")
        print("Round-trip: \(rtt)")
        print("----------------------")
        print("")

        syncState = nil

        DispatchQueue.main.async { [weak self] in
            if let strongSelf = self {
                strongSelf.delegate?.syncSlave(strongSelf, finishedWithOffset: offset, roundTripTime: rtt)
            }
        }

    }
}

extension SyncSlave: GCDAsyncUdpSocketDelegate {
    func udpSocket(_ sock: GCDAsyncUdpSocket, didConnectToAddress address: Data) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotConnect error: Error?) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didSendDataWithTag tag: Int) { }
    func udpSocket(_ sock: GCDAsyncUdpSocket, didNotSendDataWithTag tag: Int, dueToError error: Error?) { }

    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        let t3 = Date()

        if let packet: MasterSyncResponse = decode(data: data) {
            handle(syncResponse: packet, withT3: t3)
        } else if let packet: MasterAvailabilityPacket = decode(data: data) {
            if !ignoredMasters.contains(packet.uniqueId) {
                print("Received availability notice from master \(packet.uniqueId)")

                let reference = MasterReference(uniqueId: packet.uniqueId, address: address)

                DispatchQueue.main.async { [weak self] in
                    if let strongSelf = self {
                        strongSelf.delegate?.syncSlave(strongSelf, masterBecameAvailable: reference)
                    }
                }
            }
        } else {
            print("Received packet we're unable to parse :(")
        }
    }
}
