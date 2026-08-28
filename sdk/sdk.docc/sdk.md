# ``DelightSDK``

Post-purchase reward popup SDK for iOS apps.

## Overview

Use DelightSDK to load partner campaign configuration and present reward popups from your app.

Typical integration flow:

1. Initialize once at app startup with ``Delight/initialize(brandName:locale:cdnBaseURL:useBundledConfig:ignoreDailyCooldownHours:consentGranted:)``.
2. Mount ``DelightPopupPresenter`` in your root SwiftUI view hierarchy.
3. Trigger a popup with ``Delight/showRewardPopup(_:callbacks:)``.
4. Optionally dismiss with ``Delight/dismiss()``.

For Objective-C integrations, use ``DelightObjC`` bridge methods.

`brandName` is the partner identifier provided by RewardsBag. The SDK fetches `https://cdn.rewardsbag.com/configs/{brandName}.json` unless `useBundledConfig` is `true`.

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
                        ticketTypes: nil
                    ),
                    callbacks: DelightCallbacks(
                        onImpression: { _ in },
                        onPrimaryClick: { _ in },
                        onDismiss: {},
                        onError: { _ in }
                    )
                )
            }
        }
        .overlay { DelightPopupPresenter() }
        .task {
            try? await Delight.initialize(
                brandName: "YOUR_BRAND_NAME",
                locale: "en",
                consentGranted: true
            )
        }
    }
}
```

All ``DelightRequestPayload`` fields are optional. Pass `ticketTypes` only when the campaign filters rewards by basket or context types.

## Objective-C Quick Start

```objc
#import "YourAppModuleName-Swift.h"

[DelightObjC setConsentGranted:YES];

[DelightObjC initialize:@"YOUR_BRAND_NAME"
                locale:@"en"
              completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Delight init failed: %@", error.localizedDescription);
    }
}];

[DelightObjC showRewardPopup:@"ORDER-123"
                       email:nil
                   userToken:nil
                   firstName:nil
                    lastName:nil
                 ticketTypes:nil
                onImpression:^(NSString * _Nullable rewardId) {}
              onPrimaryClick:^(NSString * _Nullable rewardId) {}
                   onDismiss:^{}
                      onError:^(NSString * message) {}];
```

All `showRewardPopup` arguments are optional, including `ticketTypes`.

## Popup Behavior

Template, copy, images, and CTA URLs come from the partner config.

### Present icon (`popup.enablePresentIcon`)

- `false` — X-only popup from first render; dismisses fully (no minimize, no floating icon)
- `true` — minimize to present icon; reopened popup shows X; X dismisses entirely

Minimize does not record an ignore. Reopening from the icon restores the same session, including the current carousel slide.

### Rewards and claim

Depending on the campaign, the popup shows one reward or a carousel of eligible rewards. Claim records a click for the visible reward. Some campaigns dismiss on claim; others stay open and advance to the next unclaimed reward. When every reward in the current popup has been claimed, the popup dismisses.

### Impressions

An impression fires the first time each reward becomes visible in the current presentation (first open, or moving to an unseen carousel slide). Reopening from the present icon does not recount rewards already impressed in that session. ``DelightCallbacks/onImpression`` and backend impression tracking both receive the visible reward id.

## Consent Controls

- Swift:
  - ``Delight/setConsent(granted:)``
  - ``Delight/resetDailySuppressionState()``
  - ``Delight/clearLocalData()``
- Objective-C:
  - `+[DelightObjC setConsentGranted:]`
  - `+[DelightObjC resetDailySuppressionState]`
  - `+[DelightObjC clearLocalData]`
- When consent is not granted, popup display and backend tracking are disabled.

## Local Suppression

Suppression runs only when the CDN config includes a `suppressionRules` block. If that block is omitted, the SDK does not apply caps, cooldowns, fatigue, or click suppression.

When the block is present, counting is on-device (UserDefaults). Missing fields use these SDK fallbacks:

- `maxRewardsPerUserPerDay`: 2 (different reward IDs)
- `dailyCooldownHours`: 5
- `maxImpressionsPerRewardWithoutEngagement`: 3
- `restPeriodAfterNoEngagementDays`: 21
- `maxImpressionsPerUserPerMonth`: 15
- `suppressionPeriodAfterClickDays`: 45
- `retentionDays`: 90 (per-reward storage housekeeping; must exceed click suppression)

Selection filters visible rewards by `ticketTypes` when provided (`nil` / empty matches rewards with no ticket type), then picks the first eligible reward. Campaigns that show a carousel include the remaining visible rewards after the selected one.

``Delight/resetDailySuppressionState()`` clears today's slots only; ``Delight/clearLocalData()`` wipes everything including the SDK token.

## Privacy

- `PrivacyInfo.xcprivacy` ships with the SDK. No host-app declarations are required for SDK behavior.
- The SDK does not use any APIs requiring App Tracking Transparency.
- The SDK does not access IDFA, advertising identifiers, or device fingerprinting.

## Error Handling

If the API is unreachable, returns an error, or configuration is invalid, the SDK fires the error callback and does not display the popup.

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

- Initialize: ``Delight/initialize(brandName:locale:cdnBaseURL:useBundledConfig:ignoreDailyCooldownHours:consentGranted:)`` ↔ `+[DelightObjC initialize:locale:ignoreDailyCooldownHours:completion:]`
- Reset daily slots: ``Delight/resetDailySuppressionState()`` ↔ `+[DelightObjC resetDailySuppressionState]`
- Show popup: ``Delight/showRewardPopup(_:callbacks:)`` ↔ `+[DelightObjC showRewardPopup:email:userToken:firstName:lastName:ticketTypes:onImpression:onPrimaryClick:onDismiss:onError:]`
- Dismiss: ``Delight/dismiss()`` ↔ `+[DelightObjC dismiss]`
