import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/staff_bloc.dart';
import '../injection.dart';
import '../models/setup_models.dart';
import '../models/staff_model.dart';
import '../repositories/enrollment_repository.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

class StaffManagementView extends StatefulWidget {
  const StaffManagementView({super.key});

  @override
  State<StaffManagementView> createState() => _StaffManagementViewState();
}

class _StaffManagementViewState extends State<StaffManagementView> {
  final TextEditingController _searchController = TextEditingController();
  List<AcademicProgramModel> _programs = [];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<StaffBloc>();
    if (bloc.state.staffList.isEmpty && !bloc.state.isLoading) {
      bloc.add(LoadStaffList());
    }
    _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      final list = await getIt<AcademicSetupRepository>().getPrograms();
      if (mounted) {
        setState(() => _programs = list);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showPasswordResetDialog(BuildContext context, StaffModel staff) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 24),
            const SizedBox(width: 10),
            const Text(
              'Staff Account Created',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'An account for ${staff.fullName} (${staff.email}) has been successfully generated.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 16),
              if (staff.firebaseSyncWarning != null && staff.firebaseSyncWarning!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          staff.firebaseSyncWarning!,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF92400E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (staff.passwordResetLink != null && staff.passwordResetLink!.isNotEmpty) ...[
                const Text(
                  'Password Setup Link:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: SelectableText(
                    staff.passwordResetLink!,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Share this link with the new staff member so they can set their password.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
        actions: [
          if (staff.passwordResetLink != null && staff.passwordResetLink!.isNotEmpty)
            ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: staff.passwordResetLink!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Password setup link copied to clipboard!'),
                    backgroundColor: Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Link'),
            ),
          TextButton(
            onPressed: () {
              context.read<StaffBloc>().add(ClearStaffCreatedEvent());
              Navigator.of(ctx).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _openAddStaffDialog(BuildContext context) {
    if (_programs.isEmpty) {
      _loadPrograms();
    }
    final formKey = GlobalKey<FormState>();
    final emailCtrl = TextEditingController();
    final firstCtrl = TextEditingController();
    final lastCtrl = TextEditingController();
    final empIdCtrl = TextEditingController();
    int selectedRole = 2; // Default to Registrar (2)
    int? selectedProgramId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return BlocProvider.value(
            value: context.read<StaffBloc>(),
            child: BlocConsumer<StaffBloc, StaffState>(
              listener: (consumerCtx, state) {
                if (!state.isSubmitting && state.createdStaff != null) {
                  Navigator.of(dialogCtx).pop();
                  _showPasswordResetDialog(context, state.createdStaff!);
                }
              },
              builder: (consumerCtx, state) {
                return AlertDialog(
                  title: const Text(
                    'Add New Staff Member',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  content: SizedBox(
                    width: 460,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: emailCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Institutional Email *',
                                hintText: 'username@dbtc-cebu.edu.ph',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.email_outlined),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Email is required';
                                }
                                final trimmed = val.trim().toLowerCase();
                                if (!trimmed.endsWith('@dbtc-cebu.edu.ph')) {
                                  return 'Email must end with @dbtc-cebu.edu.ph';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name *',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => (val == null || val.trim().isEmpty)
                                        ? 'First name is required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: lastCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Last Name *',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => (val == null || val.trim().isEmpty)
                                        ? 'Last name is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              initialValue: selectedRole,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Role *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 2, child: Text('Registrar')),
                                DropdownMenuItem(value: 3, child: Text('Teacher')),
                                DropdownMenuItem(value: 4, child: Text('Program Head')),
                                DropdownMenuItem(value: 6, child: Text('College Head')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedRole = val;
                                    if (selectedRole != 3 && selectedRole != 4) {
                                      selectedProgramId = null;
                                    }
                                  });
                                }
                              },
                            ),
                            if (selectedRole == 3 || selectedRole == 4) ...[
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int?>(
                                key: ValueKey('program_dropdown_$selectedRole'),
                                initialValue: selectedProgramId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: selectedRole == 4
                                      ? 'Academic Program *'
                                      : 'Academic Program (Optional)',
                                  helperText: selectedRole == 4
                                      ? 'Program Head access is strictly scoped to this program.'
                                      : 'Assign to department or leave empty for General Education.',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.school_outlined),
                                ),
                                items: [
                                  if (selectedRole == 3)
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        'None / General Education',
                                        style: TextStyle(color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  ..._programs.map(
                                    (p) => DropdownMenuItem<int?>(
                                      value: p.programId,
                                      child: Text('${p.programCode} - ${p.programName}'),
                                    ),
                                  ),
                                ],
                                validator: (val) {
                                  if (selectedRole == 4 && (val == null || val == 0)) {
                                    return 'Academic program is required for Program Head';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  setDialogState(() => selectedProgramId = val);
                                },
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: empIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Employee ID (Optional)',
                                hintText: 'e.g. 1024',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (int.tryParse(val.trim()) == null) {
                                    return 'Please enter a valid integer';
                                  }
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: state.isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              if (formKey.currentState?.validate() ?? false) {
                                final empIdText = empIdCtrl.text.trim();
                                final req = CreateStaffRequest(
                                  email: emailCtrl.text.trim(),
                                  firstname: firstCtrl.text.trim(),
                                  lastname: lastCtrl.text.trim(),
                                  role: selectedRole,
                                  employeeId: empIdText.isNotEmpty ? int.tryParse(empIdText) : null,
                                  programId: (selectedRole == 3 || selectedRole == 4)
                                      ? selectedProgramId
                                      : null,
                                );
                                context.read<StaffBloc>().add(CreateStaffEvent(req));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Create Account'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openEditStaffDialog(BuildContext context, StaffModel staff) {
    if (_programs.isEmpty) {
      _loadPrograms();
    }
    final formKey = GlobalKey<FormState>();
    final firstCtrl = TextEditingController(text: staff.firstname);
    final lastCtrl = TextEditingController(text: staff.lastname);
    final empIdCtrl = TextEditingController(
        text: staff.employeeId != null ? staff.employeeId.toString() : '');
    final initialRole = staff.role;
    int selectedRole = staff.role;
    int? selectedProgramId = staff.programId ?? 0;
    bool isRegular = staff.isRegular;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final wasTeaching = initialRole == 3 || initialRole == 4;
          final isDemotingToRegistrar = wasTeaching && selectedRole == 2;

          return BlocProvider.value(
            value: context.read<StaffBloc>(),
            child: BlocConsumer<StaffBloc, StaffState>(
              listener: (consumerCtx, state) {
                if (!state.isSubmitting && state.updatedStaff != null) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              builder: (consumerCtx, state) {
                return AlertDialog(
                  title: const Text(
                    'Edit Staff Member',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                  content: SizedBox(
                    width: 480,
                    child: Form(
                      key: formKey,
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              initialValue: staff.email,
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Institutional Email',
                                helperText: 'Institutional email cannot be edited.',
                                helperStyle: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.lock_outline),
                                fillColor: Color(0xFFF1F5F9),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: firstCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'First Name *',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => (val == null || val.trim().isEmpty)
                                        ? 'First name is required'
                                        : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: lastCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Last Name *',
                                      border: OutlineInputBorder(),
                                    ),
                                    textCapitalization: TextCapitalization.words,
                                    validator: (val) => (val == null || val.trim().isEmpty)
                                        ? 'Last name is required'
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              key: ValueKey('edit_role_${staff.userId}'),
                              initialValue: selectedRole,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Role *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.badge_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(value: 2, child: Text('Registrar')),
                                DropdownMenuItem(value: 3, child: Text('Teacher')),
                                DropdownMenuItem(value: 4, child: Text('Program Head')),
                                DropdownMenuItem(value: 6, child: Text('College Head')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedRole = val;
                                    if (selectedRole != 3 && selectedRole != 4) {
                                      selectedProgramId = null;
                                    }
                                  });
                                }
                              },
                            ),
                            if (isDemotingToRegistrar) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF59E0B)),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('⚠️ ', style: TextStyle(fontSize: 16)),
                                    Expanded(
                                      child: Text(
                                        'If this staff member has active classes assigned, they will lose grading and teaching access. You\'ll be notified after saving if any classes need reassignment.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF92400E),
                                          fontWeight: FontWeight.w500,
                                          height: 1.3,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (selectedRole == 3 || selectedRole == 4) ...[
                              const SizedBox(height: 14),
                              DropdownButtonFormField<int?>(
                                key: ValueKey('edit_program_${staff.userId}_$selectedRole'),
                                initialValue: selectedProgramId,
                                isExpanded: true,
                                decoration: InputDecoration(
                                  labelText: selectedRole == 4
                                      ? 'Academic Program *'
                                      : 'Academic Program (Optional)',
                                  helperText: selectedRole == 4
                                      ? 'Program Head access is strictly scoped to this program.'
                                      : 'Assign to department or leave empty for General Education.',
                                  border: const OutlineInputBorder(),
                                  prefixIcon: const Icon(Icons.school_outlined),
                                ),
                                items: [
                                  if (selectedRole == 3)
                                    const DropdownMenuItem<int?>(
                                      value: 0,
                                      child: Text(
                                        'None / General Education',
                                        style: TextStyle(color: Color(0xFF64748B)),
                                      ),
                                    ),
                                  ..._programs.map(
                                    (p) => DropdownMenuItem<int?>(
                                      value: p.programId,
                                      child: Text('${p.programCode} - ${p.programName}'),
                                    ),
                                  ),
                                ],
                                validator: (val) {
                                  if (selectedRole == 4 && (val == null || val == 0)) {
                                    return 'Academic program is required for Program Head';
                                  }
                                  return null;
                                },
                                onChanged: (val) {
                                  setDialogState(() => selectedProgramId = val);
                                },
                              ),
                            ],
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: empIdCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Employee ID (Optional)',
                                hintText: 'e.g. 1024',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.numbers_outlined),
                              ),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                if (val != null && val.trim().isNotEmpty) {
                                  if (int.tryParse(val.trim()) == null) {
                                    return 'Please enter a valid integer';
                                  }
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              initialValue: staff.positionName ?? '—',
                              enabled: false,
                              decoration: const InputDecoration(
                                labelText: 'Position',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.work_outline),
                                fillColor: Color(0xFFF1F5F9),
                                filled: true,
                              ),
                            ),
                            const SizedBox(height: 14),
                            SwitchListTile(
                              title: const Text(
                                'Regular Employee',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              subtitle: const Text(
                                'Permanent / regular faculty or staff status',
                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                              value: isRegular,
                              activeThumbColor: AppColors.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() => isRegular = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: state.isSubmitting ? null : () => Navigator.of(dialogCtx).pop(),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () {
                              if (formKey.currentState?.validate() ?? false) {
                                final empIdText = empIdCtrl.text.trim();
                                final req = UpdateStaffRequest(
                                  firstname: firstCtrl.text.trim(),
                                  lastname: lastCtrl.text.trim(),
                                  role: selectedRole,
                                  employeeId: empIdText.isNotEmpty ? int.tryParse(empIdText) : 0,
                                  programId: (selectedRole == 3 || selectedRole == 4)
                                      ? selectedProgramId
                                      : null,
                                  isRegular: isRegular,
                                );
                                context.read<StaffBloc>().add(UpdateStaffEvent(staff.userId, req));
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openDisableDialog(BuildContext context, StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<StaffBloc>(),
        child: AlertDialog(
          title: const Text('Disable Staff Account'),
          content: Text(
            'Are you sure you want to disable ${staff.fullName}\'s account?\n\nThis will prevent ${staff.fullName} from signing in until reactivated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<StaffBloc>().add(DisableStaffEvent(staff.userId));
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm Disable'),
            ),
          ],
        ),
      ),
    );
  }

  void _openReactivateDialog(BuildContext context, StaffModel staff) {
    showDialog(
      context: context,
      builder: (ctx) => BlocProvider.value(
        value: context.read<StaffBloc>(),
        child: AlertDialog(
          title: const Text('Reactivate Staff Account'),
          content: Text(
            'Are you sure you want to reactivate ${staff.fullName}\'s account? They will be able to sign in again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<StaffBloc>().add(ReactivateStaffEvent(staff.userId));
                Navigator.of(ctx).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Confirm Reactivation'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String roleName, [String? programCode]) {
    Color bg;
    Color fg;
    switch (roleName.toLowerCase()) {
      case 'admin':
        bg = const Color(0xFFF3E8FF);
        fg = const Color(0xFF7E22CE);
        break;
      case 'registrar':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1E40AF);
        break;
      case 'program head':
        bg = const Color(0xFFE0E7FF);
        fg = const Color(0xFF3730A3);
        break;
      case 'college head':
        bg = const Color(0xFFCCFBF1);
        fg = const Color(0xFF0F766E);
        break;
      case 'teacher':
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFB45309);
        break;
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }
    final label = (programCode != null && programCode.isNotEmpty)
        ? '$roleName ($programCode)'
        : roleName;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<StaffBloc, StaffState>(
        listener: (context, state) {
          if (state.warningMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.warningMessage!)),
                  ],
                ),
                backgroundColor: const Color(0xFFD97706),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 6),
              ),
            );
            context.read<StaffBloc>().add(ClearStaffMessagesEvent());
          } else if (state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.successMessage!),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<StaffBloc>().add(ClearStaffMessagesEvent());
          } else if (state.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(child: Text(state.errorMessage!)),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 4),
              ),
            );
            context.read<StaffBloc>().add(ClearStaffMessagesEvent());
          }
        },
        builder: (context, state) {
          final query = _searchController.text.trim().toLowerCase();
          final filteredStaff = query.isEmpty
              ? state.staffList
              : state.staffList.where((s) {
                  final fullName = s.fullName.toLowerCase();
                  final email = s.email.toLowerCase();
                  final role = s.roleName.toLowerCase();
                  return fullName.contains(query) ||
                      email.contains(query) ||
                      role.contains(query);
                }).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Staff Management',
                subtitle:
                    'Create and manage accounts for Registrars, Teachers, Program Heads, and College Heads.',
                action: ElevatedButton.icon(
                  onPressed: () => _openAddStaffDialog(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Add Staff'),
                ),
              ),
              // Search & Filter Toolbar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Text(
                      'All Staff (${state.staffList.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: 340,
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search by name, email, or role...',
                          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.primary),
                      tooltip: 'Refresh staff list',
                      onPressed: () => context.read<StaffBloc>().add(LoadStaffList()),
                    ),
                  ],
                ),
              ),
              // Content Area
              Expanded(
                child: state.isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : filteredStaff.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                Text(
                                  _searchController.text.isNotEmpty
                                      ? 'No staff members match "${_searchController.text}".'
                                      : 'No staff accounts found.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(32),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                        child: DataTable(
                                          headingRowColor:
                                              WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                          horizontalMargin: 24,
                                          columns: const [
                                            DataColumn(
                                              label: Text('Staff Member',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Role',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Employee ID',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Position',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Status',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Created At',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                            DataColumn(
                                              label: Text('Actions',
                                                  style: TextStyle(fontWeight: FontWeight.w700)),
                                            ),
                                          ],
                                          rows: filteredStaff.map((s) {
                                            final isProcessing = state.processingId == s.userId;

                                            return DataRow(
                                              cells: [
                                                DataCell(
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: [
                                                      Text(
                                                        s.fullName,
                                                        style: const TextStyle(
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                          color: Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      Text(
                                                        s.email,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(0xFF64748B),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DataCell(_buildRoleBadge(s.roleName, s.programCode)),
                                                DataCell(
                                                  Text(
                                                    s.employeeId != null ? '${s.employeeId}' : '—',
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    s.positionName ?? '—',
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                DataCell(
                                                  s.isActive
                                                      ? StatusBadge.success(label: 'Active')
                                                      : StatusBadge.danger(label: 'Disabled'),
                                                ),
                                                DataCell(
                                                  Text(
                                                    dateFormat.format(s.createdAt.toLocal()),
                                                    style: const TextStyle(fontSize: 13),
                                                  ),
                                                ),
                                                DataCell(
                                                  isProcessing
                                                      ? const SizedBox(
                                                          width: 20,
                                                          height: 20,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: AppColors.primary,
                                                          ),
                                                        )
                                                      : Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            if (s.role != 1 && s.roleName.toLowerCase() != 'admin') ...[
                                                              OutlinedButton.icon(
                                                                onPressed: () => _openEditStaffDialog(context, s),
                                                                style: OutlinedButton.styleFrom(
                                                                  foregroundColor: AppColors.primary,
                                                                  side: BorderSide(
                                                                      color: AppColors.primary.withValues(alpha: 0.3)),
                                                                  padding: const EdgeInsets.symmetric(
                                                                      horizontal: 10, vertical: 6),
                                                                  minimumSize: const Size(70, 30),
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(6),
                                                                  ),
                                                                ),
                                                                icon: const Icon(Icons.edit_outlined, size: 14),
                                                                label: const Text('Edit',
                                                                    style: TextStyle(fontSize: 12)),
                                                              ),
                                                              const SizedBox(width: 8),
                                                            ],
                                                            s.isActive
                                                                ? OutlinedButton.icon(
                                                                    onPressed: () =>
                                                                        _openDisableDialog(context, s),
                                                                    style: OutlinedButton.styleFrom(
                                                                      foregroundColor:
                                                                          const Color(0xFFDC2626),
                                                                      side: const BorderSide(
                                                                          color: Color(0xFFFCA5A5)),
                                                                      padding: const EdgeInsets.symmetric(
                                                                          horizontal: 10, vertical: 6),
                                                                      minimumSize: const Size(80, 30),
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(6),
                                                                      ),
                                                                    ),
                                                                    icon: const Icon(Icons.block, size: 14),
                                                                    label: const Text('Disable',
                                                                        style: TextStyle(fontSize: 12)),
                                                                  )
                                                                : OutlinedButton.icon(
                                                                    onPressed: () =>
                                                                        _openReactivateDialog(context, s),
                                                                    style: OutlinedButton.styleFrom(
                                                                      foregroundColor:
                                                                          const Color(0xFF059669),
                                                                      side: const BorderSide(
                                                                          color: Color(0xFF6EE7B7)),
                                                                      padding: const EdgeInsets.symmetric(
                                                                          horizontal: 10, vertical: 6),
                                                                      minimumSize: const Size(80, 30),
                                                                      shape: RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(6),
                                                                      ),
                                                                    ),
                                                                    icon: const Icon(Icons.check_circle_outline,
                                                                        size: 14),
                                                                    label: const Text('Reactivate',
                                                                        style: TextStyle(fontSize: 12)),
                                                                  ),
                                                          ],
                                                        ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
