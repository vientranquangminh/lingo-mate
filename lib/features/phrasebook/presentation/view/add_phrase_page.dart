import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/extensions/language_name_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_action_sheet.dart';
import '../../../../common/widgets/app_circle_icon_button.dart';
import '../../../../common/widgets/app_icon.dart';
import '../../../../common/widgets/app_platform_app_bar.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_platform_outlined_button.dart';
import '../../../../common/widgets/app_scaffold.dart';
import '../../../../common/widgets/app_text_field.dart';
import '../../../../common/widgets/save_phrase_action.dart';
import '../../../../core/engines/engine_instances.dart';
import '../../../../core/engines/engines.dart';
import '../../../../core/engines/selection/engine_providers.dart';
import '../../../../core/engines/selection/engine_selector.dart';
import '../../../../core/phrases/phrase_repository.dart';
import '../../../../core/settings/user_settings.dart';

/// Add phrase: type a sentence, get a translation from the current engine, edit it, save (AC-08.3).
class AddPhrasePage extends ConsumerStatefulWidget {
  const AddPhrasePage({super.key});

  @override
  ConsumerState<AddPhrasePage> createState() => _AddPhrasePageState();
}

class _AddPhrasePageState extends ConsumerState<AddPhrasePage> {
  final _source = TextEditingController();
  final _target = TextEditingController();
  late LanguagePair _pair = ref.read(userSettingsProvider).pair;
  bool _translating = false;
  String? _error;

  @override
  void dispose() {
    _source.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Proposes a translation with the engine Conversation would use now.
  Future<void> _translate() async {
    final text = _source.text.trim();
    if (text.isEmpty) {
      return;
    }
    final l10n = context.localization;
    setState(() {
      _translating = true;
      _error = null;
    });
    try {
      final selection = await ref.read(
        engineSelectionProvider(
          EngineRequest(mode: SessionMode.conversation, pair: _pair),
        ).future,
      );
      final engine = selection.conversationEngine;
      if (engine == null) {
        setState(() => _error = l10n.addPhraseNoEngine);
        return;
      }
      final translation = await ref
          .read(textTranslatorProvider(engine))
          .translate(TranslateRequest(from: _pair.a, to: _pair.b, text: text));
      _target.text = translation.text;
    } catch (_) {
      setState(() => _error = l10n.addPhraseFailed);
    } finally {
      if (mounted) {
        setState(() => _translating = false);
      }
    }
  }

  /// Saves and closes unless the phrase was already there.
  Future<void> _save() async {
    final result = await saveToPhrasebook(
      context,
      ref,
      sourceLang: _pair.a,
      sourceText: _source.text,
      targetLang: _pair.b,
      targetText: _target.text,
    );
    if (mounted && result?.outcome == SaveOutcome.saved) {
      await Navigator.of(context).maybePop();
    }
  }

  /// Picks the language for side [a] or b.
  Future<void> _pick({required bool a}) async {
    final l10n = context.localization;
    final matrix = await ref.read(capabilityMatrixProvider.future);
    if (!mounted) {
      return;
    }
    final other = a ? _pair.b : _pair.a;
    await showAppActionSheet(
      context: context,
      title: l10n.homePickLanguage,
      cancel: l10n.commonCancel,
      actions: [
        for (final language in matrix.languages.values)
          if (language.code != other)
            AppSheetAction(
              icon: AppIcons.language,
              label: l10n.languageName(language.code),
              onSelected: () => setState(
                () => _pair = a
                    ? LanguagePair(language.code, _pair.b)
                    : LanguagePair(_pair.a, language.code),
              ),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final scheme = Theme.of(context).colorScheme;
    final canSave =
        _source.text.trim().isNotEmpty && _target.text.trim().isNotEmpty;
    return AppPlatformScaffold(
      appBar: AppPlatformAppBar(title: Text(l10n.addPhraseTitle)),
      body: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppParams.spacing20.w,
          vertical: AppParams.spacing16.h,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: AppPlatformOutlinedButton(
                  onPressed: () => _pick(a: true),
                  text: '${l10n.addPhraseFrom}: ${l10n.languageName(_pair.a)}',
                ),
              ),
              AppCircleIconButton(
                icon: AppIcons.swap,
                semanticLabel: l10n.homeSwapLanguages,
                borderColor: Colors.transparent,
                color: scheme.primary,
                onPressed: () =>
                    setState(() => _pair = LanguagePair(_pair.b, _pair.a)),
              ),
              Expanded(
                child: AppPlatformOutlinedButton(
                  onPressed: () => _pick(a: false),
                  text: '${l10n.addPhraseTo}: ${l10n.languageName(_pair.b)}',
                ),
              ),
            ],
          ),
          SizedBox(height: AppParams.spacing16.h),
          AppTextField(
            controller: _source,
            label: l10n.addPhraseSource,
            minLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppParams.spacing12.h),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppPlatformOutlinedButton(
              onPressed: _translating || _source.text.trim().isEmpty
                  ? null
                  : _translate,
              text: l10n.addPhraseTranslate,
            ),
          ),
          if (_error != null) ...[
            SizedBox(height: AppParams.spacing8.h),
            Text(
              _error!,
              style: context.textTheme.bodyMedium?.copyWith(
                color: scheme.error,
              ),
            ),
          ],
          SizedBox(height: AppParams.spacing12.h),
          AppTextField(
            controller: _target,
            label: l10n.addPhraseTranslation,
            minLines: 2,
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: AppParams.spacing24.h),
          AppPlatformElevatedButton(
            onPressed: canSave ? _save : null,
            loading: _translating,
            text: l10n.addPhraseSave,
          ),
        ],
      ),
    );
  }
}
