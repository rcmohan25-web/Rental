import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_helpers.dart';

/// One row of `terms_documents`: `title`, text `version`, `content`, `status`
/// (draft, published, archived). The three audiences (general, borrower,
/// renter) and "exactly one active version per audience" are planned
/// columns, so [audience] is optional until that migration exists.
class TermsDocument extends Equatable {
  const TermsDocument({
    required this.id,
    required this.title,
    required this.version,
    required this.body,
    required this.status,
    required this.createdAt,
    this.audience,
    this.publishedAt,
  });

  factory TermsDocument.fromJson(Map<String, dynamic> json) => TermsDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        version: json['version'] as String,
        body: json['content'] as String,
        status: TermsStatus.fromWire(json['status'] as String),
        audience: json['audience'] == null
            ? null
            : TermsAudience.fromWire(json['audience'] as String),
        createdAt: parseTimestamp(json['created_at']),
        publishedAt: parseTimestampOrNull(json['published_at']),
      );

  final String id;
  final String title;

  /// Text, for example 'v1'. Unique together with [title].
  final String version;

  /// Column `content`.
  final String body;
  final TermsStatus status;
  final TermsAudience? audience;
  final DateTime createdAt;
  final DateTime? publishedAt;

  /// Published documents are the ones users accept.
  bool get isActive => status == TermsStatus.published;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'version': version,
        'content': body,
        'status': status.wire,
        'audience': audience?.wire,
        'created_at': formatTimestamp(createdAt),
        'published_at':
            publishedAt == null ? null : formatTimestamp(publishedAt!),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        version,
        body,
        status,
        audience,
        createdAt,
        publishedAt,
      ];
}
