import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scripturedepth/main.dart';
import 'package:scripturedepth/core/network/api_client.dart';
import 'package:scripturedepth/core/network/supabase_service.dart';
import 'package:scripturedepth/features/home/memorization_review_screen.dart';
import 'package:scripturedepth/features/reader/widgets/word_occurrences_sheet.dart';
import 'package:scripturedepth/features/reader/widgets/verse_connections_sheet.dart';
import 'package:scripturedepth/features/reader/widgets/word_study_sheet.dart';
import 'package:scripturedepth/core/models/scripture_models.dart';
import 'package:scripturedepth/features/profile/profile_screen.dart';
import 'package:scripturedepth/features/reader/reader_screen.dart';
import 'package:scripturedepth/core/services/app_settings_service.dart';
import 'package:scripturedepth/core/services/audio_bible_service.dart';
import 'package:scripturedepth/core/services/reading_plan_service.dart';
import 'package:scripturedepth/core/services/study_journal_service.dart';
import 'package:scripturedepth/core/services/reader_navigation_service.dart';
import 'package:scripturedepth/features/study/widgets/reading_plan_detail_sheet.dart';
import 'package:scripturedepth/features/study/widgets/reading_plan_picker_sheet.dart';
import 'package:scripturedepth/features/study/widgets/study_journal_sheet.dart';
import 'package:scripturedepth/features/reader/widgets/audio_player_bar.dart';
import 'package:scripturedepth/core/services/audio_cache_service.dart';
import 'package:scripturedepth/core/theme/app_theme.dart';
import 'package:scripturedepth/features/onboarding/onboarding_screen.dart';
import 'package:scripturedepth/core/services/ambient_soundscape_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppSettingsService().setDefaultTranslation('kjv', 'KJV');
  });

  testWidgets('ScriptureDepth app smoke test and navigation tabs', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
      initialThemeMode: ThemeMode.dark,
    ));
    await tester.pumpAndSettle();

    // Verify Home tab elements
    expect(find.text('Continue your study'), findsOneWidget);
    expect(find.text('The Gospel of John'), findsOneWidget);
    expect(find.text('Word of the day'), findsOneWidget);

    // Navigate to Read tab
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Default book is Genesis 1 with KJV translation switcher
    expect(find.text('Genesis 1'), findsOneWidget);
    expect(find.text('KJV'), findsOneWidget);
    expect(find.text('The Creation of Heaven and Earth'), findsOneWidget);

    // Navigate to Search tab
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('Search scripture'), findsOneWidget);
    expect(find.text('Old testament'), findsOneWidget);
    expect(find.text('New testament'), findsOneWidget);

    // Navigate to Study Hub tab (replacing Maps)
    await tester.tap(find.byIcon(Icons.auto_stories_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Study hub'), findsOneWidget);
    expect(find.text('Scripture memorization'), findsOneWidget);
    expect(find.text('Strong’s lookup'), findsOneWidget);

    // Navigate to Profile tab
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    expect(find.text('Your Profile'), findsOneWidget);
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.text('Reading as a guest'), findsOneWidget);
  });

  testWidgets('BookChapterPickerSheet allows selecting another book and chapter', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Go to Read tab
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Tap Book/Chapter header
    await tester.tap(find.text('Genesis 1'));
    await tester.pumpAndSettle();

    // Verify Picker bottom sheet is open
    expect(find.text('Select Scripture'), findsOneWidget);
    expect(find.text('New Testament'), findsOneWidget);

    // Switch to New Testament tab to access Romans
    await tester.tap(find.text('New Testament'));
    await tester.pumpAndSettle();

    expect(find.text('Romans'), findsOneWidget);

    // Tap 'Romans'
    await tester.tap(find.text('Romans'));
    await tester.pumpAndSettle();

    // Verify Chapter grid for Romans (1 to 16)
    expect(find.text('Select Chapter (1 - 16)'), findsOneWidget);
    expect(find.text('8'), findsOneWidget); // Romans 8

    // Tap chapter 8
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();

    // Verify reader updated to Romans 8
    expect(find.text('Romans 8'), findsOneWidget);
  });

  testWidgets('Translation switcher opens and switches translation to ASV', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Go to Read tab
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Tap KJV translation pill
    await tester.tap(find.text('KJV'));
    await tester.pumpAndSettle();

    // Verify translation selector modal is open with newly added modern translations
    expect(find.text('Select Translation'), findsOneWidget);
    expect(find.text('Amplified Bible'), findsOneWidget);

    // Tap Amplified Bible
    await tester.tap(find.text('Amplified Bible'));
    await tester.pumpAndSettle();

    // Verify translation pill updated to AMP
    expect(find.text('AMP'), findsOneWidget);
  });

  testWidgets('VerseActionSheet opens with color swatches and saves a study note', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Go to Read tab
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Tap verse plain text to open VerseActionSheet (gold words open WordStudySheet)
    await tester.tap(find.text('the heaven and the earth.'));
    await tester.pumpAndSettle();

    // Verify action sheet opened with sleek buttons including Links (cross-references)
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
    expect(find.text('Copy'), findsOneWidget);
    expect(find.text('Listen'), findsOneWidget);
    expect(find.text('Links'), findsOneWidget);

    // Tap 'Note'
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();

    // Enter note text
    await tester.enterText(find.byType(TextField), 'Foundational verse of all Scripture.');
    await tester.pumpAndSettle();

    // Tap 'Save Note'
    await tester.tap(find.text('Save Note'));
    await tester.pumpAndSettle();

    // Verify note is rendered in the reader
    expect(find.text('Foundational verse of all Scripture.'), findsOneWidget);
  });

  testWidgets('VerseConnectionsSheet displays connected cross references with jump action', (WidgetTester tester) async {
    bool jumped = false;
    const connections = [
      CrossReferenceModel(
        toBookCode: 'JHN',
        toBookName: 'John',
        toChapter: 1,
        toVerse: 1,
        refType: 'Creation by the Word',
        verseText: 'In the beginning was the Word, and the Word was with God, and the Word was God.',
      ),
      CrossReferenceModel(
        toBookCode: 'COL',
        toBookName: 'Colossians',
        toChapter: 1,
        toVerse: 16,
        refType: 'All Things Created in Him',
        verseText: 'For by him were all things created, that are in heaven, and that are in earth.',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VerseConnectionsSheet(
          sourceBookName: 'Genesis',
          sourceChapter: 1,
          sourceVerse: 1,
          sourceVerseText: 'In the beginning God created the heaven and the earth.',
          connections: connections,
          onNavigateToPassage: (book, ch, v) {
            jumped = true;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Scripture Connections'), findsOneWidget);
    expect(find.text('John 1:1'), findsOneWidget);
    expect(find.text('Creation by the Word'), findsOneWidget);
    expect(find.text('Colossians 1:16'), findsOneWidget);

    // Tap 'Jump to Passage'
    await tester.tap(find.text('Jump to Passage').first);
    await tester.pumpAndSettle();

    expect(jumped, isTrue);
  });

  testWidgets('WordOccurrencesSheet displays occurrences and navigates to verse', (WidgetTester tester) async {
    bool selected = false;
    const entry = LexiconEntryModel(
      strongsNumber: 'H430',
      language: 'hebrew',
      lemma: 'אֱלֹהִים',
      transliteration: "ʾĕlōhîm",
      shortDefinition: 'God, Supreme Divinity, Creator of Heaven and Earth.',
      source: 'strongs',
      occurrencesCount: 2606,
    );
    const occurrences = [
      WordOccurrenceModel(
        bookCode: 'GEN',
        chapter: 1,
        verse: 1,
        surfaceForm: 'אֱלֹהִים',
        verseText: 'In the beginning God created the heaven and the earth.',
      ),
      WordOccurrenceModel(
        bookCode: 'PSA',
        chapter: 46,
        verse: 1,
        surfaceForm: 'אֱלֹהִים',
        verseText: 'God is our refuge and strength, a very present help in trouble.',
      ),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WordOccurrencesSheet(
          entry: entry,
          occurrences: occurrences,
          onSelectOccurrence: (occ) {
            selected = true;
          },
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('אֱלֹהִים'), findsAtLeastNWidgets(1));
    expect(find.textContaining('2606 occurrences in Scripture'), findsOneWidget);
    expect(find.text('GEN 1:1'), findsOneWidget);
    expect(find.text('PSA 46:1'), findsOneWidget);

    // Tap first occurrence
    await tester.tap(find.text('GEN 1:1'));
    await tester.pumpAndSettle();

    expect(selected, isTrue);
  });

  testWidgets('MemorizationReviewScreen displays interactive swipe deck, flips card and submits review', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: MemorizationReviewScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Verify front of card and header
    expect(find.text('Verse Memorization'), findsOneWidget);
    expect(find.text('SCRIPTURE MEMORY'), findsOneWidget);
    expect(find.text('John 3:16'), findsOneWidget);
    expect(find.text('Tap card to reveal verse'), findsOneWidget);

    // Verify bottom control bar
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.text('Know It'), findsOneWidget);

    // Tap Flip button
    await tester.tap(find.text('Flip'));
    await tester.pumpAndSettle();

    // Should reveal full verse text on the back
    expect(find.textContaining('For God so loved the world'), findsOneWidget);

    // Tap 'Know It' (swipe right review)
    await tester.tap(find.text('Know It'));
    await tester.pumpAndSettle();

    // Card should advance to Card 2 (Ephesians 2:8)
    expect(find.text('Ephesians 2:8'), findsOneWidget);
  });

  testWidgets('AuthModal opens from Profile tab and signs in user', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Profile tab
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    // Tap 'Sign in' button
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();

    // Verify AuthModal opened
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // Enter credentials
    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'scholar@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'password123');
    await tester.pumpAndSettle();

    // Tap Sign In action in modal
    await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In').last);
    await tester.pumpAndSettle();

    // Should now show signed in user email
    expect(find.text('scholar@example.com'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
  });

  testWidgets('Chapter navigation chevrons and bottom card advance and return chapters', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Read tab
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    expect(find.text('Genesis 1'), findsOneWidget);

    // Tap the Next chapter chevron (Icons.chevron_right)
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();

    // Reader should now display Genesis 2
    expect(find.text('Genesis 2'), findsOneWidget);

    // Tap the Previous chapter chevron (Icons.chevron_left)
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();

    // Reader should be back at Genesis 1
    expect(find.text('Genesis 1'), findsOneWidget);
  });

  testWidgets('Reader header renders without any overflow on narrow screen sizes', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    // Set an ultra-narrow viewport (320x568, iPhone SE 1st gen)
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Read tab
    await tester.tap(find.text('Read'));
    await tester.pumpAndSettle();

    expect(find.text('Genesis 1'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.text('KJV'), findsOneWidget);
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('HomeScreen renders premium layout matching reference design', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Verify greeting and headline: guests do NOT have hardcoded 'Nelson'
    expect(find.textContaining('Nelson'), findsNothing);
    expect(find.text('Continue your study'), findsOneWidget);

    // Sign in and verify user display name is reflected in greeting
    await supabase.signInWithPassword(email: 'nelson@scripturedepth.com', password: 'password123');
    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Nelson'), findsOneWidget);

    // Sign out to return to guest mode
    await supabase.signOut();

    // Verify Reading Plan card elements
    expect(find.textContaining('Reading plan · day'), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);
    expect(find.text('The Gospel of John'), findsOneWidget);
    expect(find.textContaining('I am the vine; you are the branches'), findsOneWidget);
    expect(find.textContaining('next up'), findsOneWidget);
    expect(find.text('Continue →'), findsOneWidget);

    // Verify 3 stacked quick actions
    expect(find.text('6 verses due for review'), findsOneWidget);
    expect(find.text('Scripture connections and roots'), findsOneWidget);
    expect(find.textContaining('streak'), findsOneWidget);

    // Verify Word of the Day & Verse of the Day
    expect(find.text('Word of the day'), findsOneWidget);
    expect(find.text('ἀγάπη'), findsOneWidget);
    expect(find.text('Study'), findsAtLeastNWidgets(1));
    expect(find.text('Verse of the day'), findsOneWidget);
    expect(find.text('John 3:16 · ESV'), findsOneWidget);
  });

  testWidgets('WordStudySheet displays scholarly definition, derivation, and outline without empty dot', (WidgetTester tester) async {
    const word = OriginalWord(
      wordPosition: 1,
      surfaceForm: 'ζωή',
      lemma: 'ζωή',
      transliteration: 'zōē',
      strongsNumber: 'G2222',
      language: 'greek',
      englishGloss: 'life',
    );
    const entry = LexiconEntryModel(
      strongsNumber: 'G2222',
      language: 'greek',
      lemma: 'ζωή',
      transliteration: 'zōē',
      shortDefinition: 'life (literally or figuratively)',
      source: 'strongs',
      occurrencesCount: 134,
      derivation: 'from G2198 (ζάω);',
      outlineUsage: 'life, the state of one who is possessed of vitality or is animate',
      kjvDefinition: 'life(-time)',
    );
    const detail = LexiconDetailModel(
      entry: entry,
      occurrences: [
        WordOccurrenceModel(
          bookCode: 'JHN',
          chapter: 1,
          verse: 4,
          surfaceForm: 'ζωή',
          verseText: 'In him was life; and the life was the light of men.',
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: WordStudySheet(
          word: word,
          detail: detail,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Strong’s Definition'), findsOneWidget);
    expect(find.text('life (literally or figuratively)'), findsOneWidget);
    expect(find.text('Root & Derivation'), findsOneWidget);
    expect(find.text('from G2198 (ζάω);'), findsOneWidget);
    expect(find.text('Outline of Biblical Usage'), findsOneWidget);
    expect(find.text('KJV Translation: life(-time)'), findsOneWidget);
    expect(find.text('See all 134 recurrences'), findsOneWidget);
    expect(find.text('ζωή'), findsAtLeastNWidgets(1));
    expect(find.text('Also appears in'), findsOneWidget);
    expect(find.text('John 1:4'), findsOneWidget);
  });

  testWidgets('Memorization card swipe gesture triggers review and reveals next card in stack', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: MemorizationReviewScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    expect(find.text('John 3:16'), findsOneWidget);

    // Perform horizontal drag to the right to trigger Remembered swipe
    await tester.drag(find.text('John 3:16'), const Offset(250.0, 0.0));
    await tester.pumpAndSettle();

    // The top card should have swiped off, revealing Ephesians 2:8
    expect(find.text('Ephesians 2:8'), findsOneWidget);
  });

  testWidgets('Share button opens ShareVerseSheet with quote preview and copy button', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: MemorizationReviewScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Tap Share action in bottom control bar
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Share Scripture'), findsOneWidget);
    expect(find.text('Copy Quote'), findsOneWidget);
    expect(find.text('WhatsApp / Social'), findsOneWidget);

    // Tap Copy Quote
    await tester.tap(find.text('Copy Quote'));
    await tester.pumpAndSettle();

    // Sheet should close and snackbar should be displayed
    expect(find.text('Verse copied to clipboard for sharing!'), findsOneWidget);
  });

  testWidgets('Tapping streak row opens StreakSheet with weekly completion calendar', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Ensure streak row is scrolled into view and tap it
    await tester.ensureVisible(find.textContaining('streak'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('streak'));
    await tester.pumpAndSettle();

    // Verify StreakSheet opened
    expect(find.textContaining('Study Streak'), findsOneWidget);
    expect(find.text('Longest Streak'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
  });

  testWidgets('MemorizationReviewScreen renders cleanly without overflow on narrow screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: MemorizationReviewScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Verse Memorization'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);
    expect(find.text('Flip'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.text('Know It'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen renders dynamic guest mode, live stats, and preferences', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        supabaseService: supabase,
        apiClient: client,
      ),
    ));
    await tester.pumpAndSettle();

    // Verify Guest Mode header
    expect(find.text('Your Profile'), findsOneWidget);
    expect(find.text('Reading as a guest'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);

    // Verify dynamic stats
    expect(find.text('Current streak'), findsOneWidget);
    expect(find.text('Verses memorized'), findsOneWidget);

    // Verify preference rows
    expect(find.text('Reading preferences'), findsOneWidget);
    expect(find.text('Default translation'), findsOneWidget);
    expect(find.text('Reading font'), findsOneWidget);
    expect(find.text('Text size'), findsOneWidget);
    expect(find.text('Audio narration'), findsOneWidget);
    expect(find.text('Offline downloads'), findsOneWidget);
  });

  testWidgets('ProfileScreen opens translation sheet and changes default translation', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        supabaseService: supabase,
        apiClient: client,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap Default Translation row
    await tester.tap(find.text('Default translation'));
    await tester.pumpAndSettle();

    // Verify sheet opened with translations
    expect(find.text('12 translations downloaded & offline ready'), findsOneWidget);
    expect(find.text('Amplified Bible'), findsOneWidget);
    expect(find.text('English Standard Version'), findsOneWidget);

    // Select Amplified Bible
    await tester.tap(find.text('Amplified Bible'));
    await tester.pumpAndSettle();

    // Verify preference updated
    expect(AppSettingsService().defaultTranslationId, equals('amp'));
    expect(AppSettingsService().defaultTranslationAbbr, equals('AMP'));
  });

  testWidgets('ProfileScreen opens typography sheet and updates reader font size', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        supabaseService: supabase,
        apiClient: client,
      ),
    ));
    await tester.pumpAndSettle();

    // Tap Text Size row
    await tester.ensureVisible(find.text('Text size'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Text size'));
    await tester.pumpAndSettle();

    // Verify Typography sheet opened with live preview
    expect(find.text('Typography & Font Size'), findsOneWidget);
    expect(find.text('LIVE SCRIPTURE PREVIEW'), findsOneWidget);
    expect(find.text('Georgia'), findsWidgets);

    // Tap X-Large preset button (23 pt)
    await tester.tap(find.text('X-Large'));
    await tester.pumpAndSettle();

    // Verify font size updated
    expect(AppSettingsService().readerFontSize, equals(23.0));

    // Scroll to and tap Palatino font
    await tester.ensureVisible(find.text('Palatino'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Palatino'));
    await tester.pumpAndSettle();

    // Verify font family updated
    expect(AppSettingsService().readerFontFamily, equals('Palatino'));
  });

  testWidgets('ProfileScreen opens audio voice and offline downloads sheets', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(MaterialApp(
      home: ProfileScreen(
        themeMode: ThemeMode.light,
        onThemeModeChanged: (_) {},
        supabaseService: supabase,
        apiClient: client,
      ),
    ));
    await tester.pumpAndSettle();

    // 1. Open Audio Narration Sheet
    await tester.ensureVisible(find.text('Audio narration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Audio narration'));
    await tester.pumpAndSettle();

    expect(find.text('Audio Voice & Narration'), findsOneWidget);
    expect(find.text('Natural Reverent (US)'), findsWidgets);
    expect(find.text('British Scholarly (UK)'), findsOneWidget);
    expect(find.text('Test Voice Sample'), findsOneWidget);

    // Select British Scholarly
    await tester.tap(find.text('British Scholarly (UK)'));
    await tester.pumpAndSettle();
    expect(AppSettingsService().audioVoice, equals('British Scholarly (UK)'));

    // Close sheet
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 2. Open Offline Downloads Sheet
    await tester.ensureVisible(find.text('Offline downloads'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offline downloads'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Downloads'), findsWidgets);
    expect(find.text('12 of 12 Translations Downloaded'), findsOneWidget);
    expect(find.text('Verify Local Database Integrity'), findsOneWidget);

    // Tap Verify
    await tester.tap(find.text('Verify Local Database Integrity'));
    await tester.pumpAndSettle();
    expect(find.textContaining('All 12 translations verified'), findsOneWidget);
  });

  testWidgets('ReaderScreen toggles Parallel View and displays comparative translation cards', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: ReaderScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Verify initially in single flowing reader
    expect(find.text('Genesis 1'), findsWidgets);
    expect(find.byIcon(Icons.vertical_split_outlined), findsOneWidget);

    // Tap Parallel comparison toggle
    await tester.tap(find.byIcon(Icons.vertical_split_outlined));
    await tester.pumpAndSettle();

    // Verify Parallel view active with comparison bar and comparative verse cards
    expect(find.byIcon(Icons.vertical_split_rounded), findsOneWidget);
    expect(find.byIcon(Icons.compare_arrows_rounded), findsOneWidget);
    expect(find.text('Verse 1'), findsOneWidget);
    expect(find.text('AMP'), findsWidgets);

    // Tap the exchange swap icon (Icons.compare_arrows_rounded)
    await tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await tester.pumpAndSettle();

    // Verify translations swapped vice versa: Amplified Bible is now primary, KJV is secondary
    expect(find.text('Amplified Bible'), findsWidgets);
    expect(find.text('KJV'), findsWidgets);

    // Tap swap icon again to switch back
    await tester.tap(find.byIcon(Icons.compare_arrows_rounded));
    await tester.pumpAndSettle();

    expect(find.text('AMP'), findsWidgets);
    expect(find.text('King James Version'), findsWidgets);
  });

  testWidgets('ReaderScreen highlights active verse and updates layout during audio playback', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: ReaderScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Emit active audio verse 1
    AudioBibleService().currentVerseNumber.value = 1;
    await tester.pumpAndSettle();

    // Verify "Reading aloud" indicator is illuminated for verse 1
    expect(find.text('Reading aloud'), findsOneWidget);

    // Reset audio verse
    AudioBibleService().currentVerseNumber.value = null;
    await tester.pumpAndSettle();
    expect(find.text('Reading aloud'), findsNothing);
  });

  testWidgets('ShareVerseSheet switches between visual card themes', (WidgetTester tester) async {
    final client = ApiClient();
    await tester.pumpWidget(MaterialApp(
      home: MemorizationReviewScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Tap Share
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();

    expect(find.text('Aura Gradient'), findsOneWidget);
    expect(find.text('Cathedral Noir'), findsOneWidget);
    expect(find.text('Minimalist Paper'), findsOneWidget);
    expect(find.text('Living Water'), findsOneWidget);

    // Switch to Cathedral Noir theme
    await tester.tap(find.text('Cathedral Noir'));
    await tester.pumpAndSettle();

    // Tap WhatsApp / Social export
    await tester.tap(find.text('WhatsApp / Social'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Visual Quote Card generated'), findsOneWidget);
  });

  testWidgets('ReadingPlanDetailSheet displays checklist, toggles day completion, and shows milestone badges', (WidgetTester tester) async {
    await ReadingPlanService().initialize();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ReadingPlanDetailSheet(),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify header details
    expect(find.text('The Gospel of John'), findsOneWidget);
    expect(find.textContaining('Day checklist'), findsOneWidget);
    expect(find.textContaining('Milestone badges'), findsOneWidget);

    expect(find.text('Switch plan'), findsOneWidget);
    expect(find.textContaining('Gospels'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('The Eternal Word & Incarnation'), findsOneWidget);
    expect(find.text('John 1:1-18'), findsOneWidget);
    expect(find.text('Read >'), findsAtLeastNWidgets(1));

    // Switch to Milestone Badges tab
    await tester.tap(find.textContaining('Milestone badges'));
    await tester.pumpAndSettle();

    // Verify badges
    expect(find.text('Light of the World'), findsOneWidget);
    expect(find.text('True Vine Scholar'), findsOneWidget);
  });

  testWidgets('ReadingPlanPickerSheet displays 4 curated journeys and switches active plan', (WidgetTester tester) async {
    await ReadingPlanService().initialize();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: ReadingPlanPickerSheet(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Curated Reading Journeys'), findsOneWidget);
    expect(find.text('The Gospel of John'), findsOneWidget);
    expect(find.text("Paul's Prison Epistles"), findsOneWidget);

    // Tap Paul's Prison Epistles
    await tester.tap(find.text("Paul's Prison Epistles"));
    await tester.pumpAndSettle();

    expect(ReadingPlanService().activePlanId, 'paul_prison_epistles_14d');
  });

  testWidgets('StudyJournalSheet filters entries by theological theme and exports Markdown', (WidgetTester tester) async {
    await StudyJournalService().initialize();

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: StudyJournalSheet(),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify journal header
    expect(find.text('Theological Study Journal'), findsOneWidget);
    expect(find.text('Export MD'), findsOneWidget);

    // Verify filter pills
    expect(find.textContaining('All'), findsOneWidget);
    expect(find.text('Promises'), findsOneWidget);
    expect(find.text('Living'), findsOneWidget);
    expect(find.text('Comfort'), findsOneWidget);
    expect(find.text('Prophecy'), findsOneWidget);
    expect(find.text('Doctrine'), findsOneWidget);

    // Verify pre-seeded entries are visible
    expect(find.textContaining('John 15:5'), findsOneWidget);

    // Tap Comfort filter
    await tester.tap(find.text('Comfort'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Romans 8:28'), findsOneWidget);
    expect(find.textContaining('John 15:5'), findsNothing);

    // Tap Export MD
    await tester.tap(find.text('Export MD'));
    await tester.pumpAndSettle();

    expect(find.textContaining('exported as Markdown'), findsOneWidget);
  });

  testWidgets('StudyHubScreen renders Reading Plans and Study Journal studio cards', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Study tab
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Study'),
    ));
    await tester.pumpAndSettle();

    // Verify editorial components are rendered
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.text('Study journal'), findsOneWidget);
    expect(find.text('Open journal'), findsOneWidget);
    expect(find.text('Scripture memorization'), findsOneWidget);
    expect(find.text('Practice'), findsOneWidget);

    // Open Study Journal
    await tester.tap(find.text('Open journal'));
    await tester.pumpAndSettle();

    expect(find.text('Theological Study Journal'), findsOneWidget);
  });

  testWidgets('ReadingPlanDetailSheet Read button navigates to chapter in ReaderScreen', (WidgetTester tester) async {
    await ReadingPlanService().setActivePlan('gospel_of_john_30d');
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Study tab
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Study'),
    ));
    await tester.pumpAndSettle();

    // Open Reading Plan
    await tester.tap(find.text('Continue reading'));
    await tester.pumpAndSettle();

    // Tap 'Read' button on Day 1 (John 1) inside the sheet
    await tester.tap(find.descendant(
      of: find.byType(ReadingPlanDetailSheet),
      matching: find.textContaining('Read'),
    ).first);
    await tester.pumpAndSettle();

    expect(ReaderNavigationService().navigationRequest.value?.bookCode, 'JHN');
    expect(find.text('John 1'), findsOneWidget);
  });

  testWidgets('StudyHubScreen filters original roots by language and provides concordance quick chips', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Navigate to Study tab
    await tester.tap(find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text('Study'),
    ));
    await tester.pumpAndSettle();

    // Scroll down to reveal language filters
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -400));
    await tester.pumpAndSettle();

    // Verify language filter chips exist
    expect(find.text('All roots (10)'), findsOneWidget);
    expect(find.text('Hebrew · OT (5)'), findsOneWidget);
    expect(find.text('Greek · NT (5)'), findsOneWidget);

    // Filter by Greek
    await tester.tap(find.text('Greek · NT (5)'));
    await tester.pumpAndSettle();

    expect(find.text('Logos / The Living Word'), findsOneWidget);
    expect(find.text('Yahweh / The LORD'), findsNothing);

    // Filter by Hebrew
    await tester.tap(find.text('Hebrew · OT (5)'));
    await tester.pumpAndSettle();

    expect(find.text('Yahweh / The LORD'), findsOneWidget);
    expect(find.text('Logos / The Living Word'), findsNothing);

    // Scroll back up to verify quick Strong's suggestion chips
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, 400));
    await tester.pumpAndSettle();

    expect(find.text('H430 (God)'), findsOneWidget);
    expect(find.text('G26 (Love)'), findsOneWidget);
  });

  testWidgets('AudioPlayerBar renders editorial controls, skips verses, updates speed and closes cleanly', (WidgetTester tester) async {
    final audioService = AudioBibleService();
    bool closed = false;

    final testVerses = [
      VerseModel(verse: 1, text: 'In the beginning God created the heaven and the earth.'),
      VerseModel(verse: 2, text: 'And the earth was without form, and void.'),
      VerseModel(verse: 3, text: 'And God said, Let there be light: and there was light.'),
    ];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AudioPlayerBar(onClose: () => closed = true),
      ),
    ));

    // Initially when stopped, player bar is hidden (SizedBox.shrink)
    expect(find.text('Genesis 1:1'), findsNothing);

    // Play chapter from verse 1
    await audioService.playChapter(testVerses, startVerseIndex: 0, bookName: 'Genesis', chapter: 1);
    await tester.pumpAndSettle();

    // Verify Genesis 1:1 displayed cleanly
    expect(find.text('Genesis 1:1'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tap pause
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    expect(audioService.isPlaying.value, isFalse);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);

    // Tap next verse (should skip to Genesis 1:2)
    await tester.tap(find.byIcon(Icons.skip_next_rounded));
    await tester.pumpAndSettle();
    expect(audioService.currentVerseNumber.value, equals(2));
    expect(find.text('Genesis 1:2'), findsOneWidget);

    // Tap previous verse (should return to Genesis 1:1)
    await tester.tap(find.byIcon(Icons.skip_previous_rounded));
    await tester.pumpAndSettle();
    expect(audioService.currentVerseNumber.value, equals(1));
    expect(find.text('Genesis 1:1'), findsOneWidget);

    // Change speed
    await tester.tap(find.text('1×'));
    await tester.pumpAndSettle();
    expect(find.text('1.25× Faster'), findsOneWidget);
    await tester.tap(find.text('1.25× Faster'));
    await tester.pumpAndSettle();
    expect(audioService.playbackSpeed.value, equals(1.25));

    // Tap close
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(audioService.isPlaying.value, isFalse);
    expect(audioService.currentVerseNumber.value, isNull);
  });

  testWidgets('AudioPlayerBar renders without overflow on narrow screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 2, 600 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final audioService = AudioBibleService();
    audioService.currentVerseNumber.value = 2;
    audioService.currentReference.value = 'Genesis 1:2';
    audioService.isPlaying.value = true;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AudioPlayerBar(onClose: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Genesis 1:2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('AudioCacheService correctly manages local chapter storage', () async {
    final cache = AudioCacheService();
    // Initially not cached
    final initialStatus = await cache.isChapterCached('kjv', 'GEN', 1);
    expect(initialStatus, isFalse);

    // Save dummy MP3 data (2048 bytes > 1024 threshold)
    final dummyBytes = List<int>.generate(2048, (i) => i % 256);
    final saved = await cache.saveAudioBytes(
      translationId: 'kjv',
      bookCode: 'GEN',
      chapter: 1,
      bytes: dummyBytes,
    );
    expect(saved, isTrue);

    // Should now report cached
    final isCached = await cache.isChapterCached('kjv', 'GEN', 1);
    expect(isCached, isTrue);

    final count = await cache.getCachedChaptersCount();
    expect(count, greaterThanOrEqualTo(1));

    final sizeMB = await cache.getCacheSizeMB();
    expect(sizeMB, greaterThan(0.0));

    // Clear cache
    await cache.clearCache();
    final afterClear = await cache.isChapterCached('kjv', 'GEN', 1);
    expect(afterClear, isFalse);
  });

  testWidgets('AudioPlayerBar displays fidelity status and 1-tap cache button', (WidgetTester tester) async {
    final audioService = AudioBibleService();
    audioService.currentVerseNumber.value = 1;
    audioService.currentReference.value = 'Genesis 1:1';
    audioService.fidelityLabel.value = 'Alexander Scourby · Human Studio';
    audioService.isCachedOffline.value = false;
    audioService.isPlaying.value = true;

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AudioPlayerBar(onClose: () {}),
      ),
    ));
    await tester.pumpAndSettle();

    // Verify title and download button present
    expect(find.text('Genesis 1:1'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_circle_down_outlined), findsOneWidget);

    // Toggle cached state
    audioService.isCachedOffline.value = true;
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.download_done_rounded), findsOneWidget);
  });

  testWidgets('OnboardingScreen displays 4 interactive slides and finishes onboarding', (WidgetTester tester) async {
    bool completed = false;
    AppSettingsService().setCompletedOnboarding(false);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: OnboardingScreen(
        onComplete: () => completed = true,
      ),
    ));
    await tester.pumpAndSettle();

    // Slide 1: A translation, and a voice to read it in.
    expect(find.text('A translation,\nand a voice to\nread it in.'), findsOneWidget);
    expect(find.textContaining('Every passage is narrated by a human reader'), findsOneWidget);
    expect(find.textContaining('In the beginning God created the heaven and the earth.'), findsOneWidget);

    // Tap Continue -> Slide 2
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Slide 2: Words you can hear as well as read.
    expect(find.text('Words you can\nhear as well as\nread.'), findsOneWidget);
    expect(find.text('Genesis 1, King James Version'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

    // Tap play button inside audio card
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tap Continue -> Slide 3
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    // Slide 3: Choose the translation you'll live in.
    expect(find.text("Choose the\ntranslation you'll\nlive in."), findsOneWidget);
    expect(find.text('KJV'), findsOneWidget);
    expect(find.text('ESV'), findsOneWidget);
    expect(find.text('NIV'), findsOneWidget);

    // Tap KJV pill to switch translation preview
    await tester.tap(find.text('KJV'));
    await tester.pumpAndSettle();
    expect(find.text('King James Version'), findsOneWidget);

    // Tap Get started -> Slide 4
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    // Slide 4: Same voice, quieter room. (Dark Mode Sanctuary Showcase)
    expect(find.text('Same voice,\nquieter room.'), findsOneWidget);
    expect(find.text('Reading — Genesis 1'), findsOneWidget);
    expect(find.textContaining('Night reading dims the page'), findsOneWidget);

    // Tap Get started to complete onboarding
    await tester.tap(find.text('Get started'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(AppSettingsService().hasCompletedOnboarding, isTrue);
    expect(AppSettingsService().selectedTranslation, equals('KJV'));
  });

  testWidgets('ReaderScreen toggles Zen Mode and manuscript mode', (WidgetTester tester) async {
    final client = ApiClient();

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: ReaderScreen(apiClient: client),
    ));
    await tester.pumpAndSettle();

    // Find and tap Zen Mode focus icon in header
    expect(find.byIcon(Icons.filter_center_focus_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.filter_center_focus_outlined));
    await tester.pumpAndSettle();

    // Verify Focus Mode banner is visible
    expect(find.textContaining('FOCUS READING'), findsOneWidget);
    expect(find.text('Exit Focus'), findsOneWidget);

    // Exit Zen Mode
    await tester.tap(find.text('Exit Focus'));
    await tester.pumpAndSettle();
    expect(find.textContaining('FOCUS READING'), findsNothing);

    // Test Manuscript Mode sync with audio playback
    AudioBibleService().isManuscriptMode.value = true;
    AudioBibleService().currentVerseNumber.value = 1;
    await tester.pumpAndSettle();

    expect(find.text('Manuscript Reading Sync'), findsOneWidget);

    // Clean up
    AudioBibleService().isManuscriptMode.value = false;
    AudioBibleService().currentVerseNumber.value = null;
  });

  test('AmbientSoundscapeService manages soundscapes and volumes', () {
    final service = AmbientSoundscapeService();

    service.setSoundscape('rain');
    expect(service.currentSoundscapeId, equals('rain'));
    expect(service.activeSoundscapeInfo.title, equals('Monastery Rain'));

    service.setVolume(0.75);
    expect(service.ambientVolume, closeTo(0.75, 0.01));

    service.setSoundscape('none');
    expect(service.currentSoundscapeId, equals('none'));
  });

  testWidgets('HomeScreen renders Word of the Day spoken pronunciation action', (WidgetTester tester) async {
    final client = ApiClient();
    final supabase = SupabaseService(apiClient: client);

    await tester.pumpWidget(ScriptureDepthApp(
      apiClient: client,
      supabaseService: supabase,
    ));
    await tester.pumpAndSettle();

    // Verify Word of the day and Greek lemma
    expect(find.text('Word of the day'), findsOneWidget);
    expect(find.text('ἀγάπη'), findsOneWidget);

    // Verify ancient pronunciation speaker button is present and tappable
    expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.volume_up_outlined), warnIfMissed: false);
    await tester.pumpAndSettle();
  });
}


