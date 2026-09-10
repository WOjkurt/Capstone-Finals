import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/responses_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';

class ResponsesView extends StatefulWidget {
  const ResponsesView({super.key});

  @override
  State<ResponsesView> createState() => _ResponsesViewState();
}

class _ResponsesViewState extends State<ResponsesView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final bloc = context.read<ResponsesBloc>();
    if (bloc.state is ResponsesInitial) {
      bloc.add(LoadResponses());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: BlocConsumer<ResponsesBloc, ResponsesState>(
        listener: (context, state) {
          if (state is ResponsesActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFF10B981),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ResponsesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final totalCount = (state is ResponsesLoaded)
              ? state.responses.length
              : (state is ResponsesError ? state.responses?.length ?? 0 : 0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PageHeader(
                title: 'Enrollment Responses',
                subtitle:
                    'Incoming Google Forms submissions awaiting conversion into formal applications.',
                action: ElevatedButton.icon(
                  onPressed: () =>
                      context.read<ResponsesBloc>().add(LoadResponses()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Refresh'),
                ),
              ),
              _buildSearchBar(context, totalCount),
              Expanded(
                child: _buildContent(context, state),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Text(
            '$totalCount Unprocessed ${totalCount == 1 ? "Response" : "Responses"}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 320,
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search by applicant email...',
                hintStyle:
                    TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon:
                    const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
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
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
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
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, ResponsesState state) {
    if (state is ResponsesLoading || state is ResponsesInitial) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state is ResponsesError && (state.responses == null || state.responses!.isEmpty)) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFCA5A5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 48),
              const SizedBox(height: 12),
              Text(
                'Failed to load responses',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF991B1B),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF4B5563)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    context.read<ResponsesBloc>().add(LoadResponses()),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final responses = (state is ResponsesLoaded)
        ? state.responses
        : (state is ResponsesError ? state.responses ?? [] : <EnrollmentResponseModel>[]);
    final programs = (state is ResponsesLoaded)
        ? state.programs
        : (state is ResponsesError ? state.programs ?? [] : <AcademicProgramModel>[]);
    final terms = (state is ResponsesLoaded)
        ? state.terms
        : (state is ResponsesError ? state.terms ?? [] : <AcademicTermModel>[]);

    if (responses.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No Unprocessed Responses',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'All intake responses from Google Forms have been processed.',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final filteredResponses = query.isEmpty
        ? responses
        : responses.where((r) => r.emailAddress.toLowerCase().contains(query)).toList();

    if (filteredResponses.isEmpty && query.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No responses found matching "$query"',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334155),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear search'),
            ),
          ],
        ),
      );
    }

    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
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
                    columnSpacing: 32,
                    columns: const [
                      DataColumn(
                        label: Text('Applicant Email',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Submitted At',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Intake Status',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      DataColumn(
                        label: Text('Actions',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ],
                    rows: filteredResponses.map((r) {
                      return DataRow(
                        cells: [
                          DataCell(
                            Row(
                              children: [
                                const Icon(Icons.email_outlined,
                                    size: 16, color: Color(0xFF64748B)),
                                const SizedBox(width: 8),
                                Text(
                                  r.emailAddress,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(dateFormat.format(r.timestamp.toLocal())),
                          ),
                          DataCell(
                            StatusBadge.pending(label: 'Unprocessed'),
                          ),
                          DataCell(
                            ElevatedButton.icon(
                              onPressed: () => _openProcessDialog(
                                  context, r, programs, terms),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
                              label: const Text('Process into application',
                                  style: TextStyle(fontSize: 12)),
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
    );
  }

  void _openProcessDialog(
    BuildContext context,
    EnrollmentResponseModel response,
    List<AcademicProgramModel> programs,
    List<AcademicTermModel> terms,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => BlocProvider.value(
        value: context.read<ResponsesBloc>(),
        child: _ProcessApplicationDialog(
          response: response,
          programs: programs,
          terms: terms,
          onSubmit: (programId, termId, form, contacts) {
            context.read<ResponsesBloc>().add(ProcessResponseSubmitted(
                  responseId: response.responseId,
                  programId: programId,
                  termId: termId,
                  form: form,
                  contacts: contacts,
                ));
          },
        ),
      ),
    );
  }
}

class _ProcessApplicationDialog extends StatefulWidget {
  final EnrollmentResponseModel response;
  final List<AcademicProgramModel> programs;
  final List<AcademicTermModel> terms;
  final Function(int programId, String termId, EnrollmentFormModel form,
      List<ContactModel> contacts) onSubmit;

  const _ProcessApplicationDialog({
    required this.response,
    required this.programs,
    required this.terms,
    required this.onSubmit,
  });

  @override
  State<_ProcessApplicationDialog> createState() =>
      _ProcessApplicationDialogState();
}

class _ProcessApplicationDialogState extends State<_ProcessApplicationDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedProgramId;
  String? _selectedTermId;

  // Enrollment Form Controllers
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _pobCtrl;
  late String _sex;
  late String _civilStatus;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _barangayCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _zipCtrl;
  late final TextEditingController _lastSchoolCtrl;
  late final TextEditingController _schoolAddressCtrl;
  late int _shsStrand;
  late final TextEditingController _yearGraduatedCtrl;
  late final TextEditingController _prevCollegeCtrl;
  late final TextEditingController _prevCourseCtrl;
  late int _yearLevel;
  late final TextEditingController _previousStudentIdCtrl;

  // Contacts
  late final List<_ContactItemData> _contacts;

  @override
  void initState() {
    super.initState();
    final formData = widget.response.data?.form;
    final contactsData = widget.response.data?.contacts ?? [];

    _firstNameCtrl = TextEditingController(text: formData?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: formData?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: formData?.lastName ?? '');
    _suffixCtrl = TextEditingController(text: formData?.suffix ?? '');
    _dobCtrl = TextEditingController(text: formData?.dateOfBirth ?? '');
    _pobCtrl = TextEditingController(text: formData?.placeOfBirth ?? '');
    _sex = (formData != null && formData.sex.isNotEmpty) ? formData.sex : 'Male';
    _civilStatus = (formData != null && formData.civilStatus.isNotEmpty) ? formData.civilStatus : 'Single';
    _nationalityCtrl = TextEditingController(text: formData?.nationality ?? '');
    _mobileCtrl = TextEditingController(text: formData?.mobileNumber ?? '');
    _barangayCtrl = TextEditingController(text: formData?.barangay ?? '');
    _cityCtrl = TextEditingController(text: formData?.cityMunicipality ?? '');
    _provinceCtrl = TextEditingController(text: formData?.province ?? '');
    _zipCtrl = TextEditingController(text: formData?.zipCode ?? '');
    _lastSchoolCtrl = TextEditingController(text: formData?.lastSchoolAttended ?? '');
    _schoolAddressCtrl = TextEditingController(text: formData?.schoolAddress ?? '');
    _shsStrand = (formData != null && formData.shsStrand > 0) ? formData.shsStrand : 1;
    _yearGraduatedCtrl = TextEditingController(text: formData?.yearGraduated ?? '');
    _prevCollegeCtrl = TextEditingController(text: formData?.previousCollege ?? '');
    _prevCourseCtrl = TextEditingController(text: formData?.previousCourse ?? '');
    _yearLevel = (formData != null && formData.yearLevel > 0) ? formData.yearLevel : 1;
    _previousStudentIdCtrl = TextEditingController(text: formData?.previousStudentID ?? '');

    if (contactsData.isNotEmpty) {
      _contacts = contactsData
          .map((c) => _ContactItemData(
                firstName: TextEditingController(text: c.firstName),
                lastName: TextEditingController(text: c.lastName),
                relationType: c.relationType > 0 ? c.relationType : 1,
                occupation: TextEditingController(text: c.occupation),
                contactNo: TextEditingController(text: c.contactNo),
              ))
          .toList();
    } else {
      _contacts = [
        _ContactItemData(
          firstName: TextEditingController(),
          lastName: TextEditingController(),
          relationType: 1, // Father
          occupation: TextEditingController(),
          contactNo: TextEditingController(),
        ),
      ];
    }

    if (widget.programs.isNotEmpty) {
      final intended = widget.response.data?.intendedProgramCode;
      if (intended != null && intended.isNotEmpty) {
        final match = widget.programs.where(
          (p) => p.programCode.toUpperCase() == intended.trim().toUpperCase(),
        );
        _selectedProgramId = match.isNotEmpty ? match.first.programId : widget.programs.first.programId;
      } else {
        _selectedProgramId = widget.programs.first.programId;
      }
    }
    if (widget.terms.isNotEmpty) {
      _selectedTermId = widget.terms.first.termId;
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _suffixCtrl.dispose();
    _dobCtrl.dispose();
    _pobCtrl.dispose();
    _nationalityCtrl.dispose();
    _mobileCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCtrl.dispose();
    _lastSchoolCtrl.dispose();
    _schoolAddressCtrl.dispose();
    _yearGraduatedCtrl.dispose();
    _prevCollegeCtrl.dispose();
    _prevCourseCtrl.dispose();
    _previousStudentIdCtrl.dispose();
    for (var c in _contacts) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProgramId == null || _selectedTermId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select Program and Term.')),
      );
      return;
    }

    final form = EnrollmentFormModel(
      firstName: _firstNameCtrl.text.trim(),
      middleName: _middleNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      suffix: _suffixCtrl.text.trim(),
      dateOfBirth: _dobCtrl.text.trim(),
      placeOfBirth: _pobCtrl.text.trim(),
      sex: _sex,
      civilStatus: _civilStatus,
      nationality: _nationalityCtrl.text.trim(),
      mobileNumber: _mobileCtrl.text.trim(),
      barangay: _barangayCtrl.text.trim(),
      cityMunicipality: _cityCtrl.text.trim(),
      province: _provinceCtrl.text.trim(),
      zipCode: _zipCtrl.text.trim(),
      lastSchoolAttended: _lastSchoolCtrl.text.trim(),
      schoolAddress: _schoolAddressCtrl.text.trim(),
      shsStrand: _shsStrand,
      yearGraduated: _yearGraduatedCtrl.text.trim(),
      previousCollege: _prevCollegeCtrl.text.trim(),
      previousCourse: _prevCourseCtrl.text.trim(),
      yearLevel: _yearLevel,
      previousStudentID: _previousStudentIdCtrl.text.trim().isNotEmpty
          ? _previousStudentIdCtrl.text.trim()
          : null,
    );

    final contacts = _contacts.map((c) {
      return ContactModel(
        firstName: c.firstName.text.trim(),
        lastName: c.lastName.text.trim(),
        relationType: c.relationType,
        occupation: c.occupation.text.trim(),
        contactNo: c.contactNo.text.trim(),
      );
    }).toList();

    widget.onSubmit(_selectedProgramId!, _selectedTermId!, form, contacts);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
      child: Container(
        width: 850,
        height: 720,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Title Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Process Enrollment Response',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Applicant: ${widget.response.emailAddress}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFBFDBFE),
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),
            // Form Body
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Academic Placement
                      _buildSectionHeader('1. Academic Placement'),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final programIds =
                              widget.programs.map((p) => p.programId).toSet();
                          final effectiveProgramId =
                              programIds.contains(_selectedProgramId)
                                  ? _selectedProgramId
                                  : (widget.programs.isNotEmpty
                                      ? widget.programs.first.programId
                                      : null);

                          final termIds =
                              widget.terms.map((t) => t.termId).toSet();
                          final effectiveTermId =
                              termIds.contains(_selectedTermId)
                                  ? _selectedTermId
                                  : (widget.terms.isNotEmpty
                                      ? widget.terms.first.termId
                                      : null);

                          const validYearLevels = [1, 2, 3, 4, 5];
                          final effectiveYearLevel =
                              validYearLevels.contains(_yearLevel)
                                  ? _yearLevel
                                  : validYearLevels.first;

                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: effectiveProgramId,
                                  decoration: const InputDecoration(
                                    labelText: 'Academic Program *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: widget.programs.map((p) {
                                    return DropdownMenuItem(
                                      value: p.programId,
                                      child: Text(
                                        '${p.programCode} - ${p.programName}',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedProgramId = val),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: effectiveTermId,
                                  decoration: const InputDecoration(
                                    labelText: 'Academic Term *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: widget.terms.map((t) {
                                    return DropdownMenuItem(
                                      value: t.termId,
                                      child: Text(
                                        t.label,
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _selectedTermId = val),
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 120,
                                child: DropdownButtonFormField<int>(
                                  isExpanded: true,
                                  initialValue: effectiveYearLevel,
                                  decoration: const InputDecoration(
                                    labelText: 'Year Level *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: validYearLevels.map((y) {
                                    return DropdownMenuItem(
                                      value: y,
                                      child: Text(
                                        'Year $y',
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (val) =>
                                      setState(() => _yearLevel = val ?? 1),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _previousStudentIdCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Previous Physical Student ID (Optional)',
                          hintText: 'e.g. 2021-12345 (for returning students)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Section: Personal & Demographic
                      _buildSectionHeader('2. Applicant Information'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _firstNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'First Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'First name required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _middleNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Middle Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _lastNameCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Last Name *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'Last name required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 90,
                            child: TextFormField(
                              controller: _suffixCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Suffix',
                                hintText: 'Jr., III',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _dobCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Date of Birth (YYYY-MM-DD) *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  v!.isEmpty ? 'DOB required' : null,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _pobCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Place of Birth *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _sex,
                              decoration: const InputDecoration(
                                labelText: 'Sex *',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Male', 'Female'].map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text(
                                    s,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) => setState(() => _sex = v!),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: _civilStatus,
                              decoration: const InputDecoration(
                                labelText: 'Civil Status *',
                                border: OutlineInputBorder(),
                              ),
                              items: ['Single', 'Married', 'Widowed'].map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _civilStatus = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nationalityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Nationality *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _mobileCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Mobile Number *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section: Address
                      _buildSectionHeader('3. Residential Address'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _barangayCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Barangay *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _cityCtrl,
                              decoration: const InputDecoration(
                                labelText: 'City / Municipality *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _provinceCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Province *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 110,
                            child: TextFormField(
                              controller: _zipCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ZIP Code *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section: Educational Background
                      _buildSectionHeader('4. Educational Background'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _lastSchoolCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Last School Attended *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _schoolAddressCtrl,
                              decoration: const InputDecoration(
                                labelText: 'School Address *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _shsStrand,
                              decoration: const InputDecoration(
                                labelText: 'SHS Strand *',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 1,
                                  child: Text(
                                    'STEM',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 2,
                                  child: Text(
                                    'HUMSS',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 3,
                                  child: Text(
                                    'ABM',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 4,
                                  child: Text(
                                    'GAS',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 5,
                                  child: Text(
                                    'TVL',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _shsStrand = v ?? 1),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _yearGraduatedCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Year Graduated (YYYY-MM-DD) *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _prevCollegeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Previous College (Transferee)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: TextFormField(
                              controller: _prevCourseCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Previous Course (Transferee)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Section: Repeatable Contacts
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildSectionHeader('5. Emergency Contacts'),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _contacts.add(_ContactItemData(
                                  firstName: TextEditingController(),
                                  lastName: TextEditingController(),
                                  relationType: 1,
                                  occupation: TextEditingController(),
                                  contactNo: TextEditingController(),
                                ));
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Another Contact'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ...List.generate(_contacts.length, (index) {
                        final c = _contacts[index];
                        return Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Contact #${index + 1}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  if (_contacts.length > 1)
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: Colors.red),
                                      onPressed: () {
                                        setState(() {
                                          c.dispose();
                                          _contacts.removeAt(index);
                                        });
                                      },
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: c.firstName,
                                      decoration: const InputDecoration(
                                        labelText: 'First Name *',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v!.isEmpty
                                          ? 'Contact first name'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: c.lastName,
                                      decoration: const InputDecoration(
                                        labelText: 'Last Name *',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v!.isEmpty
                                          ? 'Contact last name'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: DropdownButtonFormField<int>(
                                      isExpanded: true,
                                      initialValue: c.relationType,
                                      decoration: const InputDecoration(
                                        labelText: 'Relation *',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 1,
                                          child: Text(
                                            'Father',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 2,
                                          child: Text(
                                            'Mother',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 3,
                                          child: Text(
                                            'Guardian',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 4,
                                          child: Text(
                                            'Sibling',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 5,
                                          child: Text(
                                            'Spouse',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 6,
                                          child: Text(
                                            'Other',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) =>
                                          setState(() => c.relationType = v ?? 1),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: c.occupation,
                                      decoration: const InputDecoration(
                                        labelText: 'Occupation',
                                        border: OutlineInputBorder(),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: TextFormField(
                                      controller: c.contactNo,
                                      decoration: const InputDecoration(
                                        labelText: 'Phone Number *',
                                        border: OutlineInputBorder(),
                                      ),
                                      validator: (v) => v!.isEmpty
                                          ? 'Phone number required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Create Application'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E293B),
      ),
    );
  }
}

class _ContactItemData {
  final TextEditingController firstName;
  final TextEditingController lastName;
  int relationType;
  final TextEditingController occupation;
  final TextEditingController contactNo;

  _ContactItemData({
    required this.firstName,
    required this.lastName,
    required this.relationType,
    required this.occupation,
    required this.contactNo,
  });

  void dispose() {
    firstName.dispose();
    lastName.dispose();
    occupation.dispose();
    contactNo.dispose();
  }
}
