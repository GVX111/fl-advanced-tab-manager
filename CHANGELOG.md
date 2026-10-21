## 0.4.9+1 - Closed panels reopen in their place

- A container closed with its last tab (or emptied by `removePanel`) is remembered: a panel of the same group (or the same panel) added again without a drop zone goes back to that place, with the same split direction and size, instead of a default spot (e.g. a new centre over the whole layout). `DockLayout.simplify()` drops empty containers and remembers where they were.

## 0.4.9 - Focus, flyouts and splitters

- Focused container: its active tab is filled with the accent colour; the active tab of other containers is only lighter than the strip. New `DockStyle` colours: `tabStripBackground`, `tabFocusedActiveBackground`, `tabFocusedActiveText`, `tabActiveBackground`, `tabInactiveText`. `DockLayout.focusedPanelId` follows clicks, added and activated panels.
- Maximize, pin and close buttons react to the mouse (`DockIconButton`).
- Auto-hide flyouts slide out of their strip and back (up/down at the bottom, out/in at the sides), take the focus when opened (accent header and border) and pad their content: `DockStyle.flyoutContentPadding` (default 8), per panel `DockPanelSpec.flyoutPadding`.
- Flyout resize edge: a thin line that lights up on hover instead of a bar over the content; it no longer hides the flyout's border.
- Strip chips: text centred and whole, with a shadow for readability.
- Splitters: only the panes next to the divider resize (panes further away keep their size), panes stop at `DockStyle.minPanelWidth`/`minPanelHeight` (160/90), and neighbours squeezed during a drag grow back when dragging back.

## 0.4.8 - Tab strip fix

- Fix 0.4.7: every tab took the whole width of the strip, so only one tab of a container was visible. Tabs are as wide as their title again; a long title is shortened with … (full title in the tooltip) and pin and close stay visible.

## 0.4.7 - Docking fixes

- Removing a panel drops the container it leaves empty (no "Empty" area left behind, e.g. after a placeholder panel is replaced).
- Auto-hide flyouts are sized from the dock area instead of the whole window, so their bottom and right edges are no longer cut off.
- Tabs never grow wider than the tab strip: the title shrinks and scrolls (full title in a tooltip), pin and close stay visible.
- The active tab is clearly marked: it takes the panel colour with a bright top marker and bold title; other tabs are dimmer.
- Auto-hide strip buttons are readable: a visible chip, bolder text, accent colour when active or hovered.

## 0.4.6+2 - Advanced docking panel

- Update Fluent UI Package
