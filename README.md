# DelightSDK

DelightSDK is an iOS SDK for showing post-purchase reward popups. Layout, copy, and eligibility come from the partner CDN config. Local suppression and tracking run on-device.

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

Call once on app startup (for example in `.task`, app launch, or bootstrap flow). `brandName` is the partner identifier RewardsBag provides; the SDK loads `https://cdn.rewardsbag.com/configs/{brandName}.json`.

```swift
try await Delight.initialize(
    brandName: "YOUR_BRAND_NAME",
    locale: "en",
    consentGranted: true
)
```

### 3) Add the popup presenter

Attach it to a high-level container so the overlay can be presented:

```swift
.overlay {
    DelightPopupPresenter()
}
```

### 4) Show a reward popup

All payload fields are optional. Pass `ticketTypes` when the campaign filters rewards by basket/context types; omit or pass `nil` when it does not.

```swift
Delight.showRewardPopup(
    DelightRequestPayload(
        orderId: "ORDER-123",
        email: "customer@example.com",
        firstName: "Jane",
        lastName: "Doe",
        ticketTypes: nil
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
        },
        onError: { message in
            print("Error:", message)
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

[DelightObjC initialize:@"YOUR_BRAND_NAME"
                locale:@"en"
              completion:^(NSError * _Nullable error) {
    if (error) {
        NSLog(@"Delight init failed: %@", error.localizedDescription);
    }
}];
```

### 3) Show a reward popup

All arguments are optional, including `ticketTypes`.

```objc
[DelightObjC showRewardPopup:@"ORDER-123"
                       email:@"customer@example.com"
                   userToken:nil
                   firstName:@"Jane"
                    lastName:@"Doe"
                 ticketTypes:nil
                onImpression:^(NSString * _Nullable rewardId) {
    NSLog(@"Impression: %@", rewardId);
}
              onPrimaryClick:^(NSString * _Nullable rewardId) {
    NSLog(@"Primary click: %@", rewardId);
}
                   onDismiss:^{
    NSLog(@"Popup dismissed");
}
                      onError:^(NSString * message) {
    NSLog(@"Error: %@", message);
}];
```

### 4) Dismiss programmatically (optional)

```objc
[DelightObjC dismiss];
```

## Configuration Options

`Delight.initialize(...)` supports:

- `brandName`: partner identifier provided by RewardsBag
- `locale`: locale/language code for popup content (default: `"en"`)
- `cdnBaseURL`: config host (default: `https://cdn.rewardsbag.com`)
- `useBundledConfig`: when `true`, loads bundled `config.json` and skips the CDN (local testing)
- `consentGranted`: set to `true` only when user consent is granted
- `ignoreDailyCooldownHours`: set to `true` for QA so `dailyCooldownHours` is treated as 0

Objective-C initialization:

- `[DelightObjC initialize:locale:ignoreDailyCooldownHours:completion:]`
- `[DelightObjC initialize:locale:completion:]` (cooldown enforced)

## Popup Behavior

Template, copy, images, and CTA URLs come from the partner config. The SDK picks a supported template from that config.

### Present icon (`popup.enablePresentIcon`)

- `false` — close (X) from first render; no minimize; no floating present icon
- `true` — minimize (`−`) on first render; reopen from the present icon shows X; X dismisses fully

Minimize does not record an ignore. Reopening from the icon restores the same session (including the current carousel slide and already-claimed rewards).

### Rewards shown

Depending on the campaign, the popup shows a single reward or a carousel of eligible rewards.

- Claim records a click/claim for the visible reward.
- Some campaigns dismiss on claim; others stay open and move to the next unclaimed reward.
- When every reward in the current popup has been claimed, the popup dismisses.

### Impressions

An impression fires the first time a reward becomes visible in the current presentation:

- First open of the popup
- Moving to another carousel slide that has not been seen yet in this session

`onImpression` and backend impression tracking both receive that reward’s id. Reopening from the present icon does not recount rewards that were already impressed. A new `showRewardPopup` call starts a new presentation.

## Request Payload

| Field | Required | Notes |
|-------|----------|--------|
| `orderId` | No | Same order id returns the same assigned reward if one was already selected |
| `email` | No | Used for claim tracking when present |
| `userToken` | No | The SDK generates and persists one when omitted |
| `firstName` / `lastName` | No | |
| `ticketTypes` | No | Context labels used to match rewards. `nil` / empty only matches rewards with no ticket type. Non-empty values build an ordered pool from those types |

## QA / Local Testing

- `Delight.resetDailySuppressionState()` clears today's daily reward slots (simulates GMT midnight). Fatigue, click suppression, and monthly history are preserved.
- `Delight.initialize(..., ignoreDailyCooldownHours: true)` bypasses the daily slot cooldown for QA.
- `Delight.clearLocalData()` wipes all local suppression history and the SDK user token.
- Objective-C: `[DelightObjC resetDailySuppressionState]` and `[DelightObjC clearLocalData]`.

## Local Suppression Rules

Suppression runs only when the CDN config includes a `suppressionRules` block. If that block is omitted, the SDK does not apply caps, cooldowns, fatigue, or click suppression.

When the block is present, counting is on-device (UserDefaults). Missing fields use the SDK fallbacks below.

| Key | Fallback |
|-----|----------|
| `maxRewardsPerUserPerDay` | 2 (different reward IDs) |
| `dailyCooldownHours` | 5 |
| `maxImpressionsPerRewardWithoutEngagement` | 3 |
| `restPeriodAfterNoEngagementDays` | 21 |
| `maxImpressionsPerUserPerMonth` | 15 per GMT month |
| `suppressionPeriodAfterClickDays` | 45 |
| `retentionDays` | 90 (per-reward storage housekeeping; must exceed click suppression) |

**Selection:** Visible rewards are filtered by `ticketTypes` (when provided), then the first eligible reward is chosen. Campaigns that show a carousel include the remaining visible rewards after the selected one.

**Purchase blocking (when rules are present):** No popup if the daily cap is reached, the monthly cap is reached, or the next daily slot is requested inside the cooldown (cooldown attempts do not consume a slot).

**Daily reset:** GMT midnight. **Monthly reset:** GMT calendar month.

## Consent Controls

- Swift:
  - `Delight.setConsent(granted:)` to gate popup display/tracking at runtime.
  - `Delight.resetDailySuppressionState()` to simulate a GMT midnight daily reset.
  - `Delight.clearLocalData()` to clear locally stored SDK token + all suppression history.
- Objective-C:
  - `[DelightObjC setConsentGranted:YES/NO]`
  - `[DelightObjC resetDailySuppressionState]`
  - `[DelightObjC clearLocalData]`
- When consent is not granted, the SDK is a no-op for popup display and backend tracking.

## Privacy

- `PrivacyInfo.xcprivacy` ships with the SDK. No host-app declarations are required for SDK behavior.
- The SDK does not use any APIs requiring App Tracking Transparency.
- The SDK does not access IDFA, advertising identifiers, or device fingerprinting.

## Notes

- Footer links, CTA handling, impressions, claims, and local suppression are handled by the SDK.
- Keep `DelightPopupPresenter` mounted in the view hierarchy while a popup may be shown.
- If the API is unreachable, returns an error, or configuration is invalid, the SDK fires the error callback and does not display the popup.
