//
//  Interface.swift
//  
//
//  Created by Saroar Khandoker on 06.12.2021.
//

import Dependencies
import Foundation

extension DependencyValues {
  public var userDefaults: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}

public struct UserDefaultsClient {
  public var boolForKey: @Sendable (String) -> Bool
  public var dataForKey: @Sendable (String) -> Data?
  public var doubleForKey: @Sendable (String) -> Double
  public var integerForKey: @Sendable (String) -> Int
  public var stringForKey: @Sendable (String) -> String
  public var remove: @Sendable (String) async -> Void
  public var setBool: @Sendable (Bool, String) async -> Void
  public var setData: @Sendable (Data?, String) async -> Void
  public var setDouble: @Sendable (Double, String) async -> Void
  public var setInteger: @Sendable (Int, String) async -> Void
  public var setString: @Sendable (String, String) async -> Void

  public var hasShownFirstLaunchOnboarding: Bool {
    self.boolForKey(hasShownFirstLaunchOnboardingKey)
  }

  public func setHasShownFirstLaunchOnboarding(_ bool: Bool) async {
    await self.setBool(bool, hasShownFirstLaunchOnboardingKey)
  }

  public var installationTime: Double {
    self.doubleForKey(installationTimeKey)
  }

  public func setInstallationTime(_ double: Double) async {
    await self.setDouble(double, installationTimeKey)
  }
}

let hasShownFirstLaunchOnboardingKey = "hasShownFirstLaunchOnboardingKey"
let installationTimeKey = "installationTimeKey"
