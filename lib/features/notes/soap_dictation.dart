/// SOAP section a dictation transcript can append into.
enum SoapSection {
  subjective,
  objective,
  assessment,
  plan,
}

extension SoapSectionLabel on SoapSection {
  String get label => switch (this) {
        SoapSection.subjective => 'Subjective',
        SoapSection.objective => 'Objective',
        SoapSection.assessment => 'Assessment',
        SoapSection.plan => 'Plan',
      };
}

/// Appends [transcript] to [existing], separated by a newline when both have text.
String appendSoapTranscript(String existing, String transcript) {
  final t = transcript.trim();
  if (t.isEmpty) return existing;
  final e = existing.trimRight();
  if (e.isEmpty) return t;
  return '$e\n$t';
}
