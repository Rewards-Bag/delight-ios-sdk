# DelightSDK

DelightSDK is an iOS SDK that presents post-purchase reward popups with local suppression logic and configurable templates.

## Requirements

- iOS 16+
- Swift 5.9+

## Installation (Swift Package Manager)

In Xcode:

1. **File > Add Packages...**
2. Enter your repository URL (for example: `https://github.com/Rewards-Bag/delight-ios-sdk.git`)
3. Select the version/branch
4. Add product **`DelightSDK`** to your app target

## Quick Start

```swift
import SwiftUI
import DelightSDK

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Show Reward") {
                Delight.showReward(
                    DelightRequestPayload(
                        orderId: nil,
                        email: nil,
                        firstName: nil,
                        lastName: nil,
                        ticketTypes: ["adult"]
                    )
                )
            }
        }
        .overlay {
            DelightPopupPresenter()
        }
        .task {
            try? await Delight.initialize(
                brandName: "rewardsbag-provided-brand-name"
            )
        }
    }
}
```

## Initialization Options

`Delight.initialize(...)` supports:

- `brandName`: production brand identifier provided by RewardsBag

## Notes

- Footer links, CTA handling, and local suppression are all handled by the SDK.
