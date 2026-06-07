import Foundation

/// Centralizovaný identifier App Group sdíleného mezi hlavní app a widget extension.
/// Musí přesně odpovídat hodnotě v obou entitlements souborech:
/// - `Kojeni/Kojeni.entitlements`
/// - `Kojeni/KojeniWidgetExtension.entitlements`
///
/// Soubor je v target membership obou targetů (Kojeni + KojeniWidgetExtension),
/// aby ho App Intents (Plan 3 Tasks 8, 9) mohly použít při konstrukci sdíleného
/// SwiftData containeru bez rizika typo v duplikovaném string literálu.
enum AppGroup {
    static let identifier = "group.cz.zapletal.kojeni"
}
