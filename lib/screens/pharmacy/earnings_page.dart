import 'package:abc_app/models/user_model.dart';
import 'package:abc_app/services/firestore_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EarningsPage extends StatelessWidget {
  const EarningsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final FirestoreService firestoreService = FirestoreService();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Earnings'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getPharmacyEarnings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No earnings found.'));
          }

          final earningsDocs = snapshot.data!.docs;

          // Calculate totals
          double totalEarnings = 0;
          double thisWeekEarnings = 0;
          int ordersDelivered = 0;
          int thisWeekOrders = 0;

          final now = DateTime.now();
          final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

          for (var doc in earningsDocs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'Completed') {
              totalEarnings += (data['amount'] as num?)?.toDouble() ?? 0.0;
              ordersDelivered++;

              final createdAt = (data['createdAt'] as Timestamp).toDate();
              if (createdAt.isAfter(startOfWeek)) {
                thisWeekEarnings += (data['amount'] as num?)?.toDouble() ?? 0.0;
                thisWeekOrders++;
              }
            }
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(firestoreService),
                  const SizedBox(height: 24),
                  _buildOverallStats(totalEarnings, ordersDelivered),
                  const SizedBox(height: 24),
                  const Text('This Week',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildThisWeekStats(thisWeekEarnings, thisWeekOrders),
                  const SizedBox(height: 24),
                  const Text('Recent Earnings',
                      style:
                      TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildRecentEarningsList(earningsDocs),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(FirestoreService firestoreService) {
    return StreamBuilder<UserModel>(
      stream: firestoreService.getCurrentUserStream(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final user = snapshot.data!;
        final displayName = user.pharmacyName ?? user.name;
        final profileImageUrl = user.profileImageUrl;
        bool hasImage = profileImageUrl.isNotEmpty;

        return Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                hasImage ? NetworkImage(profileImageUrl) : null,
                child: !hasImage
                    ? Icon(Icons.person, size: 40, color: Colors.grey[600])
                    : null,
              ),
              const SizedBox(height: 12),
              Text(
                displayName,
                style:
                const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                'ID: ${user.uid.substring(0, 8)}...',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOverallStats(double totalEarnings, int ordersDelivered) {
    return Row(
      children: [
        _buildStatCard('Total Earnings', 'Rs ${totalEarnings.toStringAsFixed(0)}'),
        const SizedBox(width: 16),
        _buildStatCard('Orders Delivered', ordersDelivered.toString()),
        const SizedBox(width: 16),
        _buildStatCard('Average Rating', '4.9'), // Placeholder
      ],
    );
  }

  Widget _buildThisWeekStats(double thisWeekEarnings, int thisWeekOrders) {
    return Row(
      children: [
        _buildStatCard('Total Earnings', 'Rs ${thisWeekEarnings.toStringAsFixed(0)}', isPrimary: false),
        const SizedBox(width: 16),
        _buildStatCard('Orders Delivered', thisWeekOrders.toString(), isPrimary: false),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, {bool isPrimary = true}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.grey[100] : Colors.blue[50],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentEarningsList(List<QueryDocumentSnapshot> docs) {
    final completedEarnings = docs.where((doc) => (doc.data() as Map<String, dynamic>)['status'] == 'Completed').toList();

    if (completedEarnings.isEmpty) {
      return const Center(child: Text('No completed orders yet.'));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: completedEarnings.length > 5 ? 5 : completedEarnings.length, // Show max 5
      itemBuilder: (context, index) {
        final data = completedEarnings[index].data() as Map<String, dynamic>;
        final orderId = (data['orderId'] as String?) ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;

        return ListTile(
          title: const Text('Order Completed', style: TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text('Order ID: #${orderId.substring(0, 6)}...'),
          trailing: Text('Rs ${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        );
      },
    );
  }
}
