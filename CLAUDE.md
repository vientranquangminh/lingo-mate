# Project rules

## Read first

- `.agents/CONTEXT.md`: the code map. It shows the architecture, the folder layout and the
  patterns each layer follows. Read it before searching the tree, so you open only the
  files you need and don't miss related ones.
- `.agents/INSTRUCTIONS.md`: how to add a feature (folders, states, repositories).
- When you add or move a feature, route, server call, shared widget or cross-feature
  dependency, update `.agents/CONTEXT.md` in the same change.

## Flutter version

- The project pins Flutter in `.fvmrc` (currently 3.50.0); run Flutter and Dart through
  `fvm` (`fvm flutter …`, `fvm dart …`). When you bump it, also update `.vscode/settings.json`
  and the prerequisite in `README.md`.
- Material and Cupertino come from the `material_ui` and `cupertino_ui` packages, not from
  the framework. Import `package:material_ui/material_ui.dart` and
  `package:cupertino_ui/cupertino_ui.dart`, never `package:flutter/material.dart` or
  `package:flutter/cupertino.dart`. Other framework libraries (`foundation`, `services`,
  `widgets`) stay as they are.
- Localization delegates come from `material_ui`: use
  `...GlobalMaterialLocalizations.delegates` next to `AppLocalizations.delegate`.
- If a third-party package still builds widgets from `package:flutter/material.dart`, wrap
  that subtree in `MaterialUiCompatibilityBridge`.

## Localization

- Strings come from Flutter's gen-l10n (`l10n.yaml`), not intl_utils. Add every
  user-visible string to `lib/l10n/intl_en.arb` (the template) and to each other ARB file,
  then run `fvm flutter gen-l10n`.
- Read strings with `context.localization.<key>`. Don't hard-code user-visible text.
- `lib/generated/` is generated and git-ignored; never edit or commit it.

## Code comments

Applies to new and changed code. Leave existing comments as they are unless you are editing that code.

- Add no comments to code.
- Only exception: one short doc comment per function/method saying what it does,
  and one short line per class saying what it is.
- Keep analyzer directives (`// ignore: ...`) and annotations such as `@pragma`.

## Shared platform widgets

Applies to every screen.

- Build UI from the shared widgets in `lib/common/widgets` instead of raw Material widgets:

  | Instead of | Use |
  |---|---|
  | `Scaffold` | `AppPlatformScaffold` |
  | `AppBar` | `AppPlatformAppBar` |
  | `NavigationBar` / `BottomNavigationBar` | `AppPlatformNavBar` |
  | `FilledButton` / `ElevatedButton` | `AppPlatformElevatedButton` |
  | `OutlinedButton` / pill buttons | `AppPlatformOutlinedButton` |
  | `TextButton` | `AppPlatformTextButton` |
  | `IconButton` | `AppPlatformIconButton` |
  | `CircularProgressIndicator` | `AppCircularProgressIndicator` |

- Need a widget that isn't there yet? Add it to `lib/common/widgets`, building the
  Material or the Cupertino Flutter widget depending on `context.isCupertino`
  (`lib/common/extensions/platform_ext.dart`), following the existing `AppPlatform*`
  widgets, then use it.
- Widgets used by more than one feature live in `lib/common/widgets`; a feature never
  imports widgets from another feature's folder.
- Take sizes, radii, paddings and durations from `AppParams`
  (`lib/common/resources/app_params.dart`) instead of repeating literals; add new shared
  values there.
- Take colours from the theme's `ColorScheme` (`lib/common/resources/app_theme.dart`).
  Don't hard-code colours in widgets.

## Responsive sizing (flutter_screenutil)

Applies to every screen and shared widget.

- Scale every layout size against the 375×812 design (`AppConfiguration.mainAppSize`)
  with `flutter_screenutil`. Never pass a raw number as a size.

  | Value | Use | Example |
  |---|---|---|
  | Width, horizontal padding/gap | `.w` | `SizedBox(width: 8.w)`, `EdgeInsets.symmetric(horizontal: 16.w)` |
  | Height, vertical padding/gap | `.h` | `SizedBox(height: 16.h)`, `EdgeInsets.symmetric(vertical: 12.h)` |
  | Radius, icon size, square boxes, `EdgeInsets.all` | `.r` | `BorderRadius.circular(12.r)`, `Icon(size: 24.r)`, `EdgeInsets.all(24.r)` |
  | Font size | `.sp` | `TextStyle(fontSize: 16.sp)` |

- Don't scale unitless values: `TextStyle.height`, `flex`, opacity, scale factors,
  durations.
- `AppParams` and `Dimens` hold unscaled design values; scale them where they are used
  (`AppParams.radius24.r`, `AppParams.buttonHeight.h`, `Dimens.fontSize14.sp`). Drop
  `const` where a scaled value makes it impossible.
