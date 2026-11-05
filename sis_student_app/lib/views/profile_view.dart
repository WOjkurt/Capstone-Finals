import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/profile_bloc.dart';
import '../models/student_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';

class ProfileView extends StatefulWidget {
  final String email;

  const ProfileView({super.key, required this.email});

  @override
  State<ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<ProfileView> {
  @override
  void initState() {
    super.initState();
    context.read<ProfileBloc>().add(LoadProfileEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileBloc, ProfileState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.scaffoldBg,
          body: RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(LoadProfileEvent(refresh: true));
            },
            color: AppColors.primary,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader(state)),
                ..._buildBodySlivers(state),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(ProfileState state) {
    return PageHeader(
      title: 'Profile',
      subtitle: 'Your student account and enrollment details.',
      onRefresh: () => context.read<ProfileBloc>().add(LoadProfileEvent(refresh: true)),
    );
  }

  // ── Body Slivers ────────────────────────────────────────────────────────────

  List<Widget> _buildBodySlivers(ProfileState state) {
    if (state is ProfileInitial || state is ProfileLoading) {
      return [
        const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(48),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
        ),
      ];
    }

    if (state is ProfileError) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildErrorState(state.message),
        ),
      ];
    }

    if (state is ProfileLoaded) {
      return _buildLoadedSlivers(state.profile);
    }

    return [];
  }

  List<Widget> _buildLoadedSlivers(StudentProfileModel profile) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Avatar + Name card ─────────────────────────────────────────
              _buildIdentityCard(profile),
              const SizedBox(height: 12),
              // ── Academic details card ──────────────────────────────────────
              _buildAcademicCard(profile),
              const SizedBox(height: 12),
              // ── Account card ───────────────────────────────────────────────
              _buildAccountCard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ];
  }

  // ── Identity Card ───────────────────────────────────────────────────────────

  Widget _buildIdentityCard(StudentProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Initials avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.center,
            child: Text(
              profile.initials,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName.isNotEmpty ? profile.fullName : 'Student',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                if (profile.lrn != null && profile.lrn!.isNotEmpty)
                  _inlineDetail('LRN', profile.lrn!),
                _statusChip(profile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(StudentProfileModel profile) {
    final isEnrolled = profile.studentStatus == 1;
    final bg = isEnrolled ? AppColors.accentGreenLight : const Color(0xFFF1F5F9);
    final fg = isEnrolled ? AppColors.accentGreen : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          profile.studentStatusLabel,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ),
    );
  }

  // ── Academic Card ───────────────────────────────────────────────────────────

  Widget _buildAcademicCard(StudentProfileModel profile) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Academic Information'),
          const SizedBox(height: 14),
          _detailRow('Program', profile.programDisplay),
          _divider(),
          _detailRow('Year Level', profile.yearLevelLabel),
          _divider(),
          _detailRow('Student Type', profile.studentTypeLabel),
          _divider(),
          _detailRow('Enrollment Type', profile.regularStatusLabel),
        ],
      ),
    );
  }

  // ── Account Card ────────────────────────────────────────────────────────────

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Account'),
          const SizedBox(height: 14),
          _detailRow('Email', widget.email, stacked: true),
          _divider(),
          _detailRow('Role', 'Student'),
        ],
      ),
    );
  }

  // ── Error State ─────────────────────────────────────────────────────────────

  Widget _buildErrorState(String message) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 28),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could Not Load Profile',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () {
                  context
                      .read<ProfileBloc>()
                      .add(LoadProfileEvent(refresh: true));
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: AppColors.cardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.0,
      ),
    );
  }

  /// [stacked] puts the value under the label, for long values like a school email on a phone.
  Widget _detailRow(String label, String value, {bool stacked = false}) {
    if (stacked) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(value,
                style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(height: 1, color: AppColors.borderSubtle);
  }
}
