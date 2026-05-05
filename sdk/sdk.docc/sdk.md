# ``DelightSDK``

Post-purchase reward popup SDK for iOS apps.

## Overview

Use DelightSDK to initialize campaign configuration and present reward popups from your app.

Typical integration flow:

1. Initialize once at app startup with ``Delight/initialize(brandName:cdnBaseURL:useBundledConfig:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:)``.
2. Mount ``DelightPopupPresenter`` in your root SwiftUI view hierarchy.
3. Trigger a popup with ``Delight/showRewardPopup(_:callbacks:)``.
4. Optionally dismiss with ``Delight/dismiss()``.

For Objective-C integrations, use ``DelightObjC`` bridge methods.

## Swift Quick Start

```swift
import SwiftUI
import DelightSDK

struct ContentView: View {
    var body: some View {
        VStack {
            Button("Show Reward") {
                Delight.showRewardPopup(
                    DelightRequestPayload(
                        orderId: "ORDER-123",
                        email: nil,
                        userToken: nil,
                        firstName: nil,
                        lastName: nil,
                        ticketTypes: ["adult"]
                    ),
                    callbacks: DelightCallbacks(
                        onImpression: { _ in },
                        onPrimaryClick: { _ in },
                        onDismiss: {}
                    )
                )
            }
        }
        .overlay { DelightPopupPresenter() }
        .task {
            try? await Delight.initialize(
                brandName: "rewardsbag-provided-brand-name",
                ignoreLocalRulesForTesting: false,
                ignoreCooldownForLocalDevelopment: false
            )
        }
    }
}
```

## Objective-C Quick Start

```objc
#import "YourAppModuleName-Swift.h"

[DelightObjC initialize:@"rewardsbag-provided-brand-name"
ignoreLocalRulesForTesting:NO
ignoreCooldownForLocalDevelopment:NO
              completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Delight init failed: %@", error.localizedDescription);
    }
}];

[DelightObjC showRewardPopup:nil
                       email:nil
                   userToken:nil
                   firstName:nil
                    lastName:nil
                 ticketTypes:@[@"adult"]
                onImpression:^(NSString * _Nullable rewardId) {}
              onPrimaryClick:^(NSString * _Nullable rewardId) {}
                   onDismiss:^{}];
```

`ticketTypes` is required for Objective-C `showRewardPopup`; `orderId`, `email`, `userToken`, `firstName`, and `lastName` are optional.

## Privacy

- `PrivacyInfo.xcprivacy` ships with the SDK. No host-app declarations are required for SDK behavior.
- The SDK does not use any APIs requiring App Tracking Transparency.
- The SDK does not access IDFA, advertising identifiers, or device fingerprinting.

## Topics

### Swift API

- ``Delight``
- ``DelightRequestPayload``
- ``DelightCallbacks``
- ``DelightPopupPresenter``
- ``DelightPopupView``

### Objective-C Bridge

- ``DelightObjC``

### API Mapping (Swift ↔ Objective-C)

- Initialize: ``Delight/initialize(brandName:cdnBaseURL:useBundledConfig:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:)`` ↔ `+[DelightObjC initialize:ignoreLocalRulesForTesting:ignoreCooldownForLocalDevelopment:completion:]`
- Show popup: ``Delight/showRewardPopup(_:callbacks:)`` ↔ `+[DelightObjC showRewardPopup:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:]`
- Dismiss: ``Delight/dismiss()`` ↔ `+[DelightObjC dismiss]`