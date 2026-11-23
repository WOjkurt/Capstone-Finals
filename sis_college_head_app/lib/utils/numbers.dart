/// One place for the numbers this system shows, because four screens disagreeing about
/// whether a grade is "1.2" or "1.20" is what testers noticed first.
///
/// The rules are not interchangeable, so the two are kept apart deliberately.
library;

/// A grade, the way the registrar writes it: `1.20 → "1.2"`, `1.75 → "1.75"`, `2 → "2.0"`.
///
/// Trailing zeros go, but **never at the cost of precision**. DBTC grades run 1.0 to 5.0 in
/// steps of 0.1 *plus* the quarter steps, so 1.25 and 1.75 are real grades a student earned
/// (see GradeScale on the API side). Rounding everything to one decimal place would print
/// 1.25 as "1.3" on a transcript -- a different grade. So: at least one decimal, at most two,
/// and the second only when it says something.
String gradeText(double v) {
  final two = v.toStringAsFixed(2);
  return two.endsWith('0') ? v.toStringAsFixed(1) : two;
}

/// Same shape as a grade. A GWA of 1.8234 prints as "1.82"; one of exactly 2 prints as "2.0".
String averageText(double v) => gradeText(v);

/// Credit units: `3.0 → "3"`, `1.5 → "1.5"`.
///
/// Whole where whole -- a 3-unit subject is "3 units", not "3.0 units". Halves survive,
/// because a 1.5-unit subject exists and printing it as "2" would overstate a student's load.
String unitsText(double v) => v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 1);

/// Hours, which behave like units.
String hoursText(double v) => unitsText(v);

/// A grade that may not have been given yet.
String gradeOrDash(double? v, {String dash = '-'}) => v == null ? dash : gradeText(v);
