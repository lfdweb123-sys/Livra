import 'dart:async';
import 'package:flutter/material.dart';
import 'package:twilio_voice/twilio_voice.dart';
import '../services/twilio_call_service.dart';
import '../theme/app_colors.dart';

class InAppCallScreen extends StatefulWidget {
  final String name;
  const InAppCallScreen({super.key, required this.name});

  @override
  State<InAppCallScreen> createState() => _InAppCallScreenState();
}

class _InAppCallScreenState extends State<InAppCallScreen> {
  StreamSubscription? _sub;
  String _status = 'Appel en cours...';
  bool _muted = false;
  bool _speakerOn = false;
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    _sub = TwilioCallService.instance.events.listen((event) {
      if (!mounted) return;
      switch (event) {
        case CallEvent.ringing:
          setState(() => _status = 'Ça sonne...');
          break;
        case CallEvent.connected:
          setState(() => _status = 'En communication');
          break;
        case CallEvent.reconnecting:
          setState(() => _status = 'Reconnexion...');
          break;
        case CallEvent.callEnded:
        case CallEvent.declined:
        case CallEvent.missedCall:
          _closeCall();
          break;
        default:
          break;
      }
    });
  }

  void _closeCall() {
    if (_ended) return;
    _ended = true;
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          TwilioCallService.instance.hangUp();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppColors.surfaceElevated,
                  child: Text(widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 20),
                Text(widget.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(_status, style: TextStyle(color: AppColors.textSecondary)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _controlButton(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      active: _muted,
                      onTap: () {
                        setState(() => _muted = !_muted);
                        TwilioCallService.instance.toggleMute(_muted);
                      },
                    ),
                    _controlButton(
                      icon: _speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                      active: _speakerOn,
                      onTap: () {
                        setState(() => _speakerOn = !_speakerOn);
                        TwilioCallService.instance.toggleSpeaker(_speakerOn);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                GestureDetector(
                  onTap: () {
                    TwilioCallService.instance.hangUp();
                    _closeCall();
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
                    child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlButton({required IconData icon, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: active ? AppColors.gold : AppColors.surfaceElevated, shape: BoxShape.circle),
        child: Icon(icon, color: active ? Colors.black : AppColors.textPrimary),
      ),
    );
  }
}
