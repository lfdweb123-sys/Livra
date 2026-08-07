import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_colors.dart';

/// Ouvre un lien de paiement (Verzapay checkout_url) DANS l'application via
/// WebView — sortir vers Chrome perd le client en cours de paiement.
/// Se ferme automatiquement (pop avec résultat true) si l'URL de retour
/// contient un des marqueurs de succès/échec.
class PaymentWebviewScreen extends StatefulWidget {
  final String url;
  final String title;
  const PaymentWebviewScreen({super.key, required this.url, this.title = 'Paiement'});

  @override
  State<PaymentWebviewScreen> createState() => _PaymentWebviewScreenState();
}

class _PaymentWebviewScreenState extends State<PaymentWebviewScreen> {
  late final WebViewController _controller;
  bool _loading = true;

  static const _successMarkers = ['success', 'succes', 'payment.completed', 'status=completed'];
  static const _failureMarkers = ['failed', 'echec', 'cancel', 'status=failed'];

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) => setState(() => _loading = true),
        onPageFinished: (_) => setState(() => _loading = false),
        onNavigationRequest: (request) {
          final url = request.url.toLowerCase();
          if (_successMarkers.any((m) => url.contains(m))) {
            Navigator.of(context).pop(true);
            return NavigationDecision.prevent;
          }
          if (_failureMarkers.any((m) => url.contains(m))) {
            Navigator.of(context).pop(false);
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(null),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_loading) Center(child: CircularProgressIndicator(color: AppColors.gold)),
        ],
      ),
    );
  }
}
