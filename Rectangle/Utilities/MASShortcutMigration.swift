/// MASShortcutMigration.swift

import Foundation
import MASShortcut

class MASShortcutMigration {
    
    static func migrate() {
        
        guard let dataTransformer = ValueTransformer(forName: .secureUnarchiveFromDataTransformerName) else { return }
        
        guard let dictTransformer = ValueTransformer(forName: NSValueTransformerName(rawValue: MASDictionaryTransformerName)) else { return }

        for action in WindowAction.active {
            
            if let dataValue = JSONPreferences.shared.object(forKey: action.name) as? Data {
                if let shortcut = dataTransformer.transformedValue(dataValue) {
                    
                    let dictValue = dictTransformer.reverseTransformedValue(shortcut)
                    JSONPreferences.shared.set(dictValue, forKey: action.name)
                }
            }
            
        }
        
    }

    static func syncRenamedSideShortcutAliases(userDefaults: UserDefaults? = nil) {
        func object(_ key: String) -> Any? {
            if let userDefaults { return userDefaults.object(forKey: key) }
            return JSONPreferences.shared.object(forKey: key)
        }
        func set(_ value: Any, _ key: String) {
            if let userDefaults { userDefaults.set(value, forKey: key) }
            else { JSONPreferences.shared.set(value, forKey: key) }
        }
        func remove(_ key: String) {
            if let userDefaults { userDefaults.removeObject(forKey: key) }
            else { JSONPreferences.shared.removeObject(forKey: key) }
        }
        for action in WindowAction.active {
            guard let aliasName = action.aliasName,
                  let aliasValue = object(aliasName)
            else { continue }

            if let currentValue = object(action.name) as? NSObject,
               let aliasObject = aliasValue as? NSObject,
               currentValue.isEqual(aliasObject) {
                remove(aliasName)
                continue
            }

            set(aliasValue, action.name)
            remove(aliasName)
        }
    }
    
}
