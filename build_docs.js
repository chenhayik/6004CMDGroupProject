const fs = require("fs");
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  AlignmentType, LevelFormat, HeadingLevel, BorderStyle, WidthType, ShadingType,
  TableOfContents, PageBreak, VerticalAlign,
} = require("docx");

// ── palette ──
const BRAND = "16A34A";       // green
const INK = "0F172A";
const MUTED = "475569";
const BORDER = "CBD5E1";
const TAGFILL = {
  "Critical":    "FBD5D5",
  "Important":   "D6E4F5",
  "Nice-to-have":"D7EFDD",
  "Cosmetic":    "E5E7EB",
};

const CONTENT_W = 9360; // US Letter, 1" margins

// ── helpers ──
const border = { style: BorderStyle.SINGLE, size: 1, color: BORDER };
const allBorders = { top: border, left: border, bottom: border, right: border };

function h1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun(text)] });
}
function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun(text)] });
}
function p(text, opts = {}) {
  return new Paragraph({
    spacing: { after: 120 },
    children: [new TextRun({ text, color: opts.color || INK, italics: !!opts.italics })],
  });
}
// "Label: value" line with a bold label
function labeled(label, value) {
  return new Paragraph({
    spacing: { after: 100 },
    children: [
      new TextRun({ text: label + ": ", bold: true, color: BRAND }),
      new TextRun({ text: value, color: INK }),
    ],
  });
}
function tag(value) {
  return new Paragraph({
    spacing: { after: 100 },
    children: [
      new TextRun({ text: "Priority: ", bold: true, color: BRAND }),
      new TextRun({ text: value, bold: true, color: INK }),
    ],
  });
}
function bullet(text) {
  return new Paragraph({ numbering: { reference: "bullets", level: 0 },
    children: [new TextRun({ text, color: INK })] });
}
// screenshot placeholder box + caption (single-cell table so borders validate)
function shot(caption, figNo) {
  return [
    new Table({
      width: { size: CONTENT_W, type: WidthType.DXA },
      columnWidths: [CONTENT_W],
      rows: [new TableRow({ children: [new TableCell({
        borders: allBorders,
        width: { size: CONTENT_W, type: WidthType.DXA },
        shading: { fill: "F1F5F9", type: ShadingType.CLEAR },
        margins: { top: 460, bottom: 460, left: 120, right: 120 },
        verticalAlign: VerticalAlign.CENTER,
        children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [
          new TextRun({ text: "[ Screenshot placeholder ]", italics: true, color: MUTED }),
        ] })],
      })] })],
    }),
    new Paragraph({
      spacing: { before: 60, after: 220 },
      alignment: AlignmentType.CENTER,
      children: [
        new TextRun({ text: `Figure ${figNo}. `, bold: true, color: MUTED, size: 18 }),
        new TextRun({ text: caption, italics: true, color: MUTED, size: 18 }),
      ],
    }),
  ];
}

