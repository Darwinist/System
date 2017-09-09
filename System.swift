//
//  Created by Jon on 9/9/17.
//  Copyright © 2017 Jonathan Cardasis. All rights reserved.
//
//  Uses Darwin's `sysctl` (and a few other C libraries) to retrieve system info
//  Note: will need a bridging header to `#include <ifaddrs.h>`.

import Foundation
#if os(OSX)
    import CoreWLAN
#elseif os(iOS) || os(tvOS)
    import SystemConfiguration.CaptiveNetwork
#endif


class System {
    
    enum DarwinError: Error {
        case unknown
        case malformedUTF8
        case invalidSize
        case posixError(POSIXErrorCode)
    }
    
    /// Uses sysctl to return a byte array of data for given keys to retrieve system configurations
    fileprivate static func dataForKeys(_ keys: [Int32]) throws -> [Int8] {
        
        return try keys.withUnsafeBufferPointer { keysPointer throws -> [Int8] in
            // Interface with sysctl to first retrieve the size of the byte array
            var requiredSize: Int = 0
            guard Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), nil, &requiredSize, nil, 0) == 0 else {
                throw POSIXErrorCode(rawValue: errno).map { DarwinError.posixError($0) } ?? DarwinError.unknown
            }
            
            // Retrieve data now that the appropriate size is known
            let data = [Int8](repeating: 0, count: requiredSize)
            let resultCode = data.withUnsafeBufferPointer() { dataPointer -> Int32 in
                return Darwin.sysctl(UnsafeMutablePointer<Int32>(mutating: keysPointer.baseAddress), UInt32(keys.count), UnsafeMutableRawPointer(mutating: dataPointer.baseAddress), &requiredSize, nil, 0)
            }
            
            guard resultCode == 0 else {
                throw POSIXErrorCode(rawValue: errno).map { DarwinError.posixError($0) } ?? DarwinError.unknown
            }
            
            return data
        }
    }
    
    /// Returns a string representation of sysctl for given keys
    fileprivate static func stringForKeys(_ keys: [Int32]) throws -> String {
        let utf8DataString = try dataForKeys(keys).withUnsafeBufferPointer() { dataPointer -> String? in
            dataPointer.baseAddress.flatMap { String(validatingUTF8: $0) }
        }
        
        guard let string = utf8DataString else {
            throw DarwinError.malformedUTF8
        }
        
        return string
    }
    
    /// Convert a string like "machdep.cpu.brand_string" to an array of integer keys reference values
    fileprivate static func keysForName(_ name: String) throws -> [Int32] {
        var keysBufferSize = Int(CTL_MAXNAME)
        var keysBuffer = [Int32](repeating: 0, count: keysBufferSize)
        try keysBuffer.withUnsafeMutableBufferPointer() { (bytePointer: inout UnsafeMutableBufferPointer<Int32>) throws in
            try name.withCString() { (cString: UnsafePointer<Int8>) throws in
                guard sysctlnametomib(cString, bytePointer.baseAddress, &keysBufferSize) == 0 else {
                    throw POSIXErrorCode(rawValue: errno).map { DarwinError.posixError($0) } ?? DarwinError.unknown
                }
            }
        }
        
        // truncate range if needed
        if keysBuffer.count > keysBufferSize {
            keysBuffer.removeSubrange(keysBufferSize..<keysBuffer.count)
        }
        return keysBuffer
    }
    
    /// Will rebind data as the memory type provided. Throws errors if memory type expected is invalid
    fileprivate static func interpretDataAsType<T>(_ data: [Int8], type: T.Type) throws -> T {
        if data.count != MemoryLayout<T>.size {
            throw DarwinError.invalidSize
        }
        
        return try data.withUnsafeBufferPointer() { bufferPointer throws -> T in
            guard let baseAddress = bufferPointer.baseAddress else { throw DarwinError.unknown }
            return baseAddress.withMemoryRebound(to: T.self, capacity: 1) { $0.pointee }
        }
    }
}


/// System + General
extension System {
    
    /// Hostname of the machine
    /// Retrived from: (System Preferences -> Sharing -> Computer Name) or (Settings -> General -> About -> Name)
    /// ex. "MacBookPro.local" or "Jon-iPhone"
    static var hostName: String {
        return try! stringForKeys([CTL_KERN, KERN_HOSTNAME])
    }
    
    /// OS type
    /// ex. "Darwin"
    static var osType: String {
        return try! System.stringForKeys([CTL_KERN, KERN_OSVERSION])
    }
    
    /// Model of the machine
    /// ex. "MacBookPro11,2" or "iPhone7,1"
    static var model: String {
        // Due to a known inverse key match since beginning of iOS, the model and machine keys are flipped for iOS vs macOS
        #if os(iOS) && !arch(x86_64) && !arch(i386)
            return try! stringForKeys([CTL_HW, HW_MACHINE])
        #else
            return try! stringForKeys([CTL_HW, HW_MODEL])
        #endif
    }
}


/// System + CPU
extension System {
    
    class CPU {
        
