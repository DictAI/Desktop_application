enum DocumentKind {
  transcriptTxt('transcript.txt', 'text/plain'),
  transcriptPdf('transcript.pdf', 'application/pdf'),
  summaryTxt('summary.txt', 'text/plain'),
  summaryPdf('summary.pdf', 'application/pdf');

  const DocumentKind(this.fileName, this.contentType);
  final String fileName;
  final String contentType;
}
