import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Utilise un import relatif (../lib/) pour éviter les erreurs de nom de package
import '../lib/main.dart';

void main() {
  testWidgets('Test de démarrage SmartCampusApp', (WidgetTester tester) async {
    // On enveloppe l'application dans un ProviderScope car tu utilises Riverpod
    await tester.pumpWidget(
      const ProviderScope(
        // Si tu as bien nommé ta classe SmartCampusApp dans main.dart, ceci fonctionnera
        child: SmartCampusApp(),
      ),
    );

    // On vérifie simplement que l'application s'est construite correctement
    expect(find.byType(SmartCampusApp), findsOneWidget);
  });
}