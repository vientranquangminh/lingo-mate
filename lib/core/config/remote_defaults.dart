/// Remote Config keys with the in-app defaults used until a fetch succeeds.
abstract final class RemoteDefaults {
  static const modelTextTranslate = 'model_text_translate';
  static const modelTextReview = 'model_text_review';
  static const modelLiveTranslate = 'model_live_translate';
  static const modelLiveFallback = 'model_live_fallback';
  static const capabilityMatrix = 'capability_matrix';
  static const quotaLimits = 'quota_limits';
  static const liveBlockSec = 'live_block_sec';
  static const ffLiveEnabled = 'ff_live_enabled';
  static const ffMeetingOverlay = 'ff_meeting_overlay';
  static const ffPostSessionReview = 'ff_post_session_review';
  static const ffPaywall = 'ff_paywall';
  static const minSupportedBuild = 'min_supported_build';
  static const ffEmailLinkSignin = 'ff_email_link_signin';
  static const ffManageSubscription = 'ff_manage_subscription';

  static const _quotaLimitsJson =
      '{"free":{"standard":{"win5hSec":1800,"weekSec":3600},'
      '"live":{"trialSec":600}},'
      '"pro":{"standard":{"win5hSec":10800,"weekSec":36000},'
      '"live":{"monthSec":1800}}}';

  /// Returns the default value of every key; `liveEnabled` depends on the flavor.
  static Map<String, Object> values({required bool liveEnabled}) => {
    modelTextTranslate: 'gemini-2.5-flash-lite',
    modelTextReview: 'gemini-2.5-flash-lite',
    modelLiveTranslate: 'gemini-3.5-live-translate-preview',
    modelLiveFallback: 'gemini-3.1-flash-live-preview',
    capabilityMatrix: '',
    quotaLimits: _quotaLimitsJson,
    liveBlockSec: 600,
    ffLiveEnabled: liveEnabled,
    ffMeetingOverlay: true,
    ffPostSessionReview: false,
    ffPaywall: false,
    minSupportedBuild: 1,
    ffEmailLinkSignin: true,
    ffManageSubscription: false,
  };
}
