import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/models/notification_model.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/empty_state.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('userId', isEqualTo: uid)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return SkeletonCardList();
          final items = snapshot.data!.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList();
          if (items.isEmpty) return EmptyState(icon: Icons.notifications_none_rounded, message: 'Aucune notification pour le moment.');
          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final n = items[i];
              return Card(
                margin: EdgeInsets.only(bottom: 10),
                color: n.read ? AppColors.surface : AppColors.surfaceElevated,
                child: ListTile(
                  leading: Icon(Icons.circle, size: 10, color: n.read ? Colors.transparent : AppColors.gold),
                  title: Text(n.title, style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(n.body),
                  onTap: () => FirebaseFirestore.instance.collection('notifications').doc(n.id).update({'read': true}),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
