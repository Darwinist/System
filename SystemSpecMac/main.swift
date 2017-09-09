//
//  Created by Jon on 9/7/17.
//  Copyright © 2017 Jonathan Cardasis. All rights reserved.
//
//  Uses Darwin's `sysctl` (and a few other C libraries) to retrieve system info
//

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
print("CPU brand: \(System.CPU.brand)")
print("CPU vendor: \(System.CPU.vendor)")
print("CPU cores: \(System.CPU.cores)")
print("CPU is 64bit: \(System.CPU.is64Bit)")

print("\n-- RAM --")
print("RAM: \(System.RAM.ramSize) GB")







