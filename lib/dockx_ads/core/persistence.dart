import 'dart:convert';
import 'package:fl_advanced_tab_manager/dockx_ads/core/container_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_layout.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_registry.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/dock_panel_spec.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/drag_model.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/dock_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/enums/split_node.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/split_node.dart';
import 'package:flutter/widgets.dart';

typedef DockSpecFactory = DockPanelSpec? Function(String id);

enum MissingPanelPolicy {
  /// Try specFactory; if still missing, register a placeholder DockPanelSpec.
  registerPlaceholder,

  /// Try specFactory; if still missing, skip this panel id.
  skip,

  /// Try specFactory; if still missing, throw ArgumentError.
  throwIfMissing,
}

/* -------------------------- Persistence API ------------------------- */

class DockPersistence {
  /* ============================ EXPORT ============================ */

  /// Export as structured Map (includes autoHidden).
  static Map<String, dynamic> exportToJson(DockLayout layout) {
    return {
      'root': layout.root.toJson(),
      'autoHidden': {
        'left': List<String>.from(layout.autoHidden[AutoSide.left] ?? const []),
        'right':
            List<String>.from(layout.autoHidden[AutoSide.right] ?? const []),
        'bottom':
            List<String>.from(layout.autoHidden[AutoSide.bottom] ?? const []),
      },
    };
  }

  /// Export as JSON string.
  static String exportToJsonString(DockLayout layout) =>
      jsonEncode(exportToJson(layout));

  /* ============================ IMPORT ============================ */

  /// Import from JSON string, resolving missing ids as configured.
  static DockLayout importFromJsonString(
    String jsonStr,
    DockPanelRegistry registry, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,

    // Optional placeholder customizations:
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    final map = jsonDecode(jsonStr) as Map<String, dynamic>;
    return importFromJson(
      map,
      registry,
      specFactory: specFactory,
      missingPanelPolicy: missingPanelPolicy,
      missingPanelBuilder: missingPanelBuilder,
      missingPanelTitle: missingPanelTitle,
      missingPanelSide: missingPanelSide,
    );
  }

  /// Import from structured Map (same semantics as above).
  static DockLayout importFromJson(
    Map<String, dynamic> map,
    DockPanelRegistry registry, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,

    // Optional placeholder customizations:
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    final rootMap = map['root'] as Map<String, dynamic>;

    final resolvedRoot = _nodeFromJsonWithResolution(
      rootMap,
      registry,
      specFactory: specFactory,
      missingPanelPolicy: missingPanelPolicy,
      missingPanelBuilder: missingPanelBuilder,
      missingPanelTitle: missingPanelTitle,
      missingPanelSide: missingPanelSide,
    );

    final layout = DockLayout(root: resolvedRoot, registry: registry);

    // Load autoHidden (may be absent)
    final ah = (map['autoHidden'] as Map?) ?? const {};
    _readAutoHiddenArray(layout, AutoSide.left, ah['left']);
    _readAutoHiddenArray(layout, AutoSide.right, ah['right']);
    _readAutoHiddenArray(layout, AutoSide.bottom, ah['bottom']);

    // After loading strips, make sure container tabs don’t include hidden ids.
    _pruneAutoHiddenPanels(layout);

    return layout;
  }

  /* ======================= Internal helpers ======================= */

  static void _readAutoHiddenArray(
    DockLayout layout,
    AutoSide side,
    Object? raw,
  ) {
    final list = (raw is List) ? raw.cast() : const [];
    final result = <String>[];

    for (final e in list) {
      if (e is! String) continue;
      // Ensure the id is registered (try factory / placeholder / skip / throw).
      final ok = _ensureRegistered(
        e,
        layout.registry,
        specFactory:
            null, // layout already built with resolution; leave null here
        // NOTE: if you want *autoHidden* also to attempt specFactory, pass it down
      );
      if (ok) result.add(e);
    }
    layout.autoHidden[side] = result;
  }

