import EarnlySystems
import Foundation
import ManagedSettings
import ManagedSettingsUI
import UIKit

final class EarnlyShieldConfiguration: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        if let host = Bundle.main.object(forInfoDictionaryKey: "EarnlyHostBundleIdentifier") as? String,
           let group = Bundle.main.object(forInfoDictionaryKey: "EarnlyAppGroupIdentifier") as? String,
           AppleHostShieldRecovery.recover(application, appGroupIdentifier: group, hostBundleIdentifier: host) {
            return ShieldConfiguration(
                title: .init(text: "Earnly is available", color: .label),
                subtitle: .init(text: "Close this screen and reopen Earnly.", color: .label),
                primaryButtonLabel: .init(text: "Close", color: .white),
                primaryButtonBackgroundColor: .systemIndigo
            )
        }
        return configuration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory)
        -> ShieldConfiguration { configuration(shielding: application) }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { configuration() }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory)
        -> ShieldConfiguration { configuration() }

    private func configuration() -> ShieldConfiguration {
        let ink = UIColor(red: 20 / 255, green: 20 / 255, blue: 34 / 255, alpha: 1)
        let canvas = UIColor(red: 246 / 255, green: 247 / 255, blue: 251 / 255, alpha: 1)
        let purple = UIColor(red: 97 / 255, green: 85 / 255, blue: 245 / 255, alpha: 1)
        let direct: Bool
        if #available(iOS 26.5, *) {
            direct = Bundle.main.object(forInfoDictionaryKey: "EarnlyEnableDirectShieldOpen") as? Bool == true
        } else {
            direct = false
        }
        let instructions = "Complete your practice questions in Earnly to unlock more screen time."
        return ShieldConfiguration(
            backgroundColor: canvas,
            icon: UIImage(named: "EarnlyShieldMark"),
            title: .init(text: "Time to earn it.", color: ink),
            subtitle: .init(
                text: direct ? instructions : instructions + " Close this activity and open Earnly from the Home Screen.",
                color: ink
            ),
            primaryButtonLabel: .init(text: direct ? "Open Earnly" : "Close", color: .white),
            primaryButtonBackgroundColor: purple
        )
    }
}