// ── feature data (single source for both the summary table and the sections) ──
const features = [
  {
    title: "Authentication & Account",
    module: "Login / Auth",
    what: "Email + password and Google sign-in, registration, and password reset.",
    why: "Every user needs a private, persistent account so their profile, logs, and history are theirs alone and sync across sessions.",
    how: "Firebase Authentication wrapped by AuthService (FirebaseAuth + google_sign_in). LoginViewModel (Provider/ChangeNotifier) handles form validation and maps Firebase error codes to friendly, non-revealing messages. A root WidgetTree listens to authStateChanges and routes to Login, Onboarding, or Home.",
    priority: "Critical",
    justify: "Gates the entire app; nothing else is reachable without it.",
    caption: "Login / register screen with Google sign-in.",
  },
  {
    title: "Onboarding & Macro Targets",
    module: "Onboarding",
    what: "Collects body stats + goal and computes daily calorie and macro targets.",
    why: "Every downstream feature (dashboard, meal plan, analytics) needs personalised calorie/protein/carb/fat targets to be meaningful.",
    how: "A 3-step flow (SetupProfileView → SelectGoalView → MacroCalculatorView). MacroCalculatorViewModel computes BMR via Mifflin–St Jeor, applies an activity multiplier for TDEE, adjusts for the goal (cut −500 / bulk +300), enforces a safe-calorie floor, and splits macros by the chosen ratio. Saved to the user profile in Firestore.",
    priority: "Critical",
    justify: "Without targets the core tracking and planning features have no reference point.",
    caption: "Goal selection and calculated macro targets.",
  },
  {
    title: "Home Dashboard",
    module: "Home",
    what: "At-a-glance daily view: calorie ring, macro cards, steps, water, and insights.",
    why: "Users need one screen that answers 'how am I doing today?' and acts as the hub to every other feature.",
    how: "HomeViewModel subscribes to a real-time Firestore stream of today's daily_log totals and recomputes progress live. Hosts the step counter, water quick-add, an insight banner, quick-log buttons, and the bottom navigation.",
    priority: "Critical",
    justify: "The primary landing screen and navigation hub for the whole app.",
    caption: "Home dashboard with calorie ring and macro cards.",
  },
  {
    title: "Daily Log (data backbone)",
    module: "Data layer",
    what: "Per-day record of consumed macros, steps, and water.",
    why: "A single source of truth for 'today' that the dashboard, notifications, and analytics all read from.",
    how: "DailyLogService writes to users/{uid}/daily_logs/{yyyy-MM-dd} using Firestore atomic increments (FieldValue.increment) so concurrent meal/water logs never clobber each other, plus a real-time snapshot stream for the dashboard.",
    priority: "Critical",
    justify: "Underpins nutrition tracking, contextual notifications, and analytics trends.",
    caption: "Daily totals updating live as a meal is logged.",
  },
  {
    title: "AI Meal Scanning",
    module: "Nutrition",
    what: "Snap or pick a food photo and get an instant macro estimate.",
    why: "Manual macro entry is tedious and error-prone; a photo lowers the friction of logging food.",
    how: "image_picker captures/compresses the image; GeminiService sends it to Google Gemini (gemini-3.1-flash-lite) with a strict JSON response schema and returns clamped, sanitised macros. A client-side RateLimiter caps calls to protect API quota/cost; results are editable before saving.",
    priority: "Important",
    justify: "A flagship convenience feature, but the app still works via manual entry without it.",
    caption: "Meal photo analysed into editable macro fields.",
  },
  {
    title: "Meal History",
    module: "Nutrition",
    what: "Browsable list of logged meals, grouped by day, with re-log and delete.",
    why: "Users want to review what they ate and quickly re-add recurring meals.",
    how: "MealHistoryService stores entries under users/{uid}/meal_history and, on save, also increments the daily log. The view groups entries into Today / Yesterday / dated sections.",
    priority: "Important",
    justify: "Completes the nutrition loop and feeds the meal planner's 'avoid repeats' input.",
    caption: "Meal history grouped by date.",
  },
  {
    title: "Weekly Meal Plan (AI)",
    module: "Meal Plan",
    what: "AI-generated 7-day Malaysian meal plan matched to the user's macros.",
    why: "Deciding what to eat that fits your targets is hard; an automatic, localised plan removes that burden.",
    how: "GeminiMealPlanService asks Gemini (structured JSON) for rice/staple-based, budget-friendly meals with a per-meal MYR price and a cuisine preference (Mixed or strict Malay/Chinese/Indian/Thai/Western). Inputs are mirrored to on-device DataStore so a Workmanager background job can regenerate weekly and pre-schedule offline meal-time notifications, even with no network.",
    priority: "Important",
    justify: "A strong differentiator with offline support, but not required for core tracking.",
    caption: "Weekly plan with per-meal prices and cuisine chips.",
  },
  {
    title: "Workout Tracking",
    module: "Gym",
    what: "Log a live workout: exercises, sets, reps/weight, rest timer, and PRs.",
    why: "Lifters need to record sets and see last time's numbers to progressively overload.",
    how: "ActiveWorkoutViewModel manages the session, pre-fills each set from previous performance, runs a rest timer, detects personal records (max weight, Epley 1RM, set volume), and auto-saves an in-progress session to local storage so it can be resumed. Finished workouts persist to users/{uid}/workouts.",
    priority: "Important",
    justify: "The core of the fitness half of the app; central to many users' routine.",
    caption: "Active workout with set rows, rest timer, and PR badges.",
  },
  {
    title: "Workout Recommendations",
    module: "Gym",
    what: "Suggests the next session based on goal and training frequency.",
    why: "Beginners don't know how to structure a split; a recommendation gives them a sensible starting point.",
    how: "RecommendationService maps goal + days/week to a training split (full-body / upper-lower / push-pull-legs), rotates through it using workout history for basic recovery awareness, and applies a goal-driven set/rep scheme from a curated preset library.",
    priority: "Nice-to-have",
    justify: "Helpful guidance, but users can build workouts manually without it.",
    caption: "Recommended routine card with days-per-week selector.",
  },
  {
    title: "Exercise Library",
    module: "Gym",
    what: "Searchable list of built-in exercises plus user-created custom ones.",
    why: "Logging needs a consistent catalogue of exercises (with the right input type per movement).",
    how: "ExerciseLibraryService merges a built-in preset list with custom exercises from users/{uid}/custom_exercises. Each exercise declares a type (weight×reps, reps-only, duration, distance+duration…) that drives which fields the logger shows.",
    priority: "Important",
    justify: "Required for workout logging to function; supports the whole Gym module.",
    caption: "Exercise picker with muscle-group filters.",
  },
  {
    title: "Analytics & Insights",
    module: "Analytics",
    what: "Trends and summaries across nutrition, workouts, and body weight.",
    why: "Progress is invisible day-to-day; charts over weeks/months show whether the user is actually improving.",
    how: "AnalyticsService performs date-bounded Firestore reads, buckets data into calendar-aligned ranges (week / month / quarter), and returns an immutable summary. AnalyticsViewModel caches one summary per range. Charts (calorie/protein trends, macro donut, volume, estimated-1RM, muscle radar, consistency heatmap) are rendered with fl_chart; unlogged days are treated as gaps, not zeros.",
    priority: "Important",
    justify: "Major value-add for retention and motivation, though not needed for daily logging.",
    caption: "Analytics tabs with trend charts and a consistency heatmap.",
  },
  {
    title: "Body Weight Tracking",
    module: "Profile",
    what: "Log body weight over time and view the trend.",
    why: "Weight change is the clearest signal of whether a cut/bulk is working.",
    how: "WeightService stores one entry per day under users/{uid}/weight_logs and keeps the profile's current weight in sync. The Profile hub plots the trend with a shared line-chart widget.",
    priority: "Nice-to-have",
    justify: "Valuable for goal tracking but secondary to nutrition and workout logging.",
    caption: "Body-weight trend chart in the Profile hub.",
  },
  {
    title: "Profile Hub",
    module: "Profile",
    what: "Account summary, daily targets, goal reassignment, and sign-out.",
    why: "Users need a place to review their stats, change goals, and manage their session.",
    how: "ProfileHubView reads the profile and weight history, links into the goal/macro flow for reassignment (updating targets without overwriting the rest of the profile), and exposes a test-notification action and sign-out.",
    priority: "Important",
    justify: "Central account management and the only path to change goals or sign out.",
    caption: "Profile hub with stats, targets, and weight card.",
  },
  {
    title: "Fitness Radar — Gym Finder",
    module: "Fitness Radar",
    what: "Map of nearby gyms with filters and directions.",
    why: "Users (often travelling or new to an area) want to find a place to train near them.",
    how: "google_maps_flutter renders the map; geolocator gets the user's fix; the Places API (New) searchNearby endpoint is called over REST with a tight field mask to keep billing low. Results are cached on-device (DataStore, 30-min TTL) and filtered in-memory by open-now / radius / type. Directions open via url_launcher.",
    priority: "Nice-to-have",
    justify: "A useful companion feature; the core fitness/nutrition loop works without it.",
    caption: "Gym map with filter chips and a results sheet.",
  },
  {
    title: "Fitness Radar — Coach Directory",
    module: "Fitness Radar",
    what: "Browse and register personal trainers; contact them directly.",
    why: "Connects users who want guidance with local coaches, and lets trainers list themselves.",
    how: "CoachService reads/writes a top-level coaches collection (one doc per trainer, keyed by uid; write access locked to the owner via Firestore rules). The directory filters by specialization in-memory; 'Inquire' opens WhatsApp, the dialer, or email via url_launcher.",
    priority: "Nice-to-have",
    justify: "Extends the app into a marketplace, but is peripheral to personal tracking.",
    caption: "Coach directory cards with specialization filters.",
  },
  {
    title: "Notifications",
    module: "Engagement",
    what: "Contextual nudges, scheduled reminders, and offline meal alerts.",
    why: "Timely prompts (low protein, skipped meal, hydration, planned meals) drive the daily habit the app depends on.",
    how: "NotificationManager evaluates today's totals to fire data-driven alerts (calorie surplus, low protein, goal achieved, skipped meal, hydration), de-duped to once per day. NotificationService wraps flutter_local_notifications with timezone-aware scheduling for daily reminders and pre-baked offline meal-plan notifications.",
    priority: "Nice-to-have",
    justify: "Boosts engagement and retention, but the app is fully usable with them off.",
    caption: "Example contextual notification in the system tray.",
  },
  {
    title: "Step Counting",
    module: "Activity",
    what: "Counts steps taken today using the device's hardware sensor.",
    why: "Daily steps are a low-effort activity signal users expect from a fitness app.",
    how: "The pedometer plugin reads the cumulative hardware step counter; HomeViewModel reconciles it into 'steps today' using persisted baselines/offsets so the count survives the app being killed and device reboots. Totals are throttled-persisted to the daily log for analytics.",
    priority: "Nice-to-have",
    justify: "A pleasant passive metric, not central to the app's core value.",
    caption: "Steps ring on the home dashboard.",
  },
  {
    title: "Water Tracking",
    module: "Activity",
    what: "Quick-add water intake toward a daily hydration goal.",
    why: "Hydration is a simple, motivating habit users like to track alongside nutrition.",
    how: "A bottom-sheet quick-add (+250 ml / +500 ml / +1 L) increments the daily log via DailyLogService; the dashboard shows progress and NotificationManager sends data-driven hydration nudges when the user falls behind.",
    priority: "Nice-to-have",
    justify: "Lightweight engagement feature, easily lived without.",
    caption: "Water quick-add sheet and progress ring.",
  },
];

