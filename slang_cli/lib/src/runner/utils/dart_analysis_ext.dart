final _spacesRegex = RegExp(r'\s');
final _singleLineCommentsRegex = RegExp(r'//.*');
final _multiLineCommentsRegex = RegExp(r'/\*.*?\*/', dotAll: true);

extension DartAnalysisExt on String {
  String sanitizeDartFileForAnalysis({required bool removeSpaces}) {
    String temp = replaceAll(_singleLineCommentsRegex, '')
        .replaceAll(_multiLineCommentsRegex, '');

    if (removeSpaces) {
      temp = temp.replaceAll(_spacesRegex, '');
    }

    return temp;
  }
}
