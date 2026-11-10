# Unified UI redesign

The Flutter app uses `MaestroShell` for the Teacher, Student, and Parent portals. Phones show four primary destinations and a More tab. From 600 px upward, the same destinations appear in a navigation rail; More opens the right drawer. The header, unread badge, profile menu, and sign out control are shared. Each role supplies only destinations it can use.

`DashboardLayout` provides responsive summary cards, a six-action grid, and activity sections. It caps content width at 1440 px. The teacher dashboard still reads its existing student and payment data source. The student dashboard uses the existing student portal RPC response and checks teacher-controlled permissions before showing content. The parent dashboard uses only rows returned by `maestro_parent_portal_data`; the child selector filters summaries, lessons, payments, and children by a linked student ID. No auth, RLS, or database changes were made for this redesign.

## Unavailable actions

- Reports: no report screen exists in the Flutter client.
- Student Practice Videos: the current student portal service does not return or navigate to practice videos.
- Parent Progress: the current parent portal RPC does not expose progress data.
- Parent lesson details: the current parent RPC returns lesson rows only for children with finance access. The dashboard shows an unavailable state for other children.

These actions remain disabled or show an unavailable state. Teacher Add Note opens student management, where an existing student and lesson can be selected to add a note. Record Payment opens the existing Payments screen and its Add Payment control.

The existing screens use several fixed light colors, so automatic dark mode remains disabled until those screens can be converted without contrast regressions.

## Verification

Run from `maestro-mobile`:

```sh
flutter analyze
flutter test
flutter build web --release
```

For database access checks, run the repository's existing local pgTAP suite after the local Supabase stack is running:

```sh
npx --yes supabase test db --local
```

The parent access tests include direct table and RPC reads for unrelated students and payments. They are required for a live security claim; static inspection alone does not prove deployed RLS behavior.
