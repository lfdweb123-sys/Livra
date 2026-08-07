import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/services/api/api_client.dart';
import '../../../../core/services/friendly_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/debounced_button.dart';
import '../../../../core/widgets/app_bottom_nav.dart';
import '../../../../core/widgets/notification_bell_action.dart';
import '../../../../core/widgets/phone_number_field.dart';
import '../../../../core/services/phone_number_cache.dart';
import '../../../../core/services/payment/verzapay_checkout_flow.dart';
import '../../../../core/constants/wallet_reason_labels.dart';

class WalletScreen extends StatefulWidget {
  WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  Map<String, dynamic>? _wallet;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final res = await ApiClient.instance.get('/api/wallet/$uid');
    setState(() => _wallet = res);
  }

  Future<void> _withdraw() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await showAppBottomSheet(
      context,
      title: 'Retirer vers Mobile Money',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: const Text('Feexpay'),
            subtitle: const Text('Bénin, CI, Togo, Sénégal, Congo, Burkina, Mali', style: TextStyle(fontSize: 11)),
            onTap: () {
              Navigator.pop(context);
              _withdrawFeexpay(uid);
            },
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: const Text('Verzapay'),
            onTap: () {
              Navigator.pop(context);
              _withdrawVerzapay(uid);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawVerzapay(String uid) async {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final cachedPhone = await PhoneNumberCache().load();
    if (cachedPhone != null) phoneCtrl.text = cachedPhone;
    await showAppBottomSheet(
      context,
      title: 'Retirer vers Mobile Money — Verzapay',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
              controller: amountCtrl,
              decoration: InputDecoration(hintText: 'Montant (XOF)'),
              keyboardType: TextInputType.number),
          SizedBox(height: 12),
          PhoneNumberField(
              initialValue: cachedPhone, onChanged: (v) => phoneCtrl.text = v),
          SizedBox(height: 16),
          DebouncedButton(
            label: 'Confirmer le retrait',
            onPressed: () async {
              if (phoneCtrl.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Renseignez votre numéro Mobile Money.')));
                return;
              }
              try {
                await ApiClient.instance
                    .post('/api/wallet/$uid/withdraw', data: {
                  'amount': num.tryParse(amountCtrl.text) ?? 0,
                  'phoneNumber': phoneCtrl.text.trim(),
                  'provider': 'verzapay',
                });
                await PhoneNumberCache().save(phoneCtrl.text.trim());
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Retrait en cours de confirmation.')));
                  _load();
                }
              } catch (e) {
                final msg = e.toString().contains('insufficient_balance')
                    ? 'Solde disponible insuffisant (les gains récents peuvent encore être bloqués 3 jours).'
                    : 'Erreur lors du retrait. Réessayez dans un instant.';
                if (mounted)
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(msg)));
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _withdrawFeexpay(String uid) async {
    final amountCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final otpCtrl = TextEditingController();
    String network = 'mtn';
    final cachedPhone = await PhoneNumberCache().load();
    if (cachedPhone != null) phoneCtrl.text = cachedPhone;
    const networks = {
      'mtn': 'MTN (Bénin)', 'moov': 'Moov (Bénin)', 'celtiis_bj': 'Celtiis (Bénin)',
      'mtn_ci': 'MTN CI', 'orange_ci': 'Orange CI', 'moov_ci': 'Moov CI', 'wave_ci': 'Wave CI',
      'togocom_tg': 'Togocom TG', 'moov_tg': 'Moov TG',
      'orange_sn': 'Orange SN', 'free_sn': 'Free SN', 'wave_sn': 'Wave SN',
      'mtn_cg': 'MTN Congo',
      'moov_bf': 'Moov BF', 'orange_bf': 'Orange BF (OTP requis)', 'wave_bf': 'Wave BF (OTP requis)',
      'orange_ml': 'Orange Mali', 'mobicash_ml': 'Mobicash Mali',
    };
    const otpNetworks = {'orange_bf', 'wave_bf'};

    await showAppBottomSheet(
      context,
      title: 'Retirer vers Mobile Money — Feexpay',
      child: StatefulBuilder(builder: (context, setSheetState) {
        final requiresOtp = otpNetworks.contains(network);
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Réseau', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            DropdownButton<String>(
              value: network,
              isExpanded: true,
              items: networks.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setSheetState(() => network = v!),
            ),
            const SizedBox(height: 12),
            TextField(
                controller: amountCtrl,
                decoration: InputDecoration(hintText: 'Montant (XOF)'),
                keyboardType: TextInputType.number),
            SizedBox(height: 12),
            PhoneNumberField(
                initialValue: cachedPhone, onChanged: (v) => phoneCtrl.text = v),
            if (requiresOtp) ...[
              const SizedBox(height: 12),
              Text(
                network == 'orange_bf'
                    ? 'Composez #144*4*6*montant# sur le téléphone Orange BF du bénéficiaire pour obtenir le code OTP.'
                    : 'Générez le code OTP via l\'application Wave ou par USSD.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5),
              ),
              const SizedBox(height: 8),
              TextField(controller: otpCtrl, decoration: const InputDecoration(hintText: 'Code OTP'), keyboardType: TextInputType.number),
            ],
            SizedBox(height: 16),
            DebouncedButton(
              label: 'Confirmer le retrait',
              onPressed: () async {
                if (phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Renseignez votre numéro Mobile Money.')));
                  return;
                }
                if (requiresOtp && otpCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Le code OTP est requis pour ce réseau.')));
                  return;
                }
                try {
                  await ApiClient.instance.post('/api/wallet/$uid/withdraw', data: {
                    'amount': num.tryParse(amountCtrl.text) ?? 0,
                    'phoneNumber': phoneCtrl.text.trim(),
                    'provider': 'feexpay',
                    'network': network,
                    if (requiresOtp) 'otp': otpCtrl.text.trim(),
                  });
                  await PhoneNumberCache().save(phoneCtrl.text.trim());
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Retrait en cours de confirmation.')));
                    _load();
                  }
                } catch (e) {
                  final msg = e.toString().contains('insufficient_balance')
                      ? 'Solde disponible insuffisant (les gains récents peuvent encore être bloqués 3 jours).'
                      : 'Erreur lors du retrait. Réessayez dans un instant.';
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  }
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _deposit() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final amountCtrl = TextEditingController();
    await showAppBottomSheet(
      context,
      title: 'Déposer sur mon portefeuille',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: amountCtrl,
            decoration: InputDecoration(hintText: 'Montant (XOF)'),
            keyboardType: TextInputType.numberWithOptions(decimal: false),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          SizedBox(height: 16),
          PrimaryButton(
            label: 'Continuer',
            onPressed: () {
              final amount = num.tryParse(amountCtrl.text.trim()) ?? 0;
              if (amount < 100) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content:
                          Text('Entrez un montant valide (minimum 100 XOF).')),
                );
                return;
              }
              Navigator.pop(context);
              _chooseDepositMethod(uid, amount);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _chooseDepositMethod(String uid, num amount) async {
    await showAppBottomSheet(
      context,
      title: 'Moyen de paiement',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.phone_android, color: AppColors.gold),
            title: Text('Mobile Money'),
            onTap: () => _depositFeexpay(uid, amount),
          ),
          ListTile(
            leading: Icon(Icons.credit_card, color: AppColors.gold),
            title: Text('Carte bancaire / International'),
            onTap: () => _depositVerzapay(uid, amount),
          ),
        ],
      ),
    );
  }

  Future<void> _depositFeexpay(String uid, num amount) async {
    Navigator.pop(context);
    final phoneCtrl = TextEditingController();
    String network = 'mtn';
    final cachedPhone = await PhoneNumberCache().load();
    if (cachedPhone != null) phoneCtrl.text = cachedPhone;
    await showAppBottomSheet(
      context,
      title: 'Paiement Mobile Money',
      child: StatefulBuilder(builder: (context, setSheetState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              children: ['mtn', 'moov', 'celtiis_bj', 'coris'].map((n) {
                final selected = network == n;
                return ChoiceChip(
                  label: Text(n),
                  selected: selected,
                  onSelected: (_) => setSheetState(() => network = n),
                  selectedColor: AppColors.gold,
                  labelStyle: TextStyle(
                      color: selected ? Colors.black : AppColors.textPrimary),
                );
              }).toList(),
            ),
            SizedBox(height: 12),
            PhoneNumberField(
                initialValue: cachedPhone,
                onChanged: (v) => phoneCtrl.text = v),
            SizedBox(height: 16),
            DebouncedButton(
              label: 'Payer $amount XOF',
              onPressed: () async {
                if (phoneCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Renseignez votre numéro Mobile Money.')));
                  return;
                }
                try {
                  await ApiClient.instance
                      .post('/api/wallet/$uid/deposit', data: {
                    'amount': amount,
                    'provider': 'feexpay',
                    'network': network,
                    'phoneNumber': phoneCtrl.text.trim(),
                  });
                  await PhoneNumberCache().save(phoneCtrl.text.trim());
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(
                              'Dépôt en cours — validez sur votre téléphone.')),
                    );
                    _load();
                  }
                } catch (e) {
                  if (mounted)
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(friendlyError(e))));
                }
              },
            ),
          ],
        );
      }),
    );
  }

  Future<void> _depositVerzapay(String uid, num amount) async {
    Navigator.pop(context);
    await payWithVerzapayFlow(
      context,
      title: 'Carte bancaire / International — $amount XOF',
      initiate: (phone) => ApiClient.instance.post('/api/wallet/$uid/deposit', data: {
        'amount': amount,
        'provider': 'verzapay',
        'phoneNumber': phone,
      }),
      onSuccess: () {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Dépôt en cours de traitement.')));
          _load();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
          title: Text('Portefeuille Livra'),
          actions: [notificationBellAction(context)]),
      body: swipeableTab(
        context: context,
        currentIndex: 2,
        child: _wallet == null
            ? SkeletonCardList()
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.gold,
                child: ListView(
                  padding: EdgeInsets.all(20),
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppColors.surface,
                          AppColors.surfaceElevated
                        ]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Solde disponible',
                              style: TextStyle(color: AppColors.textSecondary)),
                          SizedBox(height: 6),
                          Text('${_wallet!['balance'] ?? 0} XOF',
                              style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gold)),
                          if ((_wallet!['pendingBalance'] ?? 0) > 0) ...[
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.lock_clock_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  '${_wallet!['pendingBalance']} XOF en attente (disponible sous 3 jours)',
                                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                          SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                  child: PrimaryButton(
                                      label: 'Déposer', onPressed: _deposit)),
                              SizedBox(width: 12),
                              Expanded(
                                  child: PrimaryButton(
                                      label: 'Retirer',
                                      onPressed: _withdraw,
                                      outlined: true)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Transactions',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: AppColors.textPrimary)),
                        TextButton(
                          onPressed: () {},
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0)),
                          child: Text('Voir tout',
                              style: TextStyle(
                                  color: AppColors.gold,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    if ((_wallet!['transactions'] as List).isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            vertical: 40, horizontal: 24),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppColors.goldSoft),
                              child: Icon(Icons.receipt_long_outlined,
                                  color: AppColors.textSecondary, size: 32),
                            ),
                            const SizedBox(height: 16),
                            Text('Aucune transaction',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: AppColors.textPrimary)),
                            const SizedBox(height: 8),
                            Text(
                              'Vos transactions récentes apparaîtront ici une fois que vous aurez effectué des opérations.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 13,
                                  height: 1.4),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List<Widget>.from(
                          (_wallet!['transactions'] as List).map((t) {
                        final isCredit = t['type'] == 'credit';
                        final isPending = t['matured'] == false;
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                                isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                color: isCredit ? AppColors.success : AppColors.danger),
                            // BUG CORRIGE: affichait le code brut du backend
                            // (ex: "delivery_earnings") au lieu d'un vrai texte.
                            title: Text(walletReasonLabelFr(t['reason'])),
                            subtitle: isPending
                                ? Text('En attente (3 jours)', style: TextStyle(color: AppColors.textSecondary, fontSize: 12))
                                : null,
                            trailing: Text(
                              '${isCredit ? '+' : '-'}${t['amount']} XOF',
                              style: TextStyle(fontWeight: FontWeight.w600, color: isCredit ? AppColors.success : AppColors.textPrimary),
                            ),
                          ),
                        );
                      })),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const AppBottomNav(currentIndex: 2),
    );
  }
}