// ── tech stack rows ──
const techStack = [
  ["Language & framework", "Dart, Flutter (Android-first)"],
  ["State management", "Provider with ChangeNotifier view-models (MVVM)"],
  ["Auth", "Firebase Authentication (email/password + Google Sign-In)"],
  ["Database", "Cloud Firestore (per-user documents + security rules)"],
  ["AI", "Google Gemini (google_generative_ai, gemini-3.1-flash-lite) with structured JSON output"],
  ["Maps & places", "google_maps_flutter (Maps SDK) + Places API (New) over REST (http)"],
  ["Location", "geolocator"],
  ["Background work", "Workmanager (weekly meal-plan job)"],
  ["Notifications", "flutter_local_notifications, timezone, flutter_timezone"],
  ["Local storage / cache", "shared_preferences (SharedPreferencesAsync, backed by Jetpack DataStore)"],
  ["Sensors", "pedometer + permission_handler"],
  ["Charts", "fl_chart"],
  ["Other", "image_picker, url_launcher, intl, form_validator"],
];

// ── build summary table ──
function summaryTable() {
  const headerCell = (t, w) => new TableCell({
    borders: allBorders, width: { size: w, type: WidthType.DXA },
    shading: { fill: BRAND, type: ShadingType.CLEAR },
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    verticalAlign: VerticalAlign.CENTER,
    children: [new Paragraph({ children: [new TextRun({ text: t, bold: true, color: "FFFFFF" })] })],
  });
  const rows = [
    new TableRow({ tableHeader: true, children: [
      headerCell("Feature", 4060), headerCell("Module", 3100), headerCell("Importance", 2200),
    ] }),
  ];
  for (const f of features) {
    rows.push(new TableRow({ children: [
      new TableCell({ borders: allBorders, width: { size: 4060, type: WidthType.DXA },
        margins: { top: 60, bottom: 60, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: f.title, color: INK })] })] }),
      new TableCell({ borders: allBorders, width: { size: 3100, type: WidthType.DXA },
        margins: { top: 60, bottom: 60, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: f.module, color: MUTED })] })] }),
      new TableCell({ borders: allBorders, width: { size: 2200, type: WidthType.DXA },
        shading: { fill: TAGFILL[f.priority], type: ShadingType.CLEAR },
        margins: { top: 60, bottom: 60, left: 120, right: 120 },
        children: [new Paragraph({ children: [new TextRun({ text: f.priority, bold: true, color: INK })] })] }),
    ] }));
  }
  return new Table({ width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [4060, 3100, 2200], rows });
}

