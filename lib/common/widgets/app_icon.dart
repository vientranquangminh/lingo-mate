import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The in-app icon set in `assets/icons` (24 dp grid, 2 dp stroke, tinted in code).
enum AppIcons {
  add('add'),
  autoTurn('auto_turn'),
  back('back'),
  bookmark('bookmark'),
  bookmarkFilled('bookmark_filled'),
  check('check'),
  chevronDown('chevron_down'),
  chevronRight('chevron_right'),
  close('close'),
  copy('copy'),
  delete('delete'),
  deleteAccount('delete_account'),
  download('download'),
  edit('edit'),
  email('email'),
  engineLive('engine_live'),
  engineOffline('engine_offline'),
  engineStandard('engine_standard'),
  engineUnavailable('engine_unavailable'),
  error('error'),
  expand('expand'),
  external('external'),
  filter('filter'),
  glossary('glossary'),
  help('help'),
  info('info'),
  language('language'),
  lock('lock'),
  logout('logout'),
  mic('mic'),
  micOff('mic_off'),
  modeConversation('mode_conversation'),
  modeListen('mode_listen'),
  modeMedia('mode_media'),
  modeMeeting('mode_meeting'),
  modeShow('mode_show'),
  more('more'),
  navHistory('nav_history'),
  navMe('nav_me'),
  navPhrases('nav_phrases'),
  navTranslate('nav_translate'),
  pause('pause'),
  payment('payment'),
  play('play'),
  privacy('privacy'),
  pro('pro'),
  receipt('receipt'),
  regionBlocked('region_blocked'),
  replay('replay'),
  reviewCards('review_cards'),
  rotate('rotate'),
  search('search'),
  settings('settings'),
  share('share'),
  sitAirport('sit_airport'),
  sitHealth('sit_health'),
  sitHotel('sit_hotel'),
  sitMeeting('sit_meeting'),
  sitRestaurant('sit_restaurant'),
  sitShopping('sit_shopping'),
  sitSmalltalk('sit_smalltalk'),
  sitTaxi('sit_taxi'),
  speaker('speaker'),
  speakerOff('speaker_off'),
  star('star'),
  starFilled('star_filled'),
  stop('stop'),
  streak('streak'),
  suggestReply('suggest_reply'),
  summarize('summarize'),
  swap('swap'),
  sync('sync'),
  tag('tag'),
  textSize('text_size'),
  timer('timer'),
  usage('usage'),
  warning('warning'),
  waveform('waveform'),
  wifiOff('wifi_off');

  const AppIcons(this.fileName);

  final String fileName;

  /// Asset path of the SVG.
  String get asset => 'assets/icons/ic_$fileName.svg';
}

/// One icon from [AppIcons], tinted with [color] or the ambient icon colour; never mix in Material icons.
class AppIcon extends StatelessWidget {
  const AppIcon(
    this.icon, {
    super.key,
    this.size = 24,
    this.color,
    this.semanticLabel,
  });

  final AppIcons icon;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final tint =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    final picture = SvgPicture.asset(
      icon.asset,
      width: size.r,
      height: size.r,
      colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
    );
    if (semanticLabel == null) {
      return ExcludeSemantics(child: picture);
    }
    return Semantics(label: semanticLabel, image: true, child: picture);
  }
}
