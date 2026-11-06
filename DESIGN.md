---
name: VPS Monitor
description: Native macOS server monitoring following the supplied redesigned Overview reference.
typography:
  server-title:
    fontFamily: "System"
    fontSize: "30pt"
    fontWeight: 600
  resource-value:
    fontFamily: "System"
    fontSize: "44pt"
    fontWeight: 300
  resource-unit:
    fontFamily: "System"
    fontSize: "23pt"
  file-preview:
    fontFamily: "System Monospaced"
    fontSize: "12pt"
rounded:
  source-selection: "8pt"
  source-icon: "6pt"
  alert: "10pt"
spacing:
  small: "12pt"
  toolbar-inset: "16pt"
  compact-content: "24pt"
  section: "28pt"
  resource-gap: "32pt"
  detail-content: "36pt"
  column-gap: "48pt"
---

# Design System: VPS Monitor

## Visual authority

The user's supplied “Overview (redesigned)” image is the authority for the app's visual treatment. Preserve its quiet charcoal surfaces, neutral navigation selection, colored icon tiles, large lightweight resource percentages, thin meters, shaded history plots, failure callout, and paired service columns. Native macOS controls and window chrome remain functional and familiar. The surface is an operating tool: real data, clear status, and fast inspection take priority.

## Appearance and color

Follow the system's light or dark appearance. `MonitorSurface` resolves the reference's dark content (white 0.075) and sidebar (white 0.10), with corresponding light content (0.99) and sidebar (0.96). Use primary and secondary semantic text, native tables, focus rings, and system sheets. The unified window toolbar shares the content background.

`MonitorPalette` defines the reference's resource accents in sRGB: CPU (0.32, 0.65, 1), memory (0.73, 0.51, 0.96), and storage (0.30, 0.79, 0.82). Sidebar icons reuse these roles, with orange for Services. White SF Symbols sit on subtle native color gradients inside 25 pt tiles. Selected navigation uses primary color at 7% opacity.

Green denotes active or running services, red denotes failed services, and orange denotes transitional states or monitoring warnings. Always pair status color with text. Missing and inactive units use neutral styling; neither implies failure. Failure alerts use a red tint at 8% opacity with a 25% red outline.

## Typography

Use the system font. Server titles use 30 pt semibold; sidebar server names use 17 pt semibold. Resource values use 44 pt light with a secondary 23 pt percentage suffix and monospaced digits. Supporting measurements use caption text. Resource labels and service column headings use uppercase captions with modest tracking, matching the reference. Ordinary section titles use native headline text.

Paths, permissions, SSH fingerprints, and file content use system monospaced text. Do not apply monospace to ordinary navigation or status descriptions.

## Window and navigation

The default window is 1240 × 960 pt; the minimum remains 960 × 640 pt. The source column ranges from 210 to 300 pt, with 225 pt ideal width. The native unified toolbar holds the section title, refresh interval picker, pause/resume, and refresh actions. Keep real macOS window controls and keyboard commands.

The sidebar has server identity and a compact connection/monitoring status above a divider, four navigation rows with colored icon tiles, and the SSH endpoint and disconnect action at the bottom. Services receives a red indicator only when collected data contains failed units. Distinguish being connected from readings being current, paused, or stale.

## Overview composition

Use a vertical scroll view with 36 pt content padding on wider detail panes and 24 pt on narrower panes. Sections are 28 pt apart. The order is server identity and uptime, an optional failure banner, resources, history, and services.

Three equal resource columns are separated by dividers and 32 pt gaps. Every resource presents percentage usage, a 3 pt tinted capsule meter, and capacity or measurement details. CPU initially reads “Sampling…”; its accessibility value explains that another reading is needed.

CPU and memory charts share a row with a 48 pt gap. Each chart has a title and the actual collected duration, a fixed 0–100 vertical scale, subtle horizontal grid lines, a shaded area under a monotone line, and a marked latest sample. Chart height is 120 pt. Time-axis labels are hidden; the header describes duration. Never label the graph as ten minutes unless ten minutes of data exists. Load averages sit below CPU history; swap information sits below memory history.

Services has active and failed totals and a View all action. Applications and Databases & cache share two equal columns when the detail pane is at least 830 pt wide and stack below that width. Each service row is at least 43 pt high with aligned dividers. Preserve scrolling at minimum window size and when groups expand.

## Interaction and status

A failure banner appears only for collected failed systemd units and only when the services query succeeded. Review opens Services with the Failed filter. View all and sidebar Services open the full service list. Failed is an explicit filter, distinct from inactive or missing units.

Application rows show a status dot, group name, count, active/total ratio, and trailing expansion chevron. Activating a row reveals individual selectable service names and readable status labels. Expose expanded/collapsed state and active/failed counts to accessibility.

Database rows translate active/running to Running and active/exited to Completed. Completed does not confirm a running process; preserve the raw state and substate in help text. Other states remain explicit, including Not loaded.

The footer shows the last successful reading's timestamp and relative age plus SSH · Read-only. Refreshing, paused, stale, error, and empty states remain visible and truthful. Retain the last readings on refresh failure and provide Retry.

## Supporting screens

Connection fields use native grouped Server and Authentication sections. Keep SSH trust verification in a focused native sheet with selectable fingerprints, Cancel, and Trust and Connect. Credentials, permissions, and remote operations retain their existing behavior.

Processes, Services, and Files retain native sortable tables, search/filter controls, numerical sorting, and contextual actions. Empty process and file states explain how to recover. Services names the raw substate column explicitly. Files keeps parent/home navigation, editable paths, hidden-file control, preview sheets, and read-only actions.

## Verification

Review light and dark renders, the 960 × 640 pt minimum, long server names, failure banners, filtered failed services, paused and stale readings, empty history, and individual service states. Use synthetic fixtures for screenshots and never represent them as live server readings. Build and verify the packaged app and SSH helper after UI changes.
