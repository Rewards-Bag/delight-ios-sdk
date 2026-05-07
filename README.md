# DelightSDK

DelightSDK is an iOS SDK for showing post-purchase reward popups with local suppression rules and configurable templates.

## Requirements

- iOS 14+
- Swift 5.9+

## Add The Package (SPM)

### Xcode UI

1. Go to **File > Add Packages...**
2. Enter the repository URL (for example: `https://github.com/Rewards-Bag/delight-ios-sdk.git`)
3. Choose a version or branch
4. Add product **`DelightSDK`** to your app target

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/Rewards-Bag/delight-ios-sdk.git", from: "1.0.0")
],
targets: [
    .target(
        name: "YourAppTarget",
        dependencies: [
            .product(name: "DelightSDK", package: "delight-ios-sdk")
        ]
    )
]
```

## Swift Integration

### 1) Import the SDK

```swift
import DelightSDK
```

### 2) Initialize the SDK

Call once on app startup (for example in `.task`, app launch, or bootstrap flow):

```swift
try await Delight.initialize(
    brandName: "rewardsbag-provided-brand-name",
    locale: "en",
    ignoreLocalRulesForTesting: false,
    ignoreCooldownForLocalDevelopment: false,
    consentGranted: true
)
```

### 3) Add the popup presenter

Attach it to a high-level container so the sheet can be presented:

```swift
.overlay {
    DelightPopupPresenter()
}
```

### 4) Show a reward popup

```swift
Delight.showRewardPopup(
    DelightRequestPayload(
        orderId: "",
        email: "",
        firstName: "",
        lastName: "",
        ticketTypes: ["adult"]
    ),
    callbacks: DelightCallbacks(
        onImpression: { rewardId in
            print("Impression:", rewardId ?? "nil")
        },
        onPrimaryClick: { rewardId in
            print("Primary click:", rewardId ?? "nil")
        },
        onDismiss: {
            print("Popup dismissed")
        }
    )
)
```

### 5) Dismiss programmatically (optional)

```swift
Delight.dismiss()
```

## Objective-C Integration

The SDK exposes `DelightObjC` as an Objective-C bridge for initialization and popup control.

### 1) Import generated Swift header

```objc
#import "YourAppModuleName-Swift.h"
```

### 2) Initialize the SDK

```objc
// Set consent first (required for popup/tracking behavior).
// `initialize` does not take a consent argument in Objective-C.
[DelightObjC setConsentGranted:YES];

[DelightObjC initialize:@"rewardsbag-provided-brand-name"
ignoreLocalRulesForTesting:NO
ignoreCooldownForLocalDevelopment:NO
              completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Delight init failed: %@", error.localizedDescription);
    }
}];
```

### 3) Show a reward popup

```objc
[DelightObjC showRewardPopup:nil
                  email:nil
              userToken:nil
              firstName:nil
               lastName:nil
            ticketTypes:@[@"adult"]
           onImpression:^(NSString * _Nullable rewardId) {
    NSLog(@"Impression: %@", rewardId);
}
         onPrimaryClick:^(NSString * _Nullable rewardId) {
    NSLog(@"Primary click: %@", rewardId);
}
              onDismiss:^{
    NSLog(@"Popup dismissed");
}];
```

### 4) Dismiss programmatically (optional)

```objc
[DelightObjC dismiss];
```

## Configuration Options

`Delight.initialize(...)` supports:

- `brandName`: production brand identifier provided by RewardsBag
- `locale`: locale/language code for popup content (default: `"en"`)
- `ignoreLocalRulesForTesting`: bypass suppression logic (QA/testing only)
- `ignoreCooldownForLocalDevelopment`: bypass only 24h cooldown (local development)
- `consentGranted`: set to `true` only when user consent is granted

For `DelightObjC showRewardPopup`, only `ticketTypes` is required. `orderId`, `email`, `userToken`, `firstName`, and `lastName` are optional.

## Consent Controls

- Swift:
  - `Delight.setConsent(granted:)` to gate popup display/tracking at runtime.
  - `Delight.clearLocalData()` to clear locally stored SDK token + suppression history.
- Objective-C:
  - `[DelightObjC setConsentGranted:YES/NO]`
  - `[DelightObjC clearLocalData]`
- When consent is not granted, the SDK is a no-op for popup display and backend tracking.

## Privacy

- `PrivacyInfo.xcprivacy` ships with the SDK. No host-app declarations are required for SDK behavior.
- The SDK does not use any APIs requiring App Tracking Transparency.
- The SDK does not access IDFA, advertising identifiers, or device fingerprinting.

## Notes

- Footer links, CTA handling, and local suppression are handled by the SDK.
- Ensure your host view remains mounted while presenting the popup (`DelightPopupPresenter` must stay in the view hierarchy).
- If the API is unreachable, returns an error, or configuration is invalid, the SDK fires the error callback and does not display the popup.
