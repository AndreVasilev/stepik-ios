import Foundation

extension FileManager {
    static var widgetContainerURL: URL {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetConstants.appGroupName
        ) ?? URL(string: "https://google.com").require()
    }
}