  static DockNode _nodeFromJsonWithResolution(
    Map<String, dynamic> j,
    DockPanelRegistry registry, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    final k = j['kind'];
    if (k == 'split') {
      return SplitNode(
        axis: j['axis'] == 'horizontal'
            ? SplitAxis.horizontal
            : SplitAxis.vertical,
        ratio: (j['ratio'] as num).toDouble(),
        a: _nodeFromJsonWithResolution(
          j['a'] as Map<String, dynamic>,
          registry,
          specFactory: specFactory,
          missingPanelPolicy: missingPanelPolicy,
          missingPanelBuilder: missingPanelBuilder,
          missingPanelTitle: missingPanelTitle,
          missingPanelSide: missingPanelSide,
        ),
        b: _nodeFromJsonWithResolution(
          j['b'] as Map<String, dynamic>,
          registry,
          specFactory: specFactory,
          missingPanelPolicy: missingPanelPolicy,
          missingPanelBuilder: missingPanelBuilder,
          missingPanelTitle: missingPanelTitle,
          missingPanelSide: missingPanelSide,
        ),
      );
    }

    if (k == 'container') {
      final rawIds = List<String>.from(
          (j['panelIds'] as List? ?? const <String>[]).cast());
      final active = (j['activeIndex'] as num?)?.toInt() ?? 0;
      final side = _dockSideFromStr(j['side'] as String?);

      // Resolve / filter panel ids
      final ids = <String>[];
      for (final id in rawIds) {
        final ok = _ensureRegistered(
          id,
          registry,
          specFactory: specFactory,
          missingPanelPolicy: missingPanelPolicy,
          missingPanelBuilder: missingPanelBuilder,
          missingPanelTitle: missingPanelTitle,
          missingPanelSide: missingPanelSide,
        );
        if (ok) ids.add(id);
      }

      final c = ContainerNode(panelIds: ids, activeIndex: active, side: side);
      return c;
    }

    throw ArgumentError('Unknown node kind: $k');
  }

  static DockSide _dockSideFromStr(String? s) {
    switch (s) {
      case 'left':
        return DockSide.left;
      case 'right':
        return DockSide.right;
      case 'bottom':
        return DockSide.bottom;
      case 'center':
      default:
        return DockSide.center;
    }
  }

  /// Ensures a panel id is registered in [registry].
  /// Returns true if the id is now available, false when skipped.
  static bool _ensureRegistered(
    String id,
    DockPanelRegistry registry, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    if (registry.has(id)) return true;

    // Try user factory first
    final fromFactory = specFactory?.call(id);
    if (fromFactory != null) {
      registry.register(fromFactory);
      return true;
    }

    switch (missingPanelPolicy) {
      case MissingPanelPolicy.registerPlaceholder:
        final placeholder = DockPanelSpec(
          id: id,
          title: (missingPanelTitle?.call(id)) ?? 'Missing: $id',
          builder: (ctx) =>
              (missingPanelBuilder?.call(ctx, id)) ??
              Center(
                child: Text(
                  'Panel "$id" is not available.',
                  textAlign: TextAlign.center,
                ),
              ),
          position: (missingPanelSide?.call(id)) ?? DockSide.center,
        );
        registry.register(placeholder);
        return true;

      case MissingPanelPolicy.skip:
        return false;

      case MissingPanelPolicy.throwIfMissing:
        throw ArgumentError('Unknown panel id: $id');
    }
  }

  /// Remove hidden ids from containers and collapse empty splits.
  static void _pruneAutoHiddenPanels(DockLayout layout) {
    final hiddenIds = <String>{
      ...layout.autoHidden[AutoSide.left]!,
      ...layout.autoHidden[AutoSide.right]!,
      ...layout.autoHidden[AutoSide.bottom]!,
    };
    if (hiddenIds.isEmpty) return;

    void removeEverywhere(DockNode n) {
      if (n is ContainerNode) {
        n.panelIds.removeWhere(hiddenIds.contains);
        if (n.activeIndex >= n.panelIds.length) {
          n.activeIndex = n.panelIds.isEmpty ? 0 : n.panelIds.length - 1;
        }
      } else if (n is SplitNode) {
        removeEverywhere(n.a);
        removeEverywhere(n.b);
      }
    }

    DockNode collapseEmpty(DockNode n) {
      if (n is SplitNode) {
        n.a = collapseEmpty(n.a);
        n.b = collapseEmpty(n.b);
        if (n.a is ContainerNode && (n.a as ContainerNode).panelIds.isEmpty) {
          return n.b;
        }
        if (n.b is ContainerNode && (n.b as ContainerNode).panelIds.isEmpty) {
          return n.a;
        }
      }
      return n;
    }

    removeEverywhere(layout.root);
    layout.root = collapseEmpty(layout.root);
  }
}

/* ----------------- Optional: registry convenience ------------------ */

extension DockRegistryImport on DockPanelRegistry {
  /// Convenience wrapper: parse & resolve using this registry.
  DockLayout importJson(
    String jsonStr, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    return DockPersistence.importFromJsonString(
      jsonStr,
      this,
      specFactory: specFactory,
      missingPanelPolicy: missingPanelPolicy,
      missingPanelBuilder: missingPanelBuilder,
      missingPanelTitle: missingPanelTitle,
      missingPanelSide: missingPanelSide,
    );
  }
}
