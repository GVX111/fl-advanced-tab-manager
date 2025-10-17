// lib/dockx_ads/core/persistence.dart
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:fl_advanced_tab_manager/dockx_ads/core/models.dart';

/// A factory that creates a DockPanelSpec for a given id when the registry doesn't have it yet.
/// Return null if you don't recognize the id — the missing policy will handle it.
typedef DockSpecFactory = DockPanelSpec? Function(String panelId);

/// What to do if a panel id from the saved layout is not in the registry
/// and the specFactory couldn't produce one.
enum MissingPanelPolicy {
  /// Register a simple placeholder panel, so the layout stays intact.
  registerPlaceholder,

  /// Silently drop that panel id from the container.
  ignore,

  /// Throw ArgumentError.
  throwError,
}

/// Persistence helper (export/import).
class DockPersistence {
  /// Serialize only the layout topology and panel ids (no widget trees).
  static String exportToJsonString(DockLayout layout) {
    return jsonEncode(layout);
  }

  /// Import a layout from JSON string and **ensure** that every referenced panel id
  /// is present in `registry` by using:
  ///   1) `specFactory(id)` for unknown ids
  ///   2) Otherwise `missingPanelPolicy`
  ///
  /// Returns a **new** DockLayout wired to the same `registry`.
  static DockLayout importFromJsonString(
    String jsonStr,
    DockPanelRegistry registry, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,

    // Optional customization for placeholders:
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    final rootMap = (jsonDecode(jsonStr) as Map<String, dynamic>)['root']
        as Map<String, dynamic>;

    final resolvedRoot = _nodeFromJsonWithResolution(
      rootMap,
      registry,
      specFactory: specFactory,
      missingPanelPolicy: missingPanelPolicy,
      missingPanelBuilder: missingPanelBuilder,
      missingPanelTitle: missingPanelTitle,
      missingPanelSide: missingPanelSide,
    );

    return DockLayout(root: resolvedRoot, registry: registry);
  }

  // ---- internals ----

  static DockNode _nodeFromJsonWithResolution(
    Map<String, dynamic> j,
    DockPanelRegistry reg, {
    DockSpecFactory? specFactory,
    MissingPanelPolicy missingPanelPolicy =
        MissingPanelPolicy.registerPlaceholder,
    Widget Function(BuildContext ctx, String missingId)? missingPanelBuilder,
    String Function(String missingId)? missingPanelTitle,
    DockSide Function(String missingId)? missingPanelSide,
  }) {
    final kind = j['kind'] as String?;

    if (kind == 'split') {
      // Build children first
      final a = _nodeFromJsonWithResolution(
        (j['a'] as Map<String, dynamic>),
        reg,
        specFactory: specFactory,
        missingPanelPolicy: missingPanelPolicy,
        missingPanelBuilder: missingPanelBuilder,
        missingPanelTitle: missingPanelTitle,
        missingPanelSide: missingPanelSide,
      );
      final b = _nodeFromJsonWithResolution(
        (j['b'] as Map<String, dynamic>),
        reg,
        specFactory: specFactory,
        missingPanelPolicy: missingPanelPolicy,
        missingPanelBuilder: missingPanelBuilder,
        missingPanelTitle: missingPanelTitle,
        missingPanelSide: missingPanelSide,
      );
      // Reuse your SplitNode.fromJson to pick axis & ratio
      final split = SplitNode.fromJson(j, reg);
      split.a = a;
      split.b = b;
      return split;
    }

    if (kind == 'container') {
      // Parse with your constructor, then resolve its panelIds
      final node = ContainerNode.fromJson(j);

      final resolvedIds = <String>[];
      for (final id in node.panelIds) {
        if (reg.has(id)) {
          resolvedIds.add(id);
          continue;
        }

        // try user factory
        final spec = specFactory?.call(id);
        if (spec != null) {
          reg.register(spec);
          resolvedIds.add(id);
          continue;
        }

        // policy
        switch (missingPanelPolicy) {
          case MissingPanelPolicy.registerPlaceholder:
            final title = missingPanelTitle?.call(id);
            final side = missingPanelSide?.call(id);
            if (title == null || side == null) continue;
            reg.register(DockPanelSpec(
              id: id,
              title: title,
              position: side,
              builder: (ctx) => (missingPanelBuilder != null)
                  ? missingPanelBuilder(ctx, id)
                  : Center(child: Text('Missing panel: $id')),
            ));
            resolvedIds.add(id);
            break;

          case MissingPanelPolicy.ignore:
            // drop it
            break;

          case MissingPanelPolicy.throwError:
            throw ArgumentError('Unknown panel id: $id');
        }
      }

      node.panelIds
        ..clear()
        ..addAll(resolvedIds);
      // clamp active index safely
      // (ContainerNode already clamps in ctor/fromJson, but after editing list we ensure again)
      node.activateById(
        node.panelIds.isEmpty
            ? ''
            : node
                .panelIds[node.activeIndex.clamp(0, node.panelIds.length - 1)],
      );
      return node;
    }

    throw ArgumentError('Unknown node kind: $kind');
  }
}

/// --------- nice-to-use extensions ---------

extension DockLayoutExport on DockLayout {
  /// Export this layout to a JSON string.
  String exportJson() => DockPersistence.exportToJsonString(this);
}

extension DockRegistryImport on DockPanelRegistry {
  /// Import JSON into a **new** DockLayout, resolving missing panels
  /// using [specFactory] or [missingPanelPolicy].
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
