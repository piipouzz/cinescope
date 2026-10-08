import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:cinescope/app/cinescope_app.dart';

void main() {
  testWidgets('L’accueil se lance avec le thème sombre', (tester) async {
    await tester.pumpWidget(const CinescopeApp());
    await tester.pumpAndSettle();

    expect(find.text('CinéScope'), findsOneWidget);
    expect(
      find.text('Bienvenue ! Les films seront disponibles prochainement.'),
      findsOneWidget,
    );
    final context = tester.element(find.byType(ShadCard));
    expect(ShadTheme.of(context).colorScheme, isA<ShadVioletColorScheme>());
    expect(ShadTheme.of(context).brightness, Brightness.dark);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Une route inconnue permet de revenir à l’accueil', (
    tester,
  ) async {
    await tester.pumpWidget(const CinescopeApp());
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ShadCard));
    GoRouter.of(context).go('/inconnue');
    await tester.pumpAndSettle();
    expect(find.text('Page introuvable'), findsOneWidget);

    await tester.tap(find.text("Retour à l'accueil"));
    await tester.pumpAndSettle();
    expect(find.text('CinéScope'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