// ── tech stack table ──
function techTable() {
  const rows = techStack.map(([k, v]) => new TableRow({ children: [
    new TableCell({ borders: allBorders, width: { size: 3000, type: WidthType.DXA },
      shading: { fill: "F1F5F9", type: ShadingType.CLEAR },
      margins: { top: 60, bottom: 60, left: 120, right: 120 },
      children: [new Paragraph({ children: [new TextRun({ text: k, bold: true, color: INK })] })] }),
    new TableCell({ borders: allBorders, width: { size: 6360, type: WidthType.DXA },
      margins: { top: 60, bottom: 60, left: 120, right: 120 },
      children: [new Paragraph({ children: [new TextRun({ text: v, color: INK })] })] }),
  ] }));
  return new Table({ width: { size: CONTENT_W, type: WidthType.DXA },
    columnWidths: [3000, 6360], rows });
}

// ── assemble document body ──
const body = [];

// Title
body.push(new Paragraph({ spacing: { after: 60 }, children: [
  new TextRun({ text: "NutriFit", bold: true, size: 56, color: BRAND }),
] }));
body.push(new Paragraph({ spacing: { after: 40 }, children: [
  new TextRun({ text: "Technical Documentation", bold: true, size: 32, color: INK }),
] }));
body.push(new Paragraph({ spacing: { after: 240 }, children: [
  new TextRun({ text: "Fitness & nutrition companion app — feature reference", italics: true, color: MUTED }),
] }));

