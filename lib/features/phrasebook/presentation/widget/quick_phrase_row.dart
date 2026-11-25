import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_selectable_chip.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../common/widgets/speak_or_show.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/quick_phrases/quick_phrases.dart';

/// A quick phrase in the user's language with the translation below; tap speaks, long-press shows it large, chips fill its slot.
class QuickPhraseRow extends ConsumerStatefulWidget {
  const QuickPhraseRow({
    super.key,
    required this.phrase,
    required this.pair,
    required this.starred,
  });

  final QuickPhrase phrase;
  final LanguagePair pair;
  final bool starred;

  @override
  ConsumerState<QuickPhraseRow> createState() => _QuickPhraseRowState();
}

class _QuickPhraseRowState extends ConsumerState<QuickPhraseRow> {
  String? _value;

  String get _source => widget.phrase.text(widget.pair.a, value: _value);

  String get _target => widget.phrase.text(widget.pair.b, value: _value);

  /// Speaks the translation, or shows it when no voice is installed (AC-09.2).
  Future<void> _speak() => speakOrShow(
    context,
    ref,
    text: _target,
    lang: widget.pair.b,
    original: _source,
  );

  /// Opens the translation in show mode (AC-09.4).
  void _show() => openShowMode(
    context,
    text: _target,
    original: _source,
    lang: widget.pair.b,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final slot = widget.phrase.slot;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppParams.spacing20.w,
        vertical: AppParams.spacing8.h,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label:
                      '$_source. ${l10n.languageName(widget.pair.b)}: $_target',
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppParams.radiusCard.r),
                    onTap: _speak,
                    onLongPress: _show,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: AppParams.spacing8.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _source,
                            style: context.textTheme.titleMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          SizedBox(height: AppParams.spacing4.h),
                          Text(
                            _target,
                            style: context.textTheme.bodyLarge?.copyWith(
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              AppCircleIconButton(
                icon: widget.starred ? AppIcons.starFilled : AppIcons.star,
                semanticLabel: widget.starred
                    ? l10n.quickUnstar
                    : l10n.quickStar,
                selected: widget.starred,
                borderColor: Colors.transparent,
                color: widget.starred
                    ? scheme.primary
                    : scheme.onSurfaceVariant,
                onPressed: () => ref
                    .read(quickPhraseFavoritesProvider)
                    .set(
                      widget.phrase.key,
                      widget.pair.a,
                      widget.pair.b,
                      !widget.starred,
                    ),
              ),
              AppCircleIconButton(
                icon: AppIcons.bookmark,
                semanticLabel: l10n.phraseSave,
                borderColor: Colors.transparent,
                color: scheme.onSurfaceVariant,
                onPressed: () => saveToPhrasebook(
                  context,
                  ref,
                  sourceLang: widget.pair.a,
                  sourceText: _source,
                  targetLang: widget.pair.b,
                  targetText: _target,
                ),
              ),
              AppCircleIconButton(
                icon: AppIcons.speaker,
                semanticLabel: l10n.showModeSpeak,
                color: scheme.primary,
                onPressed: _speak,
              ),
            ],
          ),
          if (slot != null) ...[
            SizedBox(height: AppParams.spacing8.h),
            Wrap(
              spacing: AppParams.spacing8.w,
              runSpacing: AppParams.spacing8.h,
              children: [
                for (final value in slot.values)
                  AppSelectableChip(
                    label: value,
                    selected: (_value ?? slot.values.first) == value,
                    onChanged: (_) => setState(() => _value = value),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
