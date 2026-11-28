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
  static const asrModels = 'asr_models';
  static const privacyPolicyUrl = 'privacy_policy_url';
  static const ffStandardEnabled = 'ff_standard_enabled';
  static const ffSummary = 'ff_summary';
  static const ffSuggestReply = 'ff_suggest_reply';
  static const ffGlossary = 'ff_glossary';
  static const ffCloudSpeech = 'ff_cloud_speech';
  static const modelSpeechTranslate = 'model_speech_translate';
  static const ffRoleplay = 'ff_roleplay';
  static const speakerModel = 'speaker_model';
  static const speakerTuning = 'speaker_tuning';

  static const _quotaLimitsJson =
      '{"free":{"standard":{"win5hSec":1800,"weekSec":3600},'
      '"live":{"trialSec":600}},'
      '"pro":{"standard":{"win5hSec":10800,"weekSec":36000},'
      '"live":{"monthSec":1800}}}';

  /// Returns the default value of every key; `liveEnabled` depends on the flavor.
  static Map<String, Object> values({required bool liveEnabled}) => {
    modelTextTranslate: 'gemini-2.5-flash-lite',
    modelTextReview: 'gemini-2.5-flash-lite',
    modelSpeechTranslate: 'gemini-2.5-flash',
    ffCloudSpeech: true,
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
    asrModels: '{}',
    speakerTuning: '{"merge":0.35,"minNewMs":1500,"minLabelMs":800}',
    speakerModel:
        '{"file":"speaker_embedding.onnx",'
        '"url":"https://github.com/k2-fsa/sherpa-onnx/releases/download/'
        'speaker-recongition-models/'
        '3dspeaker_speech_campplus_sv_zh_en_16k-common_advanced.onnx",'
        '"bytes":28281165,'
        '"sha256":"53cab20ba8f2eb2f6e2d89ecc18e88ef3222169b61b4419cbc13666744a4574b"}',
    privacyPolicyUrl: 'https://lingo-mate-4f38d.web.app/privacy',
    ffStandardEnabled: true,
    ffSummary: true,
    ffSuggestReply: true,
    ffGlossary: true,
    ffRoleplay: true,
  };
}
