import 'package:airp2p/app.dart';
import 'package:airp2p/core/discovery/peer_registry.dart';
import 'package:airp2p/core/transfer/transfer_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AirP2PApp boots cleanly', (WidgetTester tester) async {
    final peerRegistry = PeerRegistry();
    final transferManager = TransferManager(
      selfId: 'test_node',
      selfName: 'Test Machine',
    );

    await tester.pumpWidget(AirP2PApp(
      peerRegistry: peerRegistry,
      transferManager: transferManager,
      selfName: 'Test Machine',
    ));

    expect(find.textContaining('Test Machine'), findsWidgets);
    peerRegistry.dispose();
  });
}
