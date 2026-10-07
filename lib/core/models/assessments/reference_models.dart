import '../json_helpers.dart';

/// Curriculum and library catalogue models, WHITELISTED (paths relative to eldermin-backend/src/modules/academics/):
/// schemas/curriculum.schema.ts (CUR), schemas/book.schema.ts (BK), academics.controller.ts / academics.service.ts.
/// Curriculum: never parsed tenantId, institutionId, createdBy, approvedBy/At, subjectId, academicYearId.
/// Book: never parsed tenantId, institutionId, campusId, accessionNo/barcodes (copies[]), purchasePrice, purchaseDate, issued/damaged/lost/
/// reserved counters, totalIssues, rating, isbn/issn beyond display. Borrower and fine data is never requested at all.

class Slo {
  final String code;
  final String description;
  final String strand;
  final String bloomsLevel;
  final bool isAssessed;
  final String assessmentType;
  const Slo({this.code = '', this.description = '', this.strand = '', this.bloomsLevel = '', this.isAssessed = false, this.assessmentType = ''});

  factory Slo.fromJson(Map<String, dynamic> j) => Slo(
        code: readText(j['sloCode']),
        description: readText(j['description']),
        strand: readText(j['strand']),
        bloomsLevel: readText(j['bloomsLevel']),
        isAssessed: readBool(j['isAssessed']),
        assessmentType: readText(j['assessmentType']),
      );
}

class StandardMapping {
  final String standard;
  final String code;
  final String description;
  const StandardMapping({this.standard = '', this.code = '', this.description = ''});

  factory StandardMapping.fromJson(Map<String, dynamic> j) =>
      StandardMapping(standard: readText(j['standard']), code: readText(j['code']), description: readText(j['description']));
}

class Curriculum {
  final String id;
  final String name;
  final String framework;
  final String gradeLevel;
  final String subjectName;
  final String academicYearLabel;
  final String status;
  final List<Slo> slos;
  final List<StandardMapping> standards;

  const Curriculum({
    required this.id,
    this.name = '',
    this.framework = '',
    this.gradeLevel = '',
    this.subjectName = '',
    this.academicYearLabel = '',
    this.status = '',
    this.slos = const [],
    this.standards = const [],
  });

  factory Curriculum.fromJson(Map<String, dynamic> j) => Curriculum(
        id: readId(j['_id'] ?? j['id']) ?? '',
        name: readText(j['name']),
        framework: readText(j['framework']),
        gradeLevel: readText(j['gradeLevel']),
        subjectName: readText(j['subjectName']),
        academicYearLabel: readText(j['academicYearLabel']),
        status: readText(j['status']),
        slos: asJsonMapList(j['slos']).map(Slo.fromJson).toList(),
        standards: asJsonMapList(j['standardsMapping']).map(StandardMapping.fromJson).toList(),
      );

  /// Teachers only ever see PUBLISHED curricula. The schema's status enum is `draft | active | archived` (default `draft`):
  /// eldermin-backend/src/modules/academics/schemas/curriculum.schema.ts:38; `active` is the published state (the dashboard counts
  /// `status: 'active'`, academics.service.ts:60). Everything else (draft, archived, a missing or unknown status) is hidden.
  bool get isVisibleToTeachers => status.trim().toLowerCase() == 'active';

  /// SLOs grouped by strand, in first-seen order ('General' for none).
  Map<String, List<Slo>> get byStrand {
    final out = <String, List<Slo>>{};
    for (final s in slos) {
      out.putIfAbsent(s.strand.isEmpty ? 'General' : s.strand, () => []).add(s);
    }
    return out;
  }
}

const bookCategoryLabels = {
  'fiction': 'Fiction',
  'non_fiction': 'Non-fiction',
  'textbook': 'Textbook',
  'reference': 'Reference',
  'periodical': 'Periodical',
  'islamic': 'Islamic',
  'science': 'Science',
  'biography': 'Biography',
  'children': 'Children',
  'other': 'Other',
};

String bookCategoryLabel(String c) => bookCategoryLabels[c] ?? (c.isEmpty ? 'Other' : c.replaceAll('_', ' '));

class Book {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String publisher;
  final int? publishYear;
  final String edition;
  final String callNumber;
  final String category;
  final List<String> subjects;
  final List<String> gradeLevels;
  final String language;
  final String location;
  final String shelfNo;
  final int totalCopies;
  final int availableCopies;
  final String status;
  final String coverImageUrl;
  final String description;

  const Book({
    required this.id,
    this.title = '',
    this.author = '',
    this.isbn = '',
    this.publisher = '',
    this.publishYear,
    this.edition = '',
    this.callNumber = '',
    this.category = '',
    this.subjects = const [],
    this.gradeLevels = const [],
    this.language = '',
    this.location = '',
    this.shelfNo = '',
    this.totalCopies = 0,
    this.availableCopies = 0,
    this.status = '',
    this.coverImageUrl = '',
    this.description = '',
  });

  factory Book.fromJson(Map<String, dynamic> j) => Book(
        id: readId(j['_id'] ?? j['id']) ?? '',
        title: readText(j['title']),
        author: readText(j['author']),
        isbn: readText(j['isbn']),
        publisher: readText(j['publisher']),
        publishYear: readInt(j['publishYear']),
        edition: readText(j['edition']),
        callNumber: readText(j['callNumber']),
        category: readText(j['category']),
        subjects: readStringList(j['subjects']),
        gradeLevels: readStringList(j['gradeLevels']),
        language: readText(j['language']),
        location: readText(j['location']),
        shelfNo: readText(j['shelfNo']),
        totalCopies: readInt(j['totalCopies']) ?? 0,
        availableCopies: readInt(j['availableCopies']) ?? 0,
        status: readText(j['status']),
        coverImageUrl: readText(j['coverImageUrl']),
        description: readText(j['description']),
      );

  bool get isAvailable => availableCopies > 0 && status != 'deaccessioned';
}
