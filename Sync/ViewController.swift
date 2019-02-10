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
    func syncSlave(_ slave: SyncSlave, master masterId: UInt32, becameAvailable address: Data) {
        receiveLabel?.text = String(describing: masterId)
        slave.synchronize(withMaster: address)
    }
}
