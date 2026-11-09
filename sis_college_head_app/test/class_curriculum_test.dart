import 'package:flutter_test/flutter_test.dart';
import 'package:sis_college_head_app/models/class_models.dart';

void main() {
  Map<String, dynamic> json({bool show = false}) => {
        'classID': 'c1',
        'subjectID': 's1',
        'subjectCode': 'MT 101A',
        'subjectTitle': 'Machining',
        'termID': 't1',
        'className': 'BTVTED-MT 1A',
        'curriculumName': 'CHED 2026',
        'showCurriculum': show,
      };

  test('the curriculum is shown only when the program has several curricula', () {
    expect(ClassModel.fromJson(json(show: true)).titleWithCurriculum(), 'Machining · CHED 2026');
    expect(ClassModel.fromJson(json()).titleWithCurriculum(), 'Machining');
  });

  test('older API answers without curriculum fields still read', () {
    final c = ClassModel.fromJson({'classID': 'c1', 'subjectID': 's1', 'termID': 't1', 'className': 'BSIT 1A'});
    expect(c.showCurriculum, isFalse);
    expect(c.titleWithCurriculum('Untitled Subject'), 'Untitled Subject');
  });
}
