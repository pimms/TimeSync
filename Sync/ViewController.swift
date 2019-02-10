//
//  ViewController.swift
//  Sync
//
//  Created by pimms on 09/02/2019.
//  Copyright © 2019 Joakim Stien. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet var receiveLabel: UILabel?
    @IBOutlet var offsetLabel: UILabel?
    @IBOutlet var rttLabel: UILabel?

    private let slave: SyncSlave = SyncSlave()
    private let master: SyncMaster = SyncMaster()

    override func viewDidLoad() {
        super.viewDidLoad()
        slave.delegate = self
        slave.ignoreMaster(withId: master.uniqueId)
    }

    @IBAction func buttonClicked() {
        print("Sending message")
        master.broadcastAvailability()
    }
}

extension ViewController: SyncSlaveDelegate {
    func syncSlave(_ slave: SyncSlave, masterBecameAvailable master: MasterReference) {
        receiveLabel?.text = String(describing: master.uniqueId)
        slave.synchronize(withMaster: master)
    }

    func syncSlave(_ slave: SyncSlave, finishedWithOffset offset: TimeInterval, roundTripTime: TimeInterval) {
        offsetLabel?.text = String(describing: offset)
        rttLabel?.text = String(describing: roundTripTime)
    }
}
