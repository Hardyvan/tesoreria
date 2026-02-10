import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tesoreria_ivan/main.dart';
import 'package:tesoreria_ivan/myPagesTema/a_tema_app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ProveedorTema()),
        ],
        child: const MiApp(),
      ),
    );

    // Verify that the app builds without crashing
    expect(find.byType(MiApp), findsOneWidget);
  });
}
