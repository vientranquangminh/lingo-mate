import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../common/extensions/build_context_ext.dart';
import '../../../../common/resources/app_params.dart';
import '../../../../common/widgets/app_platform_elevated_button.dart';
import '../../../../common/widgets/app_text_field.dart';

/// What the term sheet returns.
class TermInput {
  const TermInput({required this.term, required this.translation, this.note});

  final String term;
  final String translation;
  final String? note;
}

/// Shows the add/edit term sheet; returns the entered term, or null when closed.
Future<TermInput?> showTermSheet(BuildContext context, {TermInput? initial}) =>
    showModalBottomSheet<TermInput>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppParams.radiusSheet.r),
        ),
      ),
      builder: (_) => _TermSheet(initial: initial),
    );

/// Term, preferred translation and note fields with Save.
class _TermSheet extends StatefulWidget {
  const _TermSheet({this.initial});

  final TermInput? initial;

  @override
  State<_TermSheet> createState() => _TermSheetState();
}

class _TermSheetState extends State<_TermSheet> {
  late final _term = TextEditingController(text: widget.initial?.term);
  late final _translation = TextEditingController(
    text: widget.initial?.translation,
  );
  late final _note = TextEditingController(text: widget.initial?.note);

  @override
  void dispose() {
    _term.dispose();
    _translation.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid =>
      _term.text.trim().isNotEmpty && _translation.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.localization;
    final gap = SizedBox(height: AppParams.spacing12.h);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppParams.spacing20.w,
        0,
        AppParams.spacing20.w,
        MediaQuery.viewInsetsOf(context).bottom + AppParams.spacing16.h,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initial == null
                  ? l10n.glossaryAddTerm
                  : l10n.glossaryEditTerm,
              style: context.textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            gap,
            AppTextField(
              controller: _term,
              label: l10n.glossaryTerm,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            gap,
            AppTextField(
              controller: _translation,
              label: l10n.glossaryTranslation,
              maxLines: 2,
              onChanged: (_) => setState(() {}),
            ),
            gap,
            AppTextField(controller: _note, label: l10n.glossaryNote),
            SizedBox(height: AppParams.spacing16.h),
            AppPlatformElevatedButton(
              onPressed: _valid
                  ? () => Navigator.of(context).pop(
                      TermInput(
                        term: _term.text,
                        translation: _translation.text,
                        note: _note.text,
                      ),
                    )
                  : null,
              text: l10n.commonSave,
            ),
          ],
        ),
      ),
    );
  }
}
