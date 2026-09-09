import '../models/scripture_models.dart';

class VerseToken {
  final String text;
  final OriginalWord? word;
  final bool isInteractive;

  const VerseToken({
    required this.text,
    this.word,
    this.isInteractive = false,
  });
}

class VerseWordParser {
  /// Core theological roots mapped to Strong's Concordance for Old Testament (Hebrew)
  static final Map<String, OriginalWord> hebrewKeywords = {
    'lord': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'יְהֹוָה',
      lemma: 'יְהֹוָה',
      transliteration: "Yᵊhōvâ",
      strongsNumber: 'H3068',
      language: 'hebrew',
      englishGloss: 'LORD / Jehovah',
      morphDescription: 'Proper Name of Deity, The Self-Existent Eternal One',
    ),
    'god': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'אֱלֹהִים',
      lemma: 'אֱלֹהִים',
      transliteration: "ʾĕlōhîm",
      strongsNumber: 'H430',
      language: 'hebrew',
      englishGloss: 'God / Supreme Divinity',
      morphDescription: 'Noun, Plural of Majesty, Creator of Heaven and Earth',
    ),
    'created': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'בָּרָא',
      lemma: 'בָּרָא',
      transliteration: "bārāʾ",
      strongsNumber: 'H1254',
      language: 'hebrew',
      englishGloss: 'created ex nihilo',
      morphDescription: 'Verb, Qal Perfect (exclusively divine creation)',
    ),
    'beginning': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'רֵאשִׁית',
      lemma: 'רֵאשִׁית',
      transliteration: "rēʾšît",
      strongsNumber: 'H7225',
      language: 'hebrew',
      englishGloss: 'in the beginning / firstfruit',
      morphDescription: 'Noun, Primeval Beginning, Chief part',
    ),
    'spirit': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'רוּחַ',
      lemma: 'רוּחַ',
      transliteration: "rûaḥ",
      strongsNumber: 'H7307',
      language: 'hebrew',
      englishGloss: 'Spirit / breath / wind',
      morphDescription: 'Noun, The Holy Spirit of God',
    ),
    'light': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'אוֹר',
      lemma: 'אוֹר',
      transliteration: "ʾôr",
      strongsNumber: 'H216',
      language: 'hebrew',
      englishGloss: 'light / illumination',
      morphDescription: 'Noun, Radiant daylight and spiritual illumination',
    ),
    'heaven': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'שָׁמַיִם',
      lemma: 'שָׁמַיִם',
      transliteration: "šāmayim",
      strongsNumber: 'H8064',
      language: 'hebrew',
      englishGloss: 'heavens / sky',
      morphDescription: 'Noun Dual, The celestial expanse and abode of God',
    ),
    'heavens': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'שָׁמַיִם',
      lemma: 'שָׁמַיִם',
      transliteration: "šāmayim",
      strongsNumber: 'H8064',
      language: 'hebrew',
      englishGloss: 'heavens / sky',
      morphDescription: 'Noun Dual, The celestial expanse and abode of God',
    ),
    'earth': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'אֶרֶץ',
      lemma: 'אֶרֶץ',
      transliteration: "ʾereṣ",
      strongsNumber: 'H776',
      language: 'hebrew',
      englishGloss: 'earth / land',
      morphDescription: 'Noun, The terrestrial sphere',
    ),
    'covenant': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'בְּרִית',
      lemma: 'בְּרִית',
      transliteration: "bərît",
      strongsNumber: 'H1285',
      language: 'hebrew',
      englishGloss: 'covenant / alliance',
      morphDescription: 'Noun, Divine binding treaty',
    ),
    'holy': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'קָדוֹשׁ',
      lemma: 'קָדוֹשׁ',
      transliteration: "qādôš",
      strongsNumber: 'H6918',
      language: 'hebrew',
      englishGloss: 'holy / sacred / set apart',
      morphDescription: 'Adjective, Sacred and morally pure',
    ),
    'peace': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'שָׁלוֹם',
      lemma: 'שָׁלוֹם',
      transliteration: "šālôm",
      strongsNumber: 'H7965',
      language: 'hebrew',
      englishGloss: 'peace / wholeness / shalom',
      morphDescription: 'Noun, Completeness, tranquility, welfare',
    ),
    'mercy': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'חֶסֶד',
      lemma: 'חֶסֶד',
      transliteration: "ḥesed",
      strongsNumber: 'H2617',
      language: 'hebrew',
      englishGloss: 'steadfast covenant love / mercy',
      morphDescription: 'Noun, Unfailing loyal kindness',
    ),
    'righteousness': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'צְדָקָה',
      lemma: 'צְדָקָה',
      transliteration: "ṣədāqāh",
      strongsNumber: 'H6666',
      language: 'hebrew',
      englishGloss: 'righteousness / justice',
      morphDescription: 'Noun, Ethical uprightness and equity',
    ),
    'blessed': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'בָּרַךְ',
      lemma: 'בָּרַךְ',
      transliteration: "bārak",
      strongsNumber: 'H1288',
      language: 'hebrew',
      englishGloss: 'bless / knelt before',
      morphDescription: 'Verb, Imparting divine favor',
    ),
    'heart': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'לֵב',
      lemma: 'לֵב',
      transliteration: "lēb",
      strongsNumber: 'H3820',
      language: 'hebrew',
      englishGloss: 'heart / inner soul / mind',
      morphDescription: 'Noun, Center of inner life and will',
    ),
  };

  /// Core theological roots mapped to Strong's Concordance for New Testament (Greek)
  static final Map<String, OriginalWord> greekKeywords = {
    'lord': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'κύριος',
      lemma: 'κύριος',
      transliteration: "kýrios",
      strongsNumber: 'G2962',
      language: 'greek',
      englishGloss: 'Lord / Sovereign Ruler',
      morphDescription: 'Noun, Master, Ruler, Divine title for Jesus Christ',
    ),
    'god': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'θεός',
      lemma: 'θεός',
      transliteration: "theós",
      strongsNumber: 'G2316',
      language: 'greek',
      englishGloss: 'God / Supreme Divinity',
      morphDescription: 'Noun, The one true God and Creator',
    ),
    'jesus': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'Ἰησοῦς',
      lemma: 'Ἰησοῦς',
      transliteration: "Iēsoûs",
      strongsNumber: 'G2424',
      language: 'greek',
      englishGloss: 'Jesus / Savior',
      morphDescription: 'Proper Name, Yahweh is Salvation',
    ),
    'christ': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'Χριστός',
      lemma: 'Χριστός',
      transliteration: "Christós",
      strongsNumber: 'G5547',
      language: 'greek',
      englishGloss: 'Christ / Anointed One',
      morphDescription: 'Noun, The Promised Messiah',
    ),
    'word': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'λόγος',
      lemma: 'λόγος',
      transliteration: "lógos",
      strongsNumber: 'G3056',
      language: 'greek',
      englishGloss: 'Word / Divine Expression',
      morphDescription: 'Noun, The Incarnate Revelation of God',
    ),
    'loved': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'ἠγάπησεν',
      lemma: 'ἀγαπάω',
      transliteration: "agapáō",
      strongsNumber: 'G25',
      language: 'greek',
      englishGloss: 'loved sacrificially',
      morphDescription: 'Verb, Unconditional divine love',
    ),
    'love': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'ἀγάπη',
      lemma: 'ἀγάπη',
      transliteration: "agápē",
      strongsNumber: 'G26',
      language: 'greek',
      englishGloss: 'love / charity',
      morphDescription: 'Noun, Benevolent sacrificial love',
    ),
    'life': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'ζωή',
      lemma: 'ζωή',
      transliteration: "zōḗ",
      strongsNumber: 'G2222',
      language: 'greek',
      englishGloss: 'life / divine vitality',
      morphDescription: 'Noun, Eternal spiritual life in God',
    ),
    'faith': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'πίστις',
      lemma: 'πίστις',
      transliteration: "pístis",
      strongsNumber: 'G4102',
      language: 'greek',
      englishGloss: 'faith / conviction / trust',
      morphDescription: 'Noun, Firm persuasion in God\'s promise',
    ),
    'grace': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'χάρις',
      lemma: 'χάρις',
      transliteration: "cháris",
      strongsNumber: 'G5485',
      language: 'greek',
      englishGloss: 'grace / unmerited favor',
      morphDescription: 'Noun, Free divine benevolence',
    ),
    'truth': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'ἀλήθεια',
      lemma: 'ἀλήθεια',
      transliteration: "alḗtheia",
      strongsNumber: 'G225',
      language: 'greek',
      englishGloss: 'truth / reality',
      morphDescription: 'Noun, Objective biblical reality',
    ),
    'spirit': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'πνεῦμα',
      lemma: 'πνεῦμα',
      transliteration: "pneûma",
      strongsNumber: 'G4151',
      language: 'greek',
      englishGloss: 'Spirit / Holy Spirit',
      morphDescription: 'Noun, The Holy Spirit of God',
    ),
    'peace': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'εἰρήνη',
      lemma: 'εἰρήνη',
      transliteration: "eirḗnē",
      strongsNumber: 'G1515',
      language: 'greek',
      englishGloss: 'peace / reconciliation',
      morphDescription: 'Noun, Harmony and peace of heart',
    ),
    'holy': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'ἅγιος',
      lemma: 'ἅγιος',
      transliteration: "hágios",
      strongsNumber: 'G40',
      language: 'greek',
      englishGloss: 'holy / sanctified',
      morphDescription: 'Adjective, Consecrated and pure',
    ),
    'righteousness': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'δικαιοσύνη',
      lemma: 'δικαιοσύνη',
      transliteration: "dikaiosýnē",
      strongsNumber: 'G1343',
      language: 'greek',
      englishGloss: 'righteousness / justification',
      morphDescription: 'Noun, State of being acceptable to God',
    ),
    'son': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'υἱός',
      lemma: 'υἱός',
      transliteration: "huiós",
      strongsNumber: 'G5207',
      language: 'greek',
      englishGloss: 'Son / beloved heir',
      morphDescription: 'Noun, The Only Begotten Son of God',
    ),
    'world': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'κόσμος',
      lemma: 'κόσμος',
      transliteration: "kósmos",
      strongsNumber: 'G2889',
      language: 'greek',
      englishGloss: 'world / mankind',
      morphDescription: 'Noun, The created world order',
    ),
    'salvation': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'σωτηρία',
      lemma: 'σωτηρία',
      transliteration: "sōtēría",
      strongsNumber: 'G4991',
      language: 'greek',
      englishGloss: 'salvation / deliverance',
      morphDescription: 'Noun, Deliverance from sin into eternal life',
    ),
    'gospel': const OriginalWord(
      wordPosition: 0,
      surfaceForm: 'εὐαγγέλιον',
      lemma: 'εὐαγγέλιον',
      transliteration: "euangélion",
      strongsNumber: 'G2098',
      language: 'greek',
      englishGloss: 'good news / gospel',
      morphDescription: 'Noun, Glad tidings of the Kingdom of God',
    ),
  };

  /// Parses any verse text into tokens. Words matching theological roots or
  /// with attached Strong's numbers become interactive.
  static List<VerseToken> parseVerse(
    String verseText,
    String bookCode,
    List<OriginalWord> serverOriginalWords,
  ) {
    final isNT = _isNewTestament(bookCode);
    final keywordMap = isNT ? greekKeywords : hebrewKeywords;

    // First check if verse has server original words
    final Map<String, OriginalWord> wordLookup = {};
    for (final ow in serverOriginalWords) {
      if (ow.englishGloss != null && ow.englishGloss!.isNotEmpty) {
        wordLookup[ow.englishGloss!.toLowerCase()] = ow;
      }
    }

    // Split text into words and punctuation
    final words = verseText.split(' ');
    final List<VerseToken> tokens = [];

    for (int i = 0; i < words.length; i++) {
      final rawWord = words[i];
      if (rawWord.isEmpty) continue;

      // Clean punctuation for dictionary matching
      final cleanKey = rawWord.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();

      // Check server words first, then keywords dictionary
      OriginalWord? matchedWord = wordLookup[cleanKey] ?? keywordMap[cleanKey];

      // Handle common plurals / variations
      if (matchedWord == null && cleanKey.endsWith('s') && cleanKey.length > 3) {
        final singular = cleanKey.substring(0, cleanKey.length - 1);
        matchedWord = keywordMap[singular];
      } else if (matchedWord == null && cleanKey.endsWith('ed') && cleanKey.length > 4) {
        final base = cleanKey.substring(0, cleanKey.length - 2);
        matchedWord = keywordMap[base];
      }

      final isInteractive = matchedWord != null;
      tokens.add(VerseToken(
        text: rawWord,
        word: matchedWord,
        isInteractive: isInteractive,
      ));
    }

    return tokens;
  }

  static bool _isNewTestament(String bookCode) {
    const ntCodes = {
      'MAT', 'MRK', 'LUK', 'JHN', 'ACT', 'ROM', '1CO', '2CO', 'GAL',
      'EPH', 'PHP', 'COL', '1TH', '2TH', '1TI', '2TI', 'TIT', 'PHM',
      'HEB', 'JAS', '1PE', '2PE', '1JN', '2JN', '3JN', 'JUD', 'REV',
    };
    return ntCodes.contains(bookCode.toUpperCase());
  }
}
