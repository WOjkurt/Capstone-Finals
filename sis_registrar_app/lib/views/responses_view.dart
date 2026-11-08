import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/responses_bloc.dart';
import '../models/enrollment_models.dart';
import '../models/setup_models.dart';
import '../theme/app_theme.dart';
import 'widgets/enye_button.dart';
import 'widgets/page_header.dart';
import 'widgets/status_badge.dart';
import '../utils/formatters.dart';
import '../utils/phone_zip.dart';

class ResponsesView extends StatefulWidget {
  /// False inside the Admissions page, whose tabs already name this page.
  final bool showHeader;

  const ResponsesView({super.key, this.showHeader = true});

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
                backgroundColor: AppColors.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else if (state is ResponsesError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
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
              if (widget.showHeader)
                PageHeader(
                title: 'Form Responses',
                subtitle: 'Google Forms submissions waiting to become enrollment applications.',
                onRefresh: () => context.read<ResponsesBloc>().add(LoadResponses()),
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
                            Text(formatDateTime(r.timestamp.toLocal())),
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
  int _activeTab = 0;

  // ── Tab 1: Enrollment Details ──────────────────────────────────────────────
  int? _selectedProgramId;
  String? _selectedTermId;
  int _yearLevel = 1;
  int? _studentType;
  late final TextEditingController _lrnCtrl;
  late final TextEditingController _academicYearCtrl;
  late final TextEditingController _incomingCourseCtrl;
  late final TextEditingController _previousStudentIdCtrl;

  // ── Tab 2: Personal Info ───────────────────────────────────────────────────
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _genderCtrl;
  late final TextEditingController _ageCtrl;
  String? _bloodType;
  late final TextEditingController _dobCtrl;
  late final TextEditingController _pobCtrl;
  late String _sex;
  late String _civilStatus;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _religionCtrl;
  late final TextEditingController _mobileCtrl;
  late final TextEditingController _facebookNameCtrl;

  // ── Tab 3: Address ─────────────────────────────────────────────────────────
  late final TextEditingController _houseStreetCtrl;
  late final TextEditingController _barangayCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _provinceCtrl;
  late final TextEditingController _zipCtrl;

  late final TextEditingController _provHouseStreetCtrl;
  late final TextEditingController _provBarangayCtrl;
  late final TextEditingController _provCityCtrl;
  late final TextEditingController _provProvinceCtrl;
  late final TextEditingController _provZipCtrl;

  // ── Tab 4: Education ───────────────────────────────────────────────────────
  late final TextEditingController _lastSchoolCtrl;
  late final TextEditingController _schoolAddressCtrl;
  late final TextEditingController _programTrackStrandCtrl;
  late final TextEditingController _yearGraduatedCtrl;
  late final TextEditingController _prevCollegeCtrl;
  late final TextEditingController _prevCourseCtrl;

  // ── Tab 5: Family & Medical ────────────────────────────────────────────────
  String? _birthOrder;
  late final TextEditingController _siblingsCtrl;
  String? _familyStatus;
  late final Set<String> _presentMedicalSelected;
  late final Set<String> _pastMedicalSelected;
  late final Set<String> _immunizationSelected;
  late final TextEditingController _familyMedicalNotesCtrl;
  late final TextEditingController _ongoingMedicationsCtrl;
  late final TextEditingController _developmentalConditionsCtrl;
  late final TextEditingController _otherMedicalDiagnosisCtrl;

  // ── Tab 6: Father / Mother / Guardian Contacts ─────────────────────────────
  late final TextEditingController _fatherFirstNameCtrl;
  late final TextEditingController _fatherLastNameCtrl;
  late final TextEditingController _fatherContactNoCtrl;
  late final TextEditingController _fatherEmailCtrl;
  late final TextEditingController _fatherDobCtrl;
  late final TextEditingController _fatherOccupationCtrl;
  late final TextEditingController _fatherWorkplaceCtrl;
  late final TextEditingController _fatherFacebookCtrl;

  late final TextEditingController _motherFirstNameCtrl;
  late final TextEditingController _motherLastNameCtrl;
  late final TextEditingController _motherContactNoCtrl;
  late final TextEditingController _motherEmailCtrl;
  late final TextEditingController _motherDobCtrl;
  late final TextEditingController _motherOccupationCtrl;
  late final TextEditingController _motherWorkplaceCtrl;
  late final TextEditingController _motherFacebookCtrl;

  late final TextEditingController _guardianFirstNameCtrl;
  late final TextEditingController _guardianLastNameCtrl;
  late final TextEditingController _guardianContactNoCtrl;
  late final TextEditingController _guardianEmailCtrl;
  late final TextEditingController _guardianOccupationCtrl;
  late final TextEditingController _guardianRelationshipDescCtrl;
  bool _guardianLivingWith = false;

  static const List<String> _presentConditionOptions = [
    'Allergies',
    'Birth Deficiencies',
    'Eye-Vision Problems',
    'Hearing Problems',
    'Lung Problems',
    'Physically Challenged',
    'Other',
  ];

  static const List<String> _pastHistoryOptions = [
    'Fractures',
    'Heart Problems',
    'Kidney Problems',
    'Other',
  ];

  static const List<String> _immunizationOptions = [
    'BCG',
    'COVID-19',
    'Diphtheria',
    'Hepatitis A',
    'Hepatitis B',
    'HiB',
    'Influenza A annual',
    'Influenza A not annual',
    'IPV or OPV',
    'MMR',
    'Pertussis',
    'Pneumococcal',
    'Tetanus',
    'Varicella',
  ];

  static const List<String> _bloodTypeOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const List<String> _birthOrderOptions = [
    'Only Child',
    'First Child',
    'Second Child',
    'Third Child',
    'Fourth Child',
    'Fifth Child',
    'Other',
  ];

  static const List<String> _familyStatusOptions = [
    'Parents are Separated',
    'Both parents are present / living together',
    'Father is deceased',
    'Mother is deceased',
    'Both parents are deceased',
    'Mother is living abroad',
    'Father is living abroad',
  ];

  @override
  void initState() {
    super.initState();
    final formData = widget.response.data?.form;
    final contactsData = widget.response.data?.contacts ?? [];

    // Tab 1: Enrollment Placement & Metadata
    _studentType = formData?.studentType;
    _lrnCtrl = TextEditingController(text: formData?.lrn ?? '');
    _academicYearCtrl = TextEditingController(text: formData?.academicYear ?? '');
    _incomingCourseCtrl = TextEditingController(text: formData?.incomingCourse ?? '');
    _previousStudentIdCtrl = TextEditingController(text: formData?.previousStudentID ?? '');
    _yearLevel = (formData != null && formData.yearLevel > 0) ? formData.yearLevel : 1;

    if (widget.programs.isNotEmpty) {
      final intended = widget.response.data?.intendedProgramCode ?? formData?.incomingCourse;
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

    // Tab 2: Personal Info
    _firstNameCtrl = TextEditingController(text: formData?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: formData?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: formData?.lastName ?? '');
    _suffixCtrl = TextEditingController(text: formData?.suffix ?? '');
    _genderCtrl = TextEditingController(text: formData?.gender ?? '');
    _ageCtrl = TextEditingController(text: formData?.age != null ? formData!.age.toString() : '');
    _bloodType = formData?.bloodType;
    _dobCtrl = TextEditingController(text: formData?.dateOfBirth ?? '');
    _pobCtrl = TextEditingController(text: formData?.placeOfBirth ?? '');
    _sex = (formData != null && formData.sex.isNotEmpty) ? formData.sex : 'Male';
    _civilStatus = (formData != null && formData.civilStatus.isNotEmpty) ? formData.civilStatus : 'Single';
    _nationalityCtrl = TextEditingController(text: formData?.nationality.isNotEmpty == true ? formData!.nationality : 'Filipino');
    _religionCtrl = TextEditingController(text: formData?.religion ?? '');
    _mobileCtrl = TextEditingController(text: formData?.mobileNumber ?? '');
    _facebookNameCtrl = TextEditingController(text: formData?.facebookName ?? '');

    // Tab 3: Address
    _houseStreetCtrl = TextEditingController(text: formData?.houseStreet ?? '');
    _barangayCtrl = TextEditingController(text: formData?.barangay ?? '');
    _cityCtrl = TextEditingController(text: formData?.cityMunicipality ?? '');
    _provinceCtrl = TextEditingController(text: formData?.province ?? '');
    _zipCtrl = TextEditingController(text: formData?.zipCode ?? '');

    _provHouseStreetCtrl = TextEditingController(text: formData?.provHouseStreet ?? '');
    _provBarangayCtrl = TextEditingController(text: formData?.provBarangay ?? '');
    _provCityCtrl = TextEditingController(text: formData?.provCityMunicipality ?? '');
    _provProvinceCtrl = TextEditingController(text: formData?.provProvince ?? '');
    _provZipCtrl = TextEditingController(text: formData?.provZipCode ?? '');

    // Tab 4: Education
    _lastSchoolCtrl = TextEditingController(text: formData?.lastSchoolAttended ?? '');
    _schoolAddressCtrl = TextEditingController(text: formData?.schoolAddress ?? '');
    _programTrackStrandCtrl = TextEditingController(text: formData?.programTrackStrand ?? '');
    _yearGraduatedCtrl = TextEditingController(text: formData?.yearGraduated ?? '');
    _prevCollegeCtrl = TextEditingController(text: formData?.previousCollege ?? '');
    _prevCourseCtrl = TextEditingController(text: formData?.previousCourse ?? '');

    // Tab 5: Family & Medical
    final rawBirthOrder = formData?.birthOrder;
    if (rawBirthOrder != null && _birthOrderOptions.contains(rawBirthOrder)) {
      _birthOrder = rawBirthOrder;
    } else if (rawBirthOrder != null && rawBirthOrder.isNotEmpty) {
      final match = _birthOrderOptions.firstWhere(
        (o) => o.toLowerCase() == rawBirthOrder.toLowerCase(),
        orElse: () => '',
      );
      _birthOrder = match.isNotEmpty ? match : null;
    } else {
      _birthOrder = null;
    }

    _siblingsCtrl = TextEditingController(text: formData?.numberOfSiblings != null ? formData!.numberOfSiblings.toString() : '');

    final rawFamilyStatus = formData?.familyStatus;
    if (rawFamilyStatus != null && _familyStatusOptions.contains(rawFamilyStatus)) {
      _familyStatus = rawFamilyStatus;
    } else if (rawFamilyStatus != null && rawFamilyStatus.isNotEmpty) {
      final match = _familyStatusOptions.firstWhere(
        (o) => o.toLowerCase() == rawFamilyStatus.toLowerCase(),
        orElse: () => '',
      );
      _familyStatus = match.isNotEmpty ? match : null;
    } else {
      _familyStatus = null;
    }
    _presentMedicalSelected = formData?.presentMedicalConditions != null
        ? Set.from(formData!.presentMedicalConditions!)
        : {};
    _pastMedicalSelected = formData?.pastMedicalHistory != null
        ? Set.from(formData!.pastMedicalHistory!)
        : {};
    _immunizationSelected = formData?.immunizationHistory != null
        ? Set.from(formData!.immunizationHistory!)
        : {};
    _familyMedicalNotesCtrl = TextEditingController(text: formData?.familyMedicalConditionsNotes ?? '');
    _ongoingMedicationsCtrl = TextEditingController(text: formData?.ongoingMedications ?? '');
    _developmentalConditionsCtrl = TextEditingController(text: formData?.developmentalConditions ?? '');
    _otherMedicalDiagnosisCtrl = TextEditingController(text: formData?.otherMedicalDiagnosis ?? '');

    // Tab 6: Father / Mother / Guardian (match by relationType: 1=Father, 2=Mother, 3=Guardian)
    ContactModel? father;
    ContactModel? mother;
    ContactModel? guardian;

    for (final c in contactsData) {
      if (c.relationType == 1 && father == null) {
        father = c;
      } else if (c.relationType == 2 && mother == null) {
        mother = c;
      } else if (c.relationType == 3 && guardian == null) {
        guardian = c;
      }
    }

    _fatherFirstNameCtrl = TextEditingController(text: father?.firstName ?? '');
    _fatherLastNameCtrl = TextEditingController(text: father?.lastName ?? '');
    _fatherContactNoCtrl = TextEditingController(text: father?.contactNo ?? '');
    _fatherEmailCtrl = TextEditingController(text: father?.email ?? '');
    _fatherDobCtrl = TextEditingController(text: father?.dateOfBirth ?? '');
    _fatherOccupationCtrl = TextEditingController(text: father?.occupation ?? '');
    _fatherWorkplaceCtrl = TextEditingController(text: father?.workplace ?? '');
    _fatherFacebookCtrl = TextEditingController(text: father?.facebookAccount ?? '');

    _motherFirstNameCtrl = TextEditingController(text: mother?.firstName ?? '');
    _motherLastNameCtrl = TextEditingController(text: mother?.lastName ?? '');
    _motherContactNoCtrl = TextEditingController(text: mother?.contactNo ?? '');
    _motherEmailCtrl = TextEditingController(text: mother?.email ?? '');
    _motherDobCtrl = TextEditingController(text: mother?.dateOfBirth ?? '');
    _motherOccupationCtrl = TextEditingController(text: mother?.occupation ?? '');
    _motherWorkplaceCtrl = TextEditingController(text: mother?.workplace ?? '');
    _motherFacebookCtrl = TextEditingController(text: mother?.facebookAccount ?? '');

    _guardianFirstNameCtrl = TextEditingController(text: guardian?.firstName ?? '');
    _guardianLastNameCtrl = TextEditingController(text: guardian?.lastName ?? '');
    _guardianContactNoCtrl = TextEditingController(text: guardian?.contactNo ?? '');
    _guardianEmailCtrl = TextEditingController(text: guardian?.email ?? '');
    _guardianOccupationCtrl = TextEditingController(text: guardian?.occupation ?? '');
    _guardianRelationshipDescCtrl = TextEditingController(text: guardian?.guardianRelationshipDescription ?? '');
    _guardianLivingWith = guardian?.livingWithGuardian ?? false;
  }

  @override
  void dispose() {
    _lrnCtrl.dispose();
    _academicYearCtrl.dispose();
    _incomingCourseCtrl.dispose();
    _previousStudentIdCtrl.dispose();

    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _suffixCtrl.dispose();
    _genderCtrl.dispose();
    _ageCtrl.dispose();
    _dobCtrl.dispose();
    _pobCtrl.dispose();
    _nationalityCtrl.dispose();
    _religionCtrl.dispose();
    _mobileCtrl.dispose();
    _facebookNameCtrl.dispose();

    _houseStreetCtrl.dispose();
    _barangayCtrl.dispose();
    _cityCtrl.dispose();
    _provinceCtrl.dispose();
    _zipCtrl.dispose();

    _provHouseStreetCtrl.dispose();
    _provBarangayCtrl.dispose();
    _provCityCtrl.dispose();
    _provProvinceCtrl.dispose();
    _provZipCtrl.dispose();

    _lastSchoolCtrl.dispose();
    _schoolAddressCtrl.dispose();
    _programTrackStrandCtrl.dispose();
    _yearGraduatedCtrl.dispose();
    _prevCollegeCtrl.dispose();
    _prevCourseCtrl.dispose();

    _siblingsCtrl.dispose();
    _familyMedicalNotesCtrl.dispose();
    _ongoingMedicationsCtrl.dispose();
    _developmentalConditionsCtrl.dispose();
    _otherMedicalDiagnosisCtrl.dispose();

    _fatherFirstNameCtrl.dispose();
    _fatherLastNameCtrl.dispose();
    _fatherContactNoCtrl.dispose();
    _fatherEmailCtrl.dispose();
    _fatherDobCtrl.dispose();
    _fatherOccupationCtrl.dispose();
    _fatherWorkplaceCtrl.dispose();
    _fatherFacebookCtrl.dispose();

    _motherFirstNameCtrl.dispose();
    _motherLastNameCtrl.dispose();
    _motherContactNoCtrl.dispose();
    _motherEmailCtrl.dispose();
    _motherDobCtrl.dispose();
    _motherOccupationCtrl.dispose();
    _motherWorkplaceCtrl.dispose();
    _motherFacebookCtrl.dispose();

    _guardianFirstNameCtrl.dispose();
    _guardianLastNameCtrl.dispose();
    _guardianContactNoCtrl.dispose();
    _guardianEmailCtrl.dispose();
    _guardianOccupationCtrl.dispose();
    _guardianRelationshipDescCtrl.dispose();

    super.dispose();
  }

  bool _hasAnyOtherFatherField() {
    return _fatherFirstNameCtrl.text.trim().isNotEmpty ||
        _fatherLastNameCtrl.text.trim().isNotEmpty ||
        _fatherContactNoCtrl.text.trim().isNotEmpty ||
        _fatherEmailCtrl.text.trim().isNotEmpty ||
        _fatherWorkplaceCtrl.text.trim().isNotEmpty ||
        _fatherDobCtrl.text.trim().isNotEmpty ||
        _fatherFacebookCtrl.text.trim().isNotEmpty;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please check the required fields before submitting.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_selectedProgramId == null || _selectedTermId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select Program and Term in Enrollment Details.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
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
      houseStreet: _houseStreetCtrl.text.trim().isNotEmpty ? _houseStreetCtrl.text.trim() : null,
      barangay: _barangayCtrl.text.trim(),
      cityMunicipality: _cityCtrl.text.trim(),
      province: _provinceCtrl.text.trim(),
      zipCode: _zipCtrl.text.trim(),
      lastSchoolAttended: _lastSchoolCtrl.text.trim(),
      schoolAddress: _schoolAddressCtrl.text.trim(),
      programTrackStrand: _programTrackStrandCtrl.text.trim().isNotEmpty ? _programTrackStrandCtrl.text.trim() : null,
      yearGraduated: _yearGraduatedCtrl.text.trim(),
      previousCollege: _prevCollegeCtrl.text.trim(),
      previousCourse: _prevCourseCtrl.text.trim(),
      yearLevel: _yearLevel,
      previousStudentID: _previousStudentIdCtrl.text.trim().isNotEmpty ? _previousStudentIdCtrl.text.trim() : null,
      gender: _genderCtrl.text.trim().isNotEmpty ? _genderCtrl.text.trim() : null,
      age: int.tryParse(_ageCtrl.text.trim()),
      bloodType: _bloodType,
      religion: _religionCtrl.text.trim().isNotEmpty ? _religionCtrl.text.trim() : null,
      facebookName: _facebookNameCtrl.text.trim().isNotEmpty ? _facebookNameCtrl.text.trim() : null,
      provHouseStreet: _provHouseStreetCtrl.text.trim().isNotEmpty ? _provHouseStreetCtrl.text.trim() : null,
      provBarangay: _provBarangayCtrl.text.trim().isNotEmpty ? _provBarangayCtrl.text.trim() : null,
      provCityMunicipality: _provCityCtrl.text.trim().isNotEmpty ? _provCityCtrl.text.trim() : null,
      provProvince: _provProvinceCtrl.text.trim().isNotEmpty ? _provProvinceCtrl.text.trim() : null,
      provZipCode: _provZipCtrl.text.trim().isNotEmpty ? _provZipCtrl.text.trim() : null,
      studentType: _studentType,
      lrn: _lrnCtrl.text.trim().isNotEmpty ? _lrnCtrl.text.trim() : null,
      academicYear: _academicYearCtrl.text.trim().isNotEmpty ? _academicYearCtrl.text.trim() : null,
      incomingCourse: _incomingCourseCtrl.text.trim().isNotEmpty ? _incomingCourseCtrl.text.trim() : null,
      birthOrder: _birthOrder,
      numberOfSiblings: int.tryParse(_siblingsCtrl.text.trim()),
      familyStatus: _familyStatus,
      presentMedicalConditions: _presentMedicalSelected.isNotEmpty ? _presentMedicalSelected.toList() : null,
      pastMedicalHistory: _pastMedicalSelected.isNotEmpty ? _pastMedicalSelected.toList() : null,
      immunizationHistory: _immunizationSelected.isNotEmpty ? _immunizationSelected.toList() : null,
      familyMedicalConditionsNotes: _familyMedicalNotesCtrl.text.trim().isNotEmpty ? _familyMedicalNotesCtrl.text.trim() : null,
      ongoingMedications: _ongoingMedicationsCtrl.text.trim().isNotEmpty ? _ongoingMedicationsCtrl.text.trim() : null,
      developmentalConditions: _developmentalConditionsCtrl.text.trim().isNotEmpty ? _developmentalConditionsCtrl.text.trim() : null,
      otherMedicalDiagnosis: _otherMedicalDiagnosisCtrl.text.trim().isNotEmpty ? _otherMedicalDiagnosisCtrl.text.trim() : null,
    );

    // Build contacts list: only include entries that have fields provided.
    final contacts = <ContactModel>[];

    final hasFather = _hasAnyOtherFatherField() || _fatherOccupationCtrl.text.trim().isNotEmpty;
    if (hasFather) {
      contacts.add(ContactModel(
        firstName: _fatherFirstNameCtrl.text.trim(),
        lastName: _fatherLastNameCtrl.text.trim(),
        relationType: 1, // Father
        occupation: _fatherOccupationCtrl.text.trim(),
        contactNo: _fatherContactNoCtrl.text.trim(),
        email: _fatherEmailCtrl.text.trim().isNotEmpty ? _fatherEmailCtrl.text.trim() : null,
        dateOfBirth: _fatherDobCtrl.text.trim().isNotEmpty ? _fatherDobCtrl.text.trim() : null,
        workplace: _fatherWorkplaceCtrl.text.trim().isNotEmpty ? _fatherWorkplaceCtrl.text.trim() : null,
        facebookAccount: _fatherFacebookCtrl.text.trim().isNotEmpty ? _fatherFacebookCtrl.text.trim() : null,
      ));
    }

    if (_motherFirstNameCtrl.text.trim().isNotEmpty) {
      contacts.add(ContactModel(
        firstName: _motherFirstNameCtrl.text.trim(),
        lastName: _motherLastNameCtrl.text.trim(),
        relationType: 2, // Mother
        occupation: _motherOccupationCtrl.text.trim(),
        contactNo: _motherContactNoCtrl.text.trim(),
        email: _motherEmailCtrl.text.trim().isNotEmpty ? _motherEmailCtrl.text.trim() : null,
        dateOfBirth: _motherDobCtrl.text.trim().isNotEmpty ? _motherDobCtrl.text.trim() : null,
        workplace: _motherWorkplaceCtrl.text.trim().isNotEmpty ? _motherWorkplaceCtrl.text.trim() : null,
        facebookAccount: _motherFacebookCtrl.text.trim().isNotEmpty ? _motherFacebookCtrl.text.trim() : null,
      ));
    }

    if (_guardianFirstNameCtrl.text.trim().isNotEmpty) {
      contacts.add(ContactModel(
        firstName: _guardianFirstNameCtrl.text.trim(),
        lastName: _guardianLastNameCtrl.text.trim(),
        relationType: 3, // Guardian
        occupation: _guardianOccupationCtrl.text.trim(),
        contactNo: _guardianContactNoCtrl.text.trim(),
        email: _guardianEmailCtrl.text.trim().isNotEmpty ? _guardianEmailCtrl.text.trim() : null,
        guardianRelationshipDescription: _guardianRelationshipDescCtrl.text.trim().isNotEmpty ? _guardianRelationshipDescCtrl.text.trim() : null,
        livingWithGuardian: _guardianLivingWith,
      ));
    }

    widget.onSubmit(_selectedProgramId!, _selectedTermId!, form, contacts);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      child: Container(
        width: 940,
        height: 760,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
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
            // Sub-Tab Bar
            _buildSubTabBar(),
            // Form Body (IndexedStack preserves controllers, scroll state, and validation)
            Expanded(
              child: Form(
                key: _formKey,
                child: IndexedStack(
                  index: _activeTab,
                  children: [
                    _buildTabEnrollment(),
                    _buildTabPersonal(),
                    _buildTabAddress(),
                    _buildTabEducation(),
                    _buildTabFamilyMedical(),
                    _buildTabContacts(),
                  ],
                ),
              ),
            ),
            // Bottom Action Bar
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTabBar() {
    final tabs = [
      {'title': 'Enrollment Details', 'index': 0, 'icon': Icons.school_outlined},
      {'title': 'Personal Info', 'index': 1, 'icon': Icons.person_outline},
      {'title': 'Address', 'index': 2, 'icon': Icons.home_outlined},
      {'title': 'Education', 'index': 3, 'icon': Icons.history_edu_outlined},
      {'title': 'Family & Medical', 'index': 4, 'icon': Icons.health_and_safety_outlined},
      {'title': 'Father / Mother / Guardian', 'index': 5, 'icon': Icons.family_restroom_outlined},
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.map((t) {
            final idx = t['index'] as int;
            final isSelected = _activeTab == idx;
            return InkWell(
              onTap: () => setState(() => _activeTab = idx),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      t['icon'] as IconData,
                      size: 16,
                      color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      t['title'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Tab 1: Enrollment Details ──────────────────────────────────────────────
  Widget _buildTabEnrollment() {
    const validYearLevels = [1, 2, 3, 4, 5];
    final effectiveYearLevel = validYearLevels.contains(_yearLevel)
        ? _yearLevel
        : validYearLevels.first;

    final programIds = widget.programs.map((p) => p.programId).toSet();
    final effectiveProgramId = programIds.contains(_selectedProgramId)
        ? _selectedProgramId
        : (widget.programs.isNotEmpty ? widget.programs.first.programId : null);

    final termIds = widget.terms.map((t) => t.termId).toSet();
    final effectiveTermId = termIds.contains(_selectedTermId)
        ? _selectedTermId
        : (widget.terms.isNotEmpty ? widget.terms.first.termId : null);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: '1. Academic Placement',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
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
                      onChanged: (val) => setState(() => _selectedProgramId = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
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
                      onChanged: (val) => setState(() => _selectedTermId = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 130,
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
                          child: Text('Year $y'),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _yearLevel = val ?? 1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCard(
            title: '2. Enrollment Metadata',
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _studentType,
                      decoration: const InputDecoration(
                        labelText: 'Student Type',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('New')),
                        DropdownMenuItem(value: 2, child: Text('Old / Continuing')),
                        DropdownMenuItem(value: 3, child: Text('Transferee')),
                      ],
                      onChanged: (val) => setState(() => _studentType = val),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _lrnCtrl,
                      decoration: const InputDecoration(
                        labelText: 'LRN (Learner Reference No.)',
                        hintText: '12-digit LRN',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _academicYearCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Academic Year',
                        hintText: 'e.g. 2026-2027',
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
                      controller: _incomingCourseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Incoming Course (Applicant Stated)',
                        hintText: 'e.g. BSIT, BSME',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _previousStudentIdCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Previous Physical Student ID (Optional)',
                        hintText: 'e.g. 2021-12345 (for returning students)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 2: Personal Info ───────────────────────────────────────────────────
  Widget _buildTabPersonal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Full Name',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _firstNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'First Name *',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _firstNameCtrl),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'First name required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _middleNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Middle Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _middleNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _lastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Last Name *',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _lastNameCtrl),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Last name required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 100,
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
            ],
          ),
          _buildCard(
            title: 'Demographics & Vital Info',
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _sex,
                      decoration: const InputDecoration(
                        labelText: 'Sex *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Male', 'Female'].map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (v) => setState(() => _sex = v!),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _genderCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Gender Identity',
                        hintText: 'e.g. Male, Female, Non-binary',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 110,
                    child: TextFormField(
                      controller: _ageCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Age',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 130,
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _bloodType,
                      decoration: const InputDecoration(
                        labelText: 'Blood Type',
                        border: OutlineInputBorder(),
                      ),
                      items: _bloodTypeOptions.map((bt) {
                        return DropdownMenuItem(value: bt, child: Text(bt));
                      }).toList(),
                      onChanged: (v) => setState(() => _bloodType = v),
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
                        hintText: 'YYYY-MM-DD',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'DOB required' : null,
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
                      initialValue: _civilStatus,
                      decoration: const InputDecoration(
                        labelText: 'Civil Status *',
                        border: OutlineInputBorder(),
                      ),
                      items: ['Single', 'Married', 'Widowed'].map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                      onChanged: (v) => setState(() => _civilStatus = v!),
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
                      controller: _religionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Religion',
                        hintText: 'e.g. Roman Catholic',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCard(
            title: 'Contact Information',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mobileCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Number *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Mobile number required' : mobileError(v),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _facebookNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Facebook Name / Account',
                        hintText: 'e.g. juan.delacruz',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 3: Address ─────────────────────────────────────────────────────────
  Widget _buildTabAddress() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Primary Residential Address',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _houseStreetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'House No. / Street',
                        hintText: 'House/Unit No., Street name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _barangayCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Barangay *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Barangay required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'City / Municipality *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'City required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _provinceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Province *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Province required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      controller: _zipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ZIP Code *',
                        border: OutlineInputBorder(),
                        errorMaxLines: 2,
                      ),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'ZIP code required' : zipError(v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCard(
            title: 'Provincial / Secondary Address (Optional — if different from primary)',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _provHouseStreetCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Provincial House No. / Street',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _provBarangayCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Provincial Barangay',
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
                    flex: 2,
                    child: TextFormField(
                      controller: _provCityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Provincial City / Municipality',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _provProvinceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Provincial Province',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  SizedBox(
                    width: 130,
                    child: TextFormField(
                      controller: _provZipCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prov. ZIP',
                        border: OutlineInputBorder(),
                        errorMaxLines: 2,
                      ),
                      validator: zipError,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 4: Education ───────────────────────────────────────────────────────
  Widget _buildTabEducation() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Secondary / Senior High School',
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _lastSchoolCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Last School Attended *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v!.trim().isEmpty ? 'Last school required' : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 3,
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
                    flex: 3,
                    child: TextFormField(
                      controller: _programTrackStrandCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Program / Track / Strand (Free text)',
                        hintText: 'e.g. STEM, TVL-ICT, HUMSS, ABM',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _yearGraduatedCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Year Graduated *',
                        hintText: 'e.g. 2024 or 2024-05-30',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCard(
            title: 'Tertiary Education (for Transferees)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prevCollegeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Previous College / University',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _prevCourseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Previous Course / Major',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 5: Family & Medical ────────────────────────────────────────────────
  Widget _buildTabFamilyMedical() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCard(
            title: 'Family Background',
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _birthOrder,
                      decoration: const InputDecoration(
                        labelText: 'Birth Order',
                        border: OutlineInputBorder(),
                      ),
                      items: _birthOrderOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (v) => setState(() => _birthOrder = v),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _siblingsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Number of Siblings',
                        hintText: 'e.g. 2',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: _familyStatus,
                      decoration: const InputDecoration(
                        labelText: 'Family Status',
                        border: OutlineInputBorder(),
                      ),
                      items: _familyStatusOptions.map((s) {
                        return DropdownMenuItem(value: s, child: Text(s));
                      }).toList(),
                      onChanged: (v) => setState(() => _familyStatus = v),
                    ),
                  ),
                ],
              ),
            ],
          ),
          _buildCard(
            title: 'Medical / Health History (Multi-Select Checkboxes)',
            children: [
              _buildFilterChips(
                label: 'Present Medical Conditions',
                options: _presentConditionOptions,
                selectedSet: _presentMedicalSelected,
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              _buildFilterChips(
                label: 'Past Medical History',
                options: _pastHistoryOptions,
                selectedSet: _pastMedicalSelected,
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),
              _buildFilterChips(
                label: 'Immunization History',
                options: _immunizationOptions,
                selectedSet: _immunizationSelected,
              ),
            ],
          ),
          _buildCard(
            title: 'Health & Medical Notes (Free Text)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _familyMedicalNotesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Family Medical History Notes',
                        hintText: 'e.g. Hypertension, Diabetes on paternal side',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _ongoingMedicationsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Ongoing Medications',
                        hintText: 'e.g. Inhaler, maintenance meds',
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
                      controller: _developmentalConditionsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Developmental Conditions',
                        hintText: 'e.g. ADHD, Autism spectrum',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _otherMedicalDiagnosisCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Other Medical Diagnosis',
                        hintText: 'Any other relevant health notes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tab 6: Father / Mother / Guardian Contacts ─────────────────────────────
  Widget _buildTabContacts() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Father Sub-Section
          _buildCard(
            title: 'Father Details (RelationType = 1)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fatherFirstNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _fatherFirstNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherLastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _fatherLastNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherContactNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                        errorMaxLines: 2,
                      ),
                      validator: phoneError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
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
                      controller: _fatherOccupationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        hintText: 'Required if father details provided',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        if (_hasAnyOtherFatherField() &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Occupation is required if father details are provided';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherWorkplaceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Workplace',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherDobCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatherFacebookCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Facebook Account',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Mother Sub-Section
          _buildCard(
            title: 'Mother Details (RelationType = 2)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _motherFirstNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _motherFirstNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherLastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _motherLastNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherContactNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                        errorMaxLines: 2,
                      ),
                      validator: phoneError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
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
                      controller: _motherOccupationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherWorkplaceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Workplace',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherDobCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _motherFacebookCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Facebook Account',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Guardian Sub-Section
          _buildCard(
            title: 'Guardian Details (RelationType = 3)',
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _guardianFirstNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'First Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _guardianFirstNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianLastNameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Last Name',
                        border: const OutlineInputBorder(),
                        suffixIcon: EnyeButton(controller: _guardianLastNameCtrl),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianContactNoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Contact Number',
                        border: OutlineInputBorder(),
                        errorMaxLines: 2,
                      ),
                      validator: phoneError,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianEmailCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Email',
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
                      controller: _guardianOccupationCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Occupation',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _guardianRelationshipDescCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Relationship Description',
                        hintText: 'e.g. Grandmother, Aunt, Sister, Other',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Living with Guardian?',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _guardianLivingWith,
                          activeThumbColor: AppColors.primary,
                          onChanged: (val) => setState(() => _guardianLivingWith = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Bottom Action Bar ──────────────────────────────────────────────────────
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 12),
          if (_activeTab > 0)
            TextButton.icon(
              onPressed: () => setState(() => _activeTab--),
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Previous'),
            ),
          const Spacer(),
          if (_activeTab < 5)
            ElevatedButton.icon(
              onPressed: () => setState(() => _activeTab++),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE2E8F0),
                foregroundColor: const Color(0xFF1E293B),
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Next'),
            ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Create Application'),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildFilterChips({
    required String label,
    required List<String> options,
    required Set<String> selectedSet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((opt) {
            final checked = selectedSet.contains(opt);
            return FilterChip(
              label: Text(
                opt,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  color: checked ? AppColors.primary : const Color(0xFF334155),
                ),
              ),
              selected: checked,
              selectedColor: const Color(0xFFDBEAFE),
              backgroundColor: Colors.white,
              checkmarkColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: BorderSide(
                  color: checked ? AppColors.primary : const Color(0xFFCBD5E1),
                ),
              ),
              onSelected: (val) {
                setState(() {
                  if (val) {
                    selectedSet.add(opt);
                  } else {
                    selectedSet.remove(opt);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
