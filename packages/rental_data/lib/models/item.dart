import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'json_helpers.dart';

/// The fixed category list. `category` is a plan-required column that is not
/// in the committed schema yet (docs/api-contract.md section 2.2).
const List<String> kItemCategories = [
  'Cameras',
  'Projectors',
  'Gaming consoles',
  'Camping gear',
  'Tools',
  'Musical instruments',
  'Other',
];

/// One row of `items`. Dart names stay short; the JSON keys follow the team
/// contract: `daily_rate`, `pickup_area`, `status`, `declared_value`.
///
/// The exact pickup address is NOT here; it will live in
/// `item_pickup_details` and is unlocked once payment is verified.
class Item extends Equatable {
  const Item({
    required this.id,
    required this.lenderId,
    required this.category,
    required this.title,
    required this.description,
    required this.condition,
    required this.declaredValue,
    required this.dailyPrice,
    required this.pickupArea,
    required this.photoUrls,
    required this.status,
    required this.createdAt,
    this.rules,
    this.lenderFirstName,
  });

  /// Tolerant of columns that are not migrated yet (`category`, `condition`,
  /// `photo_urls`, `rules`): they fall back to empty values. Money columns are
  /// strict: they must be whole NPR.
  factory Item.fromJson(Map<String, dynamic> json) => Item(
        id: json['id'] as String,
        lenderId: json['lender_id'] as String,
        category: (json['category'] as String?) ?? 'Other',
        title: json['title'] as String,
        description: (json['description'] as String?) ?? '',
        condition: (json['condition'] as String?) ?? '',
        declaredValue: json['declared_value'] == null
            ? 0
            : wholeNpr(json['declared_value']),
        dailyPrice: wholeNpr(json['daily_rate']),
        pickupArea: json['pickup_area'] as String,
        photoUrls: json['photo_urls'] == null
            ? const []
            : List<String>.from(json['photo_urls'] as List<dynamic>),
        rules: json['rules'] as String?,
        status: ItemStatus.fromWire(json['status'] as String),
        createdAt: parseTimestamp(json['created_at']),
        lenderFirstName: json['lender_first_name'] as String?,
      );

  final String id;

  /// The Renter who owns the item.
  final String lenderId;
  final String category;
  final String title;
  final String description;
  final String condition;

  /// NPR. The column is nullable; 0 means "not declared yet" and such an item
  /// cannot be requested. The deposit is a percent of this.
  final int declaredValue;

  /// NPR per day (column `daily_rate`), whole NPR, at least 1.
  final int dailyPrice;

  /// Free text such as "Jawalakhel Chowk, Lalitpur". Shown as it is.
  final String pickupArea;

  /// 1 to 5 photo URLs; the first one is the cover.
  final List<String> photoUrls;
  final String? rules;
  final ItemStatus status;
  final DateTime createdAt;

  /// Read-only joined field (profiles name), not a column of `items`.
  final String? lenderFirstName;

  /// Only `active` items are listed publicly.
  bool get isActive => status == ItemStatus.active;

  /// The valley area named in [pickupArea], or null. Used by the area filter.
  Area? get area => Area.fromText(pickupArea);

  String? get coverPhoto => photoUrls.isEmpty ? null : photoUrls.first;

  Item copyWith({
    String? title,
    String? description,
    int? dailyPrice,
    ItemStatus? status,
  }) =>
      Item(
        id: id,
        lenderId: lenderId,
        category: category,
        title: title ?? this.title,
        description: description ?? this.description,
        condition: condition,
        declaredValue: declaredValue,
        dailyPrice: dailyPrice ?? this.dailyPrice,
        pickupArea: pickupArea,
        photoUrls: photoUrls,
        rules: rules,
        status: status ?? this.status,
        createdAt: createdAt,
        lenderFirstName: lenderFirstName,
      );

  /// Item columns only (no joined fields).
  Map<String, dynamic> toJson() => {
        'id': id,
        'lender_id': lenderId,
        'category': category,
        'title': title,
        'description': description,
        'condition': condition,
        'declared_value': declaredValue,
        'daily_rate': dailyPrice,
        'pickup_area': pickupArea,
        'photo_urls': photoUrls,
        'rules': rules,
        'status': status.wire,
        'created_at': formatTimestamp(createdAt),
      };

  @override
  List<Object?> get props => [
        id,
        lenderId,
        category,
        title,
        description,
        condition,
        declaredValue,
        dailyPrice,
        pickupArea,
        photoUrls,
        rules,
        status,
        createdAt,
        lenderFirstName,
      ];
}
