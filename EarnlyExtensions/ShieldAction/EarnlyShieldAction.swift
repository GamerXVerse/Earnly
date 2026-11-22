import Foundation
import ManagedSettings

final class EarnlyShieldAction: ShieldActionDelegate {
    override func handle(action: ShieldAction, for application: ApplicationToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action))
    }

    override func handle(action: ShieldAction, for category: ActivityCategoryToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action))
    }

    override func handle(action: ShieldAction, for webDomain: WebDomainToken,
                         completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(response(to: action))
    }

    private func response(to action: ShieldAction) -> ShieldActionResponse {
        guard action == .primaryButtonPressed else { return .none }
        if #available(iOS 26.5, *),
           Bundle.main.object(forInfoDictionaryKey: "EarnlyEnableDirectShieldOpen") as? Bool == true {
            return .openParentalControlsApp
        }
        return .close
    }
}