// Overview
body.push(h1("1. App Overview"));
body.push(p("NutriFit is a mobile fitness and nutrition companion built with Flutter. It helps everyday users hit their body-composition goals (cut, maintain, or bulk) by combining four pillars in one app: AI-assisted food logging, an automatically generated weekly meal plan, full workout tracking, and progress analytics. It is tailored for a Malaysian audience — the meal planner uses local cuisines (nasi lemak, economy rice, mamak, etc.) and prices meals in Malaysian Ringgit."));
body.push(p("The target user is a health-conscious individual — from beginners who want guidance (recommended routines, auto meal plans) to experienced lifters who want detailed set-by-set logging and personal-record tracking. A secondary audience is personal trainers, who can list themselves in the in-app coach directory. The app is account-based, with each user's profile, logs, and history stored privately in the cloud and synced across sessions."));

// Tech stack
body.push(h1("2. Tech Stack"));
body.push(p("The app follows an MVVM structure: thin views, ChangeNotifier view-models for state, and dedicated service classes for all I/O (Firestore, AI, maps, notifications)."));
body.push(techTable());
body.push(new Paragraph({ spacing: { after: 120 }, children: [new TextRun("")] }));

// Summary table
body.push(h1("3. Feature Summary"));
body.push(p("Importance tags: Critical (app cannot function without it), Important (core value, app degrades noticeably without it), Nice-to-have (enhances the experience), Cosmetic (purely visual polish)."));
body.push(summaryTable());
body.push(new Paragraph({ children: [new PageBreak()] }));

// Feature detail
body.push(h1("4. Features"));
let fig = 1;
for (const f of features) {
  body.push(h2(`${f.title}  —  [${f.module}]`));
  body.push(labeled("What it does", f.what));
  body.push(labeled("Why it exists", f.why));
  body.push(labeled("How it's implemented", f.how));
  body.push(new Paragraph({ spacing: { after: 100 }, children: [
    new TextRun({ text: "Priority: ", bold: true, color: BRAND }),
    new TextRun({ text: f.priority, bold: true, color: INK }),
    new TextRun({ text: ` — ${f.justify}`, color: INK }),
  ] }));
  shot(f.caption, fig++).forEach((x) => body.push(x));
}

// Appendix note
body.push(h1("5. Notes"));
body.push(bullet("Screenshots are placeholders — drop a captured image into each box and keep the figure caption."));
body.push(bullet("Data model: per-user documents live under users/{uid} (daily_logs, meal_history, workouts, weight_logs, custom_exercises); coaches is a shared top-level collection. Access is enforced by Firestore security rules."));
body.push(bullet("API keys (Gemini, Google Maps) are injected at build time via --dart-define-from-file=env.json and Android local.properties — never committed to source."));

// ── document with styles ──
const doc = new Document({
  styles: {
    default: { document: { run: { font: "Arial", size: 22, color: INK } } },
    paragraphStyles: [
      { id: "Heading1", name: "Heading 1", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 30, bold: true, color: BRAND, font: "Arial" },
        paragraph: { spacing: { before: 280, after: 160 }, outlineLevel: 0 } },
      { id: "Heading2", name: "Heading 2", basedOn: "Normal", next: "Normal", quickFormat: true,
        run: { size: 25, bold: true, color: INK, font: "Arial" },
        paragraph: { spacing: { before: 220, after: 100 }, outlineLevel: 1 } },
    ],
  },
  numbering: {
    config: [
      { reference: "bullets", levels: [
        { level: 0, format: LevelFormat.BULLET, text: "•", alignment: AlignmentType.LEFT,
          style: { paragraph: { indent: { left: 720, hanging: 360 } } } },
      ] },
    ],
  },
  sections: [{
    properties: { page: {
      size: { width: 12240, height: 15840 },
      margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 },
    } },
    children: body,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  fs.writeFileSync("NutriFit_Technical_Documentation.docx", buf);
  console.log("wrote NutriFit_Technical_Documentation.docx (" + buf.length + " bytes)");
});
