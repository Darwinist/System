//
//  SystemSpeciOS
//
//  Created by Jon Cardasis on 9/9/17.
//  Copyright © 2017 Jonathan Cardasis. All rights reserved.
//

import UIKit

@UIApplicationMain
class Application: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        printSystemSpecs()
        return true
    }
    
    func printSystemSpecs() {
        print("-- Networking Info --")
        print("Wifi Enabled: \(System.Network.wifiEnabled())")
        print("Wifi Connected: \(System.Network.wifiConnected())")
        print("Network SSID: \(System.Network.networkName ?? "nil")")
        
        print("\n-- System Info --")
        print("Hostname: \(System.hostName)")
        print("CPU model: \(System.CPU.model)")
        print("System mode: \(System.model)")
        print("OS type: \(System.osType)")
        
        print("\n-- CPU Info --")
        print("Available CPUs: \(System.CPU.availableCPUs)")
        print("CPU is 64bit: \(System.CPU.is64Bit)")
    }
}

