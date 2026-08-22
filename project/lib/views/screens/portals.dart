import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/portal_bloc.dart';
import '../../enums/enums.dart';
import '../../models/models.dart';
import '../widgets/shared_widgets.dart';

class TeacherPortal extends StatefulWidget {
  final ValueChanged<UserRole> onRoleChanged;
  const TeacherPortal({required this.onRoleChanged, super.key});
  @override State<TeacherPortal> createState() => _TeacherPortalState();
}

class _TeacherPortalState extends State<TeacherPortal> {
  int tab = 0;
  void _onNav(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) => BlocBuilder<TeacherBloc, PortalState>(
    builder: (context, state) {
      final content = state.loading
          ? const Center(child: CircularProgressIndicator())
          : tab == 0
              ? TeacherHome(state: state)
              : const CorrectionPanel();
      return LayoutBuilder(
        builder: (context, c) => Scaffold(
          body: Row(
            children: [
              if (c.maxWidth >= 900)
                SideNav(
                  label: 'Teaching',
                  items: const ['My subjects', 'Correction requests', 'Department subjects', 'Department faculty'],
                  selected: tab,
                  onTap: _onNav,
                ),
              Expanded(
                child: Column(
                  children: [
                    PortalHeader(
                      eyebrow: 'DBTC-Cebu / Teaching',
                      title: tab == 0 ? 'My subjects' : 'Correction requests',
                      subtitle: 'Your active study load and class rosters for this term',
                      role: UserRole.teacher,
                      onRoleChanged: widget.onRoleChanged,
                    ),
                    Expanded(child: content),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class TeacherHome extends StatelessWidget {
  final PortalState state;
  const TeacherHome({required this.state, super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          const MetricCard(label: 'Assigned classes', value: '4', icon: Icons.class_, color: blue),
          const MetricCard(label: 'Students to grade', value: '128', icon: Icons.groups_2, color: mint),
          const MetricCard(label: 'Pending submissions', value: '3', icon: Icons.pending_actions, color: Color(0xFFF2A93B)),
        ]),
        const SizedBox(height: 28),
        const Text('Assigned classes', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ink)),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, c) => GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: c.maxWidth > 1100 ? 3 : c.maxWidth > 650 ? 2 : 1,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.35,
            ),
            itemCount: state.classes.length,
            itemBuilder: (context, index) {
              final item = state.classes[index];
              return InkWell(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => BlocProvider.value(
                    value: context.read<TeacherBloc>(),
                    child: GradeDialog(classSection: item, state: state),
                  ),
                ),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE8ECF4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(item.sectionName, style: const TextStyle(color: blue, fontWeight: FontWeight.w800)),
                          const Icon(Icons.arrow_outward, color: muted, size: 18),
                        ],
                      ),
                      const Spacer(),
                      Text(item.customTitle, style: const TextStyle(color: ink, fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 5),
                      Text('42 students  •  ${item.midtermWeight * 100}% / ${item.finalWeight * 100}%', style: const TextStyle(color: muted, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class GradeDialog extends StatefulWidget {
  final ClassSection classSection;
  final PortalState state;
  const GradeDialog({required this.classSection, required this.state, super.key});
  @override State<GradeDialog> createState() => _GradeDialogState();
}

class _GradeDialogState extends State<GradeDialog> {
  late Grade grade;
  late TextEditingController mid, fin;
  GradeRemark remark = GradeRemark.passed;
  @override
  void initState() {
    super.initState();
    grade = widget.state.grades.first;
    mid = TextEditingController(text: '${grade.midtermGrade}');
    fin = TextEditingController(text: '${grade.finalGrade}');
    remark = grade.remark;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Grade encoding · ${widget.classSection.sectionName}'),
    content: SizedBox(
      width: 720,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            Expanded(child: Text('Student', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 90, child: Text('Midterm', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 90, child: Text('Final', style: TextStyle(fontWeight: FontWeight.w700))),
            SizedBox(width: 130, child: Text('Remark', style: TextStyle(fontWeight: FontWeight.w700))),
          ]),
          const Divider(),
          ...['Test Student', 'Mika Santos', 'Janelle Lim', 'Paolo Garcia'].map((name) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Expanded(child: Text(name)),
              SizedBox(width: 80, child: TextField(controller: name == 'Test Student' ? mid : null, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              SizedBox(width: 80, child: TextField(controller: name == 'Test Student' ? fin : null, keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              SizedBox(width: 120, child: DropdownButton<GradeRemark>(
                isExpanded: true,
                value: remark,
                items: GradeRemark.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label))).toList(),
                onChanged: name == 'Test Student' ? (v) { if (v != null) setState(() => remark = v); } : null,
              )),
            ]),
          )),
        ],
      ),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      FilledButton(
        onPressed: () {
          context.read<TeacherBloc>().add(UpdateGrade(grade.gradeId, double.tryParse(mid.text) ?? 0, double.tryParse(fin.text) ?? 0, remark));
          Navigator.pop(context);
        },
        child: const Text('Save grades'),
      ),
    ],
  );
}

class CorrectionPanel extends StatelessWidget {
  const CorrectionPanel({super.key});
  @override
  Widget build(BuildContext context) => Center(child: Container(padding: const EdgeInsets.all(28), child: const Text('Correction requests will appear here.', style: TextStyle(color: muted, fontSize: 16))));
}

class RegistrarPortal extends StatefulWidget {
  final ValueChanged<UserRole> onRoleChanged;
  const RegistrarPortal({required this.onRoleChanged, super.key});
  @override State<RegistrarPortal> createState() => _RegistrarPortalState();
}

class _RegistrarPortalState extends State<RegistrarPortal> {
  int tab = 0;
  void _onNav(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) => BlocBuilder<RegistrarBloc, PortalState>(
    builder: (context, state) => LayoutBuilder(
      builder: (context, c) => Scaffold(
        body: Row(
          children: [
            if (c.maxWidth >= 900)
              SideNav(
                label: 'Registrar',
                items: const ['Overview', 'Applications', 'Student directory', 'Programs'],
                selected: tab,
                onTap: _onNav,
              ),
            Expanded(
              child: Column(
                children: [
                  PortalHeader(
                    eyebrow: 'DBTC-Cebu / Registrar',
                    title: tab == 0 ? 'Registrar overview' : 'Student directory',
                    subtitle: 'Enrollment operations for the current academic term',
                    role: UserRole.registrar,
                    onRoleChanged: widget.onRoleChanged,
                  ),
                  Expanded(child: state.loading ? const Center(child: CircularProgressIndicator()) : RegistrarHome(state: state)),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class RegistrarHome extends StatelessWidget {
  final PortalState state;
  const RegistrarHome({required this.state, super.key});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(spacing: 16, runSpacing: 16, children: [
          MetricCard(label: 'Total students', value: '${state.students.length}', icon: Icons.people_alt, color: blue),
          MetricCard(label: 'Pending applications', value: '${state.applications.where((a) => a.status == ApplicationStatus.pending).length}', icon: Icons.assignment_late, color: const Color(0xFFF2A93B)),
          MetricCard(label: 'Active programs', value: '${state.programs.length}', icon: Icons.account_tree, color: mint),
        ]),
        const SizedBox(height: 28),
        const SectionTitle(title: 'Enrollment applications', action: 'View all'),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: state.applications.map((app) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              leading: CircleAvatar(backgroundColor: blue.withOpacity(.12), child: Text(app.applicantName.substring(0, 1), style: const TextStyle(color: blue))),
              title: Text(app.applicantName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(app.applicantEmail),
              trailing: Wrap(spacing: 8, children: [
                StatusPill(app.status.label, color: app.status == ApplicationStatus.pending ? const Color(0xFFF2A93B) : mint),
                if (app.status == ApplicationStatus.pending)
                  IconButton(
                    onPressed: () => context.read<RegistrarBloc>().add(ChangeApplicationStatus(app.applicationId, ApplicationStatus.approved)),
                    icon: const Icon(Icons.check_circle, color: mint),
                  ),
                if (app.status == ApplicationStatus.pending)
                  IconButton(
                    onPressed: () => context.read<RegistrarBloc>().add(ChangeApplicationStatus(app.applicationId, ApplicationStatus.rejected)),
                    icon: const Icon(Icons.cancel, color: Colors.red),
                  ),
              ]),
            )).toList(),
          ),
        ),
        const SizedBox(height: 28),
        const SectionTitle(title: 'Student directory', action: 'Export list'),
        const SizedBox(height: 12),
        Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Student number')),
                DataColumn(label: Text('Name')),
                DataColumn(label: Text('LRN')),
                DataColumn(label: Text('Status')),
              ],
              rows: state.students.map((s) => DataRow(cells: [
                DataCell(Text(s.studentNumber)),
                DataCell(Text(s.fullName)),
                DataCell(Text(s.lrn)),
                DataCell(StatusPill(s.studentStatus.label, color: s.studentStatus == StudentStatus.enrolled ? mint : muted)),
              ])).toList(),
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title, action;
  const SectionTitle({required this.title, required this.action, super.key});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(title, style: const TextStyle(color: ink, fontSize: 20, fontWeight: FontWeight.w800)),
      TextButton(onPressed: () {}, child: Text(action)),
    ],
  );
}