        /// CPU model info
        /// ex. "x86_64" or "N71mAP"
        static var model: String {
            // Due to a known inverse key match since beginning of iOS, the model and machine keys are flipped for iOS vs macOS
            #if os(iOS) && !arch(x86_64) && !arch(i386)
                return try! System.stringForKeys([CTL_HW, HW_MODEL])
            #else
                return try! System.stringForKeys([CTL_HW, HW_MACHINE])
            #endif
        }
        
        /// Number of available (physical and virtual) cpus for the system
        static var availableCPUs: Int32 {
            let sysData = try! System.dataForKeys([CTL_HW, HW_AVAILCPU])
            return try! System.interpretDataAsType(sysData, type: Int32.self)
        }
        
        
        // MARK: - macOS Specific Properties
        
        /// Brand of the cpu
        /// ex. "Intel(R) Core(TM) i7-4770HQ CPU @ 2.20GHz"
        #if os(macOS) // MACHDEP is only defined for mac architecture
        static var brand: String {
            let keys = try! System.keysForName("machdep.cpu.brand_string")
            return try! System.stringForKeys(keys)
        }
        
        /// Vendor of the cpu
        /// ex. "GenuineIntel"
        static var vendor: String {
            let keys = try! System.keysForName("machdep.cpu.vendor")
            return try! System.stringForKeys(keys)
        }
        
        /// Number of physical machine cores
        static var cores: Int32 {
            let keys = try! System.keysForName("machdep.cpu.core_count")
            let sysData = try! System.dataForKeys(keys)
            return try! System.interpretDataAsType(sysData, type: Int32.self)
        }
        #endif
        
        /// Whether the processor is 64 bit
        static var is64Bit: Bool {
            // size of Int guaranteed to be same as platform word size (Swift)
            return MemoryLayout<Int>.size == MemoryLayout<Int64>.size
        }
    }
}


/// System + Network
extension System {
    
    class Network {
        
        private struct BroadcomWifiInterfaces{
            static let standardWifi         = "en0"      //Standard Wifi Interface
            static let tethering            = "ap1"      //Access point interface used for Wifi tethering
            static let tetheringConnected   = "bridge100"   //Interface for communicating to connected device via tether (Seems like the interface is always bridge100)
            static let awdl                 = "awdl0"    //Apple Wireless Direct Link interface - used for AirDrop, GameKit, AirPlay, etc.
        }
        
        /// The networks SSID
        /// Is nil if no network ssid is found. Such as when wifi is disabled
        static var networkName: String? {
            #if os(iOS) || os(tvOS)
                guard let interfaceNames = CNCopySupportedInterfaces() as? [String] else {
                    return nil
                }
                return interfaceNames.flatMap({ name in
                    
                    guard let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String:AnyObject] else {
                        return nil
                    }
                    guard let ssid = info[kCNNetworkInfoKeySSID as String] as? String else {
                        return nil
                    }
                    return ssid
                }).first
            #elseif os(macOS)
                return CWWiFiClient()?.interface(withName: nil)?.ssid()
            #endif
        }
        
        #if os(iOS)
        
        #endif
        
        /// If the device has Wifi turned on
        static func wifiEnabled() -> Bool {
            if System.activeNetworkInterfaces().filter({ $0 == BroadcomWifiInterfaces.awdl }).count > 1 {
                //If more than 1 awdl10 interface, then wifi is turned on
                return true
            }
            return false
        }
        
        /// If the device is connected to a Wifi network
        static func wifiConnected() -> Bool {
            if System.activeNetworkInterfaces().filter({ $0 == BroadcomWifiInterfaces.standardWifi }).count > 1 {
                //If more than 1 en0 interface then its connected
                return true
            }
            return false
        }
        
        #if os(iOS)
        /// If the device is currently tethering its connection to another device
        static func isTethering() -> Bool {
        if System.activeNetworkInterfaces().filter({ $0.range(of: BroadcomWifiInterfaces.tetheringConnected) != nil }).count > 0 {
        //If theres a bridge100 interface, then theres at least one connected device
        return true
        }
        return false
        }
        #endif
    }
    
    fileprivate static func activeNetworkInterfaces() -> [String]{
        var interfaces = [String]()
        
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] } //obtain network interfaces
        guard let firstAddr = ifaddr else { return [] }
        
        for pointer in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee as ifaddrs
            
            if (Int32(interface.ifa_flags) & IFF_UP) == IFF_UP {
                let interfaceName = String(cString: interface.ifa_name)
                interfaces.append(interfaceName)
            }
        }
        freeifaddrs(ifaddr)
        
        return interfaces
    }
}


/// System + RAM (macOS only)
extension System {
    
    #if os(macOS)
    class RAM {
        
        /// Size (in gb) of system ram available
        static var ramSize: UInt32 {
            let sysData = try! System.dataForKeys([CTL_HW, HW_MEMSIZE])
            let memInBytes = try! System.interpretDataAsType(sysData, type: UInt64.self)
            return UInt32(memInBytes / 1024 / 1024 / 1024) // result in GB
        }
    }
    #endif
}
