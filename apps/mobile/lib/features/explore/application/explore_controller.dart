import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rental_core/rental_core.dart';
import 'package:rental_data/rental_data.dart';

import 'catalog_providers.dart';

enum ExploreStatus { loading, ready, loadingMore, error }

/// Everything the Explore screen draws.
class ExploreState {
  const ExploreState({
    this.items = const [],
    this.query = const ItemQuery(),
    this.cursor,
    this.hasMore = true,
    this.status = ExploreStatus.loading,
    this.errorMessage,
  });

  final List<Item> items;
  final ItemQuery query;

  /// Where the next page starts. Null when there is no next page.
  final ItemCursor? cursor;
  final bool hasMore;
  final ExploreStatus status;
  final String? errorMessage;
}

/// Loads the Explore list page by page. The widget never calls a repository.
/// Errors are kept in the state (not thrown), so the screen can show a retry.
class ExploreController extends Notifier<ExploreState> {
  Timer? _debounce;
  int _requestId = 0;
  bool _disposed = false;

  @override
  ExploreState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    unawaited(Future<void>.microtask(refresh));
    return const ExploreState();
  }

  /// Starts again from page one with the current filters.
  Future<void> refresh() async {
    final id = ++_requestId;
    state = ExploreState(query: state.query);
    await _fetch(id, after: null, previous: const []);
  }

  /// Called when the list is scrolled near the bottom.
  void loadMore() {
    final current = state;
    final canLoad = current.status == ExploreStatus.ready ||
        (current.status == ExploreStatus.error && current.items.isNotEmpty);
    if (!canLoad || !current.hasMore) return;
    final id = ++_requestId;
    state = ExploreState(
      items: current.items,
      query: current.query,
      cursor: current.cursor,
      status: ExploreStatus.loadingMore,
    );
    unawaited(_fetch(id, after: current.cursor, previous: current.items));
  }

  /// Search while typing: waits 350 ms after the last key.
  void setSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (_disposed) return;
      final value = text.trim();
      _apply(
        value.isEmpty
            ? state.query.copyWith(clearSearch: true)
            : state.query.copyWith(search: value),
      );
    });
  }

  /// Pass null for "All".
  void setCategory(String? category) {
    _apply(
      category == null
          ? state.query.copyWith(clearCategory: true)
          : state.query.copyWith(category: category),
    );
  }

  /// Area, price range and sort from the filter sheet. Null means "any".
  void applyFilters({
    Area? area,
    int? minPrice,
    int? maxPrice,
    required ItemSort sort,
  }) {
    final base = state.query.copyWith(
      clearArea: true,
      clearPrice: true,
      sort: sort,
    );
    _apply(
      ItemQuery(
        search: base.search,
        category: base.category,
        area: area,
        minPrice: minPrice,
        maxPrice: maxPrice,
        sort: base.sort,
      ),
    );
  }

  /// Clears search, category and every filter.
  void clearAll() => _apply(const ItemQuery());

  /// Try again after an error.
  void retry() => unawaited(refresh());

  void _apply(ItemQuery query) {
    _requestId++;
    state = ExploreState(query: query);
    unawaited(refresh());
  }

  Future<void> _fetch(
    int id, {
    required ItemCursor? after,
    required List<Item> previous,
  }) async {
    final query = state.query;
    try {
      final page = await ref
          .read(itemRepositoryProvider)
          .listItems(query: query, after: after);
      if (_disposed || id != _requestId) return;
      state = ExploreState(
        items: [...previous, ...page.items],
        query: query,
        cursor: page.nextCursor,
        hasMore: page.nextCursor != null,
        status: ExploreStatus.ready,
      );
    } on AppException catch (e) {
      _showError(id, query, previous, after, e.message);
    } catch (_) {
      const text = 'Could not load items. Please try again.';
      _showError(id, query, previous, after, text);
    }
  }

  void _showError(
    int id,
    ItemQuery query,
    List<Item> previous,
    ItemCursor? after,
    String text,
  ) {
    if (_disposed || id != _requestId) return;
    // Keep the cursor so "retry" asks for the same page again.
    state = ExploreState(
      items: previous,
      query: query,
      cursor: after,
      status: ExploreStatus.error,
      errorMessage: text,
    );
  }
}

final exploreControllerProvider =
    NotifierProvider<ExploreController, ExploreState>(ExploreController.new);
