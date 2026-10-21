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
