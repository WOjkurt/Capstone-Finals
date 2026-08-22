import 'package:flutter_bloc/flutter_bloc.dart';
import '../enums/enums.dart';
import '../models/models.dart';
import '../repositories/mock_repository.dart';

abstract class PortalEvent {}
class LoadPortal extends PortalEvent {}
class ChangeApplicationStatus extends PortalEvent { final int applicationId; final ApplicationStatus status; ChangeApplicationStatus(this.applicationId,this.status); }
class UpdateGrade extends PortalEvent { final int gradeId; final double midterm, finalGrade; final GradeRemark remark; UpdateGrade(this.gradeId,this.midterm,this.finalGrade,this.remark); }

class PortalState { final bool loading; final UserRole role; final List<Program> programs; final List<Student> students; final List<EnrollmentApplication> applications; final List<ClassSection> classes; final List<Grade> grades; final String? message; const PortalState({this.loading=true,required this.role,this.programs=const [],this.students=const [],this.applications=const [],this.classes=const [],this.grades=const [],this.message}); PortalState copyWith({bool? loading,List<Program>? programs,List<Student>? students,List<EnrollmentApplication>? applications,List<ClassSection>? classes,List<Grade>? grades,String? message})=>PortalState(loading:loading??this.loading,role:role,programs:programs??this.programs,students:students??this.students,applications:applications??this.applications,classes:classes??this.classes,grades:grades??this.grades,message:message); }

class PortalBloc extends Bloc<PortalEvent,PortalState> { final MockRepository repository; PortalBloc(this.repository,UserRole role):super(PortalState(role:role)){ on<LoadPortal>(_load); on<ChangeApplicationStatus>(_changeStatus); on<UpdateGrade>(_updateGrade); add(LoadPortal()); }
  Future<void> _load(LoadPortal event,Emitter<PortalState> emit) async { emit(state.copyWith(loading:true)); final result=await Future.wait([repository.getPrograms(),repository.getStudents(),repository.getApplications(),repository.getClasses(),repository.getGrades()]); emit(state.copyWith(loading:false,programs:result[0] as List<Program>,students:result[1] as List<Student>,applications:result[2] as List<EnrollmentApplication>,classes:result[3] as List<ClassSection>,grades:result[4] as List<Grade>)); }
  Future<void> _changeStatus(ChangeApplicationStatus event,Emitter<PortalState> emit) async { await repository.updateApplication(event.applicationId,event.status); add(LoadPortal()); emit(state.copyWith(message:'Application ${event.status.label.toLowerCase()} successfully.')); }
  Future<void> _updateGrade(UpdateGrade event,Emitter<PortalState> emit) async { await repository.saveGrade(event.gradeId,event.midterm,event.finalGrade,event.remark); add(LoadPortal()); emit(state.copyWith(message:'Grade saved successfully.')); }
}
class TeacherBloc extends PortalBloc { TeacherBloc(MockRepository repository):super(repository,UserRole.teacher); }
class StudentBloc extends PortalBloc { StudentBloc(MockRepository repository):super(repository,UserRole.student); }
class RegistrarBloc extends PortalBloc { RegistrarBloc(MockRepository repository):super(repository,UserRole.registrar); }
