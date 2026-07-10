import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';
import '../models/banking_models.dart';
import '../services/api_service.dart';

class ApplicationStatusScreen extends StatefulWidget {
  final String customerId;
  const ApplicationStatusScreen({super.key, required this.customerId});

  @override
  State<ApplicationStatusScreen> createState() => _ApplicationStatusScreenState();
}

class _ApplicationStatusScreenState extends State<ApplicationStatusScreen> {
  final ApiService _apiService = ApiService();
  late Future<HomeData> _homeDataFuture;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = _apiService.getHomeData(widget.customerId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<HomeData>(
      future: _homeDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final application = snapshot.data?.latestApplication;

        return CustomScrollView(
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              backgroundColor: AppColors.surface,
              elevation: 0,
              scrolledUnderElevation: 1,
              automaticallyImplyLeading: false,
              title: Text('Application Status',
                  style: GoogleFonts.inter(
                      fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.primary)),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: AppColors.primary),
                  onPressed: () {},
                ),
              ],
            ),
            if (application == null)
              const SliverFillRemaining(
                child: Center(child: Text('No active application found')),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildStatusCard(application),
                    const SizedBox(height: 32),
                    _buildTimeline(application),
                    const SizedBox(height: 40),
                    _buildHelpSection(),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> app) {
    final status = app['status'] ?? 'In Review';
    final productName = app['selected_product_name'] ?? 'Credit Card';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primaryContainer,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            productName,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Application ID: ${app['application_id'] ?? 'APP-123456'}',
            style: GoogleFonts.inter(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(Map<String, dynamic> app) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Timeline',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 24),
        _timelineItem('Application Submitted', 'We have received your application.', true, false),
        _timelineItem('Document Verification', 'Our team is verifying your documents.', true, false),
        _timelineItem('Credit Assessment', 'We are reviewing your credit history.', false, false),
        _timelineItem('Final Decision', 'You will be notified via email and app.', false, true),
      ],
    );
  }

  Widget _timelineItem(String title, String subtitle, bool isCompleted, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isCompleted ? AppColors.secondary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted ? AppColors.secondary : AppColors.outline,
                    width: 2,
                  ),
                ),
                child: isCompleted
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.secondary : AppColors.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? AppColors.primary : AppColors.onSurfaceVariant,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppColors.secondary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need help?',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Contact our support team if you have any questions about your application.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
