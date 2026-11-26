import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/widgets/app_motion.dart';
import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_banner.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_field.dart';
import '../../../../common/widgets/mic_permission_gate.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../data/notifier/roleplay_notifier.dart';
import '../widget/roleplay_bubble.dart';

/// Roleplay practice: the AI partner plays the other person in a situation; the learner answers by text or voice and gets feedback (F-22).
class RoleplayPage extends ConsumerStatefulWidget {
  const RoleplayPage({super.key, required this.scene, required this.title});

  final RoleplayScene scene;
  final String title;

  @override
  ConsumerState<RoleplayPage> createState() => _RoleplayPageState();
}

class _RoleplayPageState extends ConsumerState<RoleplayPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  RoleplayNotifier get _notifier =>
      ref.read(roleplayProvider(widget.scene).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && (ref.read(onlineProvider).value ?? true)) {
        _notifier.open();
      }
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Sends the typed answer.
  Future<void> _send() async {
    final text = _input.text;
    _input.clear();
    setState(() {});
    await _notifier.send(text);
  }

  /// Keeps the newest message in view.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: AppParams.standardDuration,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final provider = roleplayProvider(widget.scene);
    final state = ref.watch(provider);
    final online = ref.watch(onlineProvider).value ?? true;
    ref
      ..listen(provider.select((s) => s.messages.length), (_, _) {
        _scrollToEnd();
      })
      ..listen(provider.select((s) => s.heard), (_, heard) {
        if (heard != null) {
          _input.text = heard;
          setState(() {});
        }
      });
    return AppPlatformScaffold(
      backgroundColor: scheme.surface,
      appBar: AppPlatformAppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppParams.spacing20.w,
                AppParams.spacing8.h,
                AppParams.spacing20.w,
                0,
              ),
              child: Text(
                l10n.roleplayIntro(l10n.languageName(widget.scene.targetLang)),
                style: context.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (!online)
              Padding(
                padding: EdgeInsets.all(AppParams.spacing16.r),
                child: AppBanner(
                  kind: AppBannerKind.warning,
                  message: l10n.learningNeedsInternet,
                ),
              ),
            if (state.failed)
              Padding(
                padding: EdgeInsets.all(AppParams.spacing16.r),
                child: AppBanner(
                  kind: AppBannerKind.error,
                  message: l10n.learningFailed,
                  actionLabel: l10n.learningRetry,
                  onAction: _notifier.retry,
                ),
              ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: EdgeInsets.all(AppParams.spacing16.r),
                children: [
                  for (final (index, message) in state.messages.indexed)
                    AppFadeSlideIn(
                      key: ValueKey(index),
                      child: RoleplayBubble(
                        message: message,
                        targetLang: widget.scene.targetLang,
                        userLang: widget.scene.userLang,
                      ),
                    ),
                  if (state.waiting)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Padding(
                        padding: EdgeInsets.all(AppParams.spacing12.r),
                        child: AppTypingDots(color: scheme.primary),
                      ),
                    ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppParams.spacing12.w,
                vertical: AppParams.spacing8.h,
              ),
              child: Row(
                children: [
                  AppCircleIconButton(
                    icon: state.listening ? AppIcons.stop : AppIcons.mic,
                    semanticLabel: l10n.roleplaySpeak,
                    selected: state.listening,
                    onPressed: () async {
                      if (await ensureMicAccess(context, ref)) {
                        await _notifier.listen();
                      }
                    },
                  ),
                  SizedBox(width: AppParams.spacing8.w),
                  Expanded(
                    child: AppTextField(
                      controller: _input,
                      label: l10n.roleplayAnswerHint(
                        l10n.languageName(widget.scene.targetLang),
                      ),
                      maxLines: 3,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  SizedBox(width: AppParams.spacing8.w),
                  AppCircleIconButton(
                    icon: AppIcons.check,
                    semanticLabel: l10n.roleplaySend,
                    onPressed:
                        online &&
                            !state.waiting &&
                            _input.text.trim().isNotEmpty
                        ? _send
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