- Size parameters of shared widgets (`fontSize`, `size`, `padding`, `radius`) take
  unscaled design values; the widget scales them in `build` (`fontSize.sp`,
  `size.r`, `padding.r`). Callers pass plain numbers, never pre-scaled ones.

## Colours (colors.xml)

Applies to Dart and Android code. iOS code is out of scope for now: leave it as is.

- Every colour lives in `assets/color/values/colors.xml`. Never write a colour value
  (`Color(0x…)`, `Colors.white`, `#RRGGBB`, `@android:color/…`)
  anywhere else. Only `Colors.transparent` is allowed as is.
- Dart: flutter_gen turns the file into `ColorName` (`lib/gen/colors.gen.dart`); run
  `fvm dart run build_runner build --delete-conflicting-outputs` after editing it.
  `AppTheme` maps `ColorName` values to the `ColorScheme`; widgets use the `ColorScheme`,
  and use `ColorName` directly only when no role fits.
- Android: the same file is an Android resource (`main.res.srcDirs` in
  `android/app/build.gradle`); reference colours as `@color/<name>` or `R.color.<name>`.
- Naming: `<main colour>_<name>` in snake_case, e.g. `blue_seljuk`.
  - `<name>` comes only from [meodai/color-names](https://github.com/meodai/color-names):
    the entry in its `src/colornames.csv` nearest to the colour in CIELAB (smallest
    ΔE). Strip accents and punctuation: Zhēn Zhū Bái Pearl → `zhen_zhu_bai_pearl`.
  - `<main colour>` comes from the colour's HSL:
    saturation under 10% is `white` (lightness ≥ 95%), `black` (≤ 8%) or `gray`;
    otherwise by hue: `red` < 15° or ≥ 345°, `orange` < 45°, `yellow` < 65°,
    `green` < 170°, `cyan` < 200°, `blue` < 255°, `purple` < 290°, `pink` < 345°.
  - Drop a word of the name that repeats the main colour: Elite Blue → `blue_elite`,
    White → `white`.
  - Translucent colours end with `_a` and their opacity in percent: `black_a54`.
  - If two colours get the same name, add the hex to each: `blue_kon_1a2234`.

## Text styles

- Take text styles from the getters in `PlatFormThemeDataExtension`
  (`lib/common/extensions/text_style_ext.dart`) as `context.<getter>`. Don't write
  `TextStyle(...)` in widgets; add a getter when the one you need is missing.
- Use only the Material 3 type scale (size/line height): `displayLarge` 57/64,
  `displayMedium` 45/52, `displaySmall` 36/44, `headlineLarge` 32/40,
  `headlineMedium` 28/36, `headlineSmall` 24/32, `titleLarge` 22/28,
  `titleMedium` 16/24 medium, `titleSmall` 14/20 medium, `bodyLarge` 16/24,
  `bodyMedium` 14/20, `bodySmall` 12/16, `labelLarge` 14/20 medium,
  `labelMedium` 12/16 medium, `labelSmall` 11/16 medium (the official M3 spec; regular
  unless marked medium). `Dimens` holds only these sizes and the app's `TextTheme` keeps
  these line heights. Round any other size from a design to the nearest of them.
- Name getters `<weight>Size<N><Colour>Text`: weight `regular` (w400), `medium` (w500),
  `semiBold` (w600) or `bold` (w700); `<N>` matches `Dimens.fontSize<N>`; `<Colour>` is
  the `ColorName` in PascalCase. Example: `regularSize14BlackText`.
- Each getter uses the file's `_style` helper: Material starts from the `textTheme` role of that
  size (medium and heavier use the title/label role, regular the body role: 16 medium
  `titleMedium`, 16 regular `bodyLarge`), Cupertino from `textTheme.textStyle`; both
  `copyWith` `color: ColorName.<name>`, `fontSize: Dimens.fontSize<N>.sp` and `fontWeight`.
- Keep the role's line height; don't override `height` at the use site.
- Exceptions that stay inline: theme definitions, sizes computed at runtime, button labels
  coloured by the button, and colours taken from the `ColorScheme`.

## Commits and pull requests

- Write every commit message and pull request title as a
  [Conventional Commit](https://www.conventionalcommits.org/en/v1.0.0/):

  ```
  <type>(<optional scope>): <summary>
  ```

- `<type>` is one of `feat` (new feature), `fix` (bug fix), `docs`, `style`
  (formatting only), `refactor`, `perf`, `test`, `build` (dependencies, build
  scripts), `ci`, `chore` or `revert`.
- `<scope>` is optional and names the area in lowercase, e.g. `feat(auth): …`.
- `<summary>` is imperative, lower case, without a trailing period, and keeps the
  whole first line within 72 characters: `fix: keep the login button in place`.
- Mark breaking changes with `!` after the type or scope (`feat(auth)!: …`) and
  explain them in a `BREAKING CHANGE:` footer.
- Put details in the body, separated from the first line by a blank line.
