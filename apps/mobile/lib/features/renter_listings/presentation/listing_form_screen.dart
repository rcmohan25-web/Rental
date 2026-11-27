import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import '../../../shared/id_gate.dart';
import '../../../shared/image_selector.dart';
import '../application/listing_error_messages.dart';
import '../application/listing_providers.dart';

const List<String> _conditions = ['Like new', 'Good', 'Fair'];

/// Add or edit a listing (1 to 5 photos, declared value, rules, pickup area).
/// Pass [itemId] to edit. Owner: Srijan.
class ListingFormScreen extends ConsumerStatefulWidget {
  const ListingFormScreen({this.itemId, super.key});

  final String? itemId;

  @override
  ConsumerState<ListingFormScreen> createState() => _ListingFormScreenState();
}

class _ListingFormScreenState extends ConsumerState<ListingFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _declared = TextEditingController();
  final _price = TextEditingController();
  final _landmark = TextEditingController();
  final _address = TextEditingController();
  final _instructions = TextEditingController();
  final _rules = TextEditingController();

  String? _category;
  String? _condition;
  Area? _area;
  List<ListingPhoto> _photos = [];
  ItemStatus? _status;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    if (_editing) {
      _loading = true;
      Future<void>.microtask(_load);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _declared,
      _price,
      _landmark,
      _address,
      _instructions,
      _rules,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final listing = await ref
          .read(listingRepositoryProvider)
          .getMyListing(widget.itemId!);
      if (!mounted) return;
      final item = listing.item;
      final area = item.area;
      var landmark = item.pickupArea;
      if (area != null && landmark.toLowerCase().endsWith(area.wire)) {
        landmark = landmark
            .substring(0, landmark.length - area.label.length)
            .replaceAll(RegExp(r'[,\s]+$'), '');
      }
      setState(() {
        _title.text = item.title;
        _description.text = item.description;
        _declared.text = '${item.declaredValue}';
        _price.text = '${item.dailyPrice}';
        _landmark.text = landmark;
        _address.text = listing.exactAddress;
        _instructions.text = listing.pickupInstructions ?? '';
        _rules.text = item.rules ?? '';
        _category = kItemCategories.contains(item.category)
            ? item.category
            : null;
        _condition = _conditions.contains(item.condition)
            ? item.condition
            : null;
        _area = area;
        _photos = listing.photos;
        _status = item.status;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyListingError(e);
      });
    }
  }

  Future<void> _addPhoto() async {
    if (_photos.length >= AppConstants.maxListingPhotos) return;
    final source = await showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheet).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    try {
      final photo = await ref.read(imageSelectorProvider).pick(source);
      if (photo == null || !mounted) return;
      setState(() => _photos = [..._photos, ListingPhoto.upload(photo)]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = friendlyListingError(e));
    }
  }

  ListingInput? _input({required bool publish}) {
    if (!_formKey.currentState!.validate()) return null;
    final declared = parseNpr(_declared.text);
    final price = parseNpr(_price.text);
    if (_category == null ||
        _condition == null ||
        _area == null ||
        declared == null ||
        price == null) {
      setState(() => _error = 'Please fill in every required field.');
      return null;
    }
    if (publish && _photos.isEmpty) {
      setState(() => _error = 'Add at least one photo to publish.');
      return null;
    }
    return ListingInput(
      title: _title.text,
      description: _description.text,
      category: _category!,
      condition: _condition!,
      declaredValue: declared,
      dailyPrice: price,
      pickupArea: '${_landmark.text.trim()}, ${_area!.label}',
      exactAddress: _address.text,
      pickupInstructions: _instructions.text,
      rules: _rules.text,
      photos: _photos,
      publish: publish,
    );
  }

  Future<void> _save({required bool publish}) async {
    if (_saving) return;
    setState(() => _error = null);
    final input = _input(publish: publish);
    if (input == null) return;
    // The ID gate: publishing needs an ID submitted. Drafts do not.
    if (publish && !await ensureIdSubmitted(context, ref)) return;
    setState(() => _saving = true);
    try {
      final repository = ref.read(listingRepositoryProvider);
      if (_editing) {
        await repository.updateListing(widget.itemId!, input);
      } else {
        await repository.createListing(input);
      }
      ref.invalidate(myItemsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(publish ? 'Listing saved.' : 'Draft saved.')),
      );
      context.go('/listings');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyListingError(e);
      });
    }
  }

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? 'This field is required.' : null;

  String? _wholeNpr(String? v) {
    final n = parseNpr(v ?? '');
    return n == null || n < 1 ? 'Enter a whole number of NPR.' : null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit listing' : 'Add listing')),
      body: _loading
          ? const LoadingView(message: 'Loading listing')
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildPhotos(),
                  const SizedBox(height: 16),
                  Form(key: _formKey, child: _buildFields()),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: BrandColors.danger),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _buildButtons(),
                ],
              ),
            ),
    );
  }

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photos (1 to ${AppConstants.maxListingPhotos}, the first is the cover)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (var i = 0; i < _photos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _PhotoTile(
                    photo: _photos[i],
                    onRemove: () =>
                        setState(() => _photos = [..._photos]..removeAt(i)),
                  ),
                ),
              if (_photos.length < AppConstants.maxListingPhotos)
                InkWell(
                  onTap: _addPhoto,
                  child: Container(
                    width: 96,
                    decoration: BoxDecoration(
                      border: Border.all(color: BrandColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_a_photo_outlined),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFields() {
    return Column(
      children: [
        AppTextField(
          label: 'Title',
          controller: _title,
          textInputAction: TextInputAction.next,
          validator: _required,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in kItemCategories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          validator: (v) => v == null ? 'Choose a category.' : null,
          onChanged: (v) => setState(() => _category = v),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'Condition'),
          items: [
            for (final c in _conditions)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          validator: (v) => v == null ? 'Choose the condition.' : null,
          onChanged: (v) => setState(() => _condition = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Description',
          controller: _description,
          maxLines: 4,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Price per day (NPR)',
          controller: _price,
          keyboardType: TextInputType.number,
          validator: _wholeNpr,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Declared value (NPR)',
          controller: _declared,
          keyboardType: TextInputType.number,
          helperText:
              'What the item is worth. The refundable deposit is a '
              'share of it, set by Sapati.',
          validator: _wholeNpr,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<Area>(
          initialValue: _area,
          decoration: const InputDecoration(labelText: 'Pickup area'),
          items: [
            for (final a in Area.values)
              DropdownMenuItem(value: a, child: Text(a.label)),
          ],
          validator: (v) => v == null ? 'Choose the area.' : null,
          onChanged: (v) => setState(() => _area = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Landmark or neighbourhood',
          controller: _landmark,
          helperText: 'Shown to everyone, for example Jawalakhel Chowk.',
          validator: _required,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Exact pickup address (private)',
          controller: _address,
          helperText:
              'Shared only with the Borrower after payment is '
              'verified.',
          validator: _required,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Pickup instructions (optional)',
          controller: _instructions,
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Rules (optional)',
          controller: _rules,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildButtons() {
    final active = _status == ItemStatus.active;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PrimaryButton(
          label: _editing
              ? (active ? 'Save changes' : 'Save and publish')
              : 'Publish',
          loading: _saving,
          onPressed: () => _save(publish: true),
        ),
        if (!_editing || !active) ...[
          const SizedBox(height: 8),
          SecondaryButton(
            label: 'Save as draft',
            onPressed: _saving ? null : () => _save(publish: false),
          ),
        ],
      ],
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo, required this.onRemove});

  final ListingPhoto photo;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final upload = photo.upload;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 96,
            height: 96,
            child: upload != null
                ? Image.memory(upload.bytes, fit: BoxFit.cover)
                : Image.network(
                    photo.url!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: BrandColors.border,
                      child: Icon(Icons.image_outlined),
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: IconButton(
            tooltip: 'Remove photo',
            visualDensity: VisualDensity.compact,
            style: IconButton.styleFrom(backgroundColor: Colors.black54),
            icon: const Icon(Icons.close, size: 16, color: Colors.white),
            onPressed: onRemove,
          ),
        ),
      ],
    );
  }
}
