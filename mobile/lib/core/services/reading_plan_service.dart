import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'streak_service.dart';

class ReadingPlanDay {
  final int dayNumber;
  final String title;
  final String bookCode;
  final String bookName;
  final int chapter;
  final String verseSpan;
  final String versePreview;
  final String reflection;
  final bool isCompleted;

  const ReadingPlanDay({
    required this.dayNumber,
    required this.title,
    required this.bookCode,
    required this.bookName,
    required this.chapter,
    required this.verseSpan,
    required this.versePreview,
    required this.reflection,
    this.isCompleted = false,
  });

  ReadingPlanDay copyWith({bool? isCompleted}) {
    return ReadingPlanDay(
      dayNumber: dayNumber,
      title: title,
      bookCode: bookCode,
      bookName: bookName,
      chapter: chapter,
      verseSpan: verseSpan,
      versePreview: versePreview,
      reflection: reflection,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}

class ReadingPlanBadge {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final int dayRequirement;
  final bool isUnlocked;

  const ReadingPlanBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.dayRequirement,
    this.isUnlocked = false,
  });

  ReadingPlanBadge copyWith({bool? isUnlocked}) {
    return ReadingPlanBadge(
      id: id,
      name: name,
      description: description,
      icon: icon,
      dayRequirement: dayRequirement,
      isUnlocked: isUnlocked ?? this.isUnlocked,
    );
  }
}

class ReadingPlanDetail {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int durationDays;
  final List<Color> gradientColors;
  final List<ReadingPlanDay> days;
  final List<ReadingPlanBadge> badges;
  final bool isEnrolled;

  const ReadingPlanDetail({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationDays,
    required this.gradientColors,
    required this.days,
    required this.badges,
    this.isEnrolled = false,
  });

  int get daysCompleted => days.where((d) => d.isCompleted).length;
  double get progressPercent => durationDays == 0 ? 0.0 : (daysCompleted / durationDays).clamp(0.0, 1.0);
  int get unlockedBadgeCount => badges.where((b) => b.isUnlocked).length;

  ReadingPlanDay? get currentReadingDay {
    for (final day in days) {
      if (!day.isCompleted) return day;
    }
    return days.isNotEmpty ? days.last : null;
  }
}

class ReadingPlanService {
  static final ReadingPlanService _instance = ReadingPlanService._internal();
  factory ReadingPlanService() => _instance;
  ReadingPlanService._internal();

  static const String _keyActivePlanId = 'reading_plan_active_id';
  static const String _keyCompletedDaysPrefix = 'reading_plan_completed_days_';

  String _activePlanId = 'gospel_of_john_30d';
  final Map<String, Set<int>> _completedDays = {};

  final ValueNotifier<ReadingPlanDetail?> activePlanNotifier =
      ValueNotifier<ReadingPlanDetail?>(null);

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activePlanId = prefs.getString(_keyActivePlanId) ?? 'gospel_of_john_30d';

      for (final plan in _rawPlans) {
        final key = '$_keyCompletedDaysPrefix${plan.id}';
        final savedList = prefs.getStringList(key);
        if (savedList != null) {
          _completedDays[plan.id] = savedList.map((e) => int.tryParse(e) ?? 0).where((e) => e > 0).toSet();
        } else if (plan.id == 'gospel_of_john_30d') {
          // Pre-seed first 12 days for John's Gospel to show initial realistic progress (40%)
          _completedDays[plan.id] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12};
        } else {
          _completedDays[plan.id] = {};
        }
      }

      _notifyActivePlan();
    } catch (_) {
      _notifyActivePlan();
    }
  }

  void _notifyActivePlan() {
    activePlanNotifier.value = getPlanById(_activePlanId);
  }

  String get activePlanId => _activePlanId;

  Future<void> setActivePlan(String planId) async {
    _activePlanId = planId;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActivePlanId, planId);
    } catch (_) {}
    _notifyActivePlan();
  }

  List<ReadingPlanDetail> getAllPlans() {
    return _rawPlans.map((raw) => _buildDetail(raw)).toList();
  }

  ReadingPlanDetail? getPlanById(String planId) {
    final raw = _rawPlans.firstWhere(
      (p) => p.id == planId,
      orElse: () => _rawPlans.first,
    );
    return _buildDetail(raw);
  }

  Future<bool> toggleDayCompleted(String planId, int dayNumber) async {
    final set = _completedDays.putIfAbsent(planId, () => {});
    final wasCompleted = set.contains(dayNumber);

    if (wasCompleted) {
      set.remove(dayNumber);
    } else {
      set.add(dayNumber);
      // Award study activity streak
      StreakService().recordActivity(chaptersRead: 1);
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        '$_keyCompletedDaysPrefix$planId',
        set.map((e) => e.toString()).toList(),
      );
    } catch (_) {}

    _notifyActivePlan();
    return !wasCompleted;
  }

  ReadingPlanDetail _buildDetail(_RawPlan raw) {
    final completed = _completedDays[raw.id] ?? {};
    final days = raw.days.map((d) {
      final isDone = completed.contains(d.dayNumber);
      return d.copyWith(isCompleted: isDone);
    }).toList();

    final completedCount = days.where((d) => d.isCompleted).length;
    final badges = raw.badges.map((b) {
      final isUnlocked = completedCount >= b.dayRequirement;
      return b.copyWith(isUnlocked: isUnlocked);
    }).toList();

    return ReadingPlanDetail(
      id: raw.id,
      title: raw.title,
      subtitle: raw.subtitle,
      category: raw.category,
      durationDays: raw.durationDays,
      gradientColors: raw.gradientColors,
      days: days,
      badges: badges,
      isEnrolled: raw.id == _activePlanId,
    );
  }

  // --- Curated Plans Catalog ---
  static final List<_RawPlan> _rawPlans = [
    _RawPlan(
      id: 'gospel_of_john_30d',
      title: 'The Gospel of John',
      subtitle: 'The Living Word & Divine Signs',
      category: 'Gospels & Christology',
      durationDays: 30,
      gradientColors: const [Color(0xFF0F172A), Color(0xFF0F766E)],
      badges: const [
        ReadingPlanBadge(
          id: 'john_badge_1',
          name: 'Light of the World',
          description: 'Completed 7 days in the early ministry of Jesus',
          icon: Icons.light_mode_rounded,
          dayRequirement: 7,
        ),
        ReadingPlanBadge(
          id: 'john_badge_2',
          name: 'True Vine Scholar',
          description: 'Completed 15 days studying the Seven "I Am" claims',
          icon: Icons.eco_rounded,
          dayRequirement: 15,
        ),
        ReadingPlanBadge(
          id: 'john_badge_3',
          name: 'Resurrection Witness',
          description: 'Completed 25 days up through the Passion & Resurrection',
          icon: Icons.flare_rounded,
          dayRequirement: 25,
        ),
        ReadingPlanBadge(
          id: 'john_badge_4',
          name: 'Faithful Finisher',
          description: 'Finished all 30 days of the Gospel of John journey',
          icon: Icons.military_tech_rounded,
          dayRequirement: 30,
        ),
      ],
      days: [
        const ReadingPlanDay(
          dayNumber: 1,
          title: 'The Eternal Word & Incarnation',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 1,
          verseSpan: 'John 1:1-18',
          versePreview: 'In the beginning was the Word, and the Word was with God, and the Word was God.',
          reflection: 'Contemplate how the eternal Logos stepped into history to reveal the Father with grace and truth.',
        ),
        const ReadingPlanDay(
          dayNumber: 2,
          title: 'Behold the Lamb of God',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 1,
          verseSpan: 'John 1:19-34',
          versePreview: 'Behold the Lamb of God, which taketh away the sin of the world.',
          reflection: 'John the Baptist points away from himself to herald the sacrificial Redeemer.',
        ),
        const ReadingPlanDay(
          dayNumber: 3,
          title: 'The First Disciples Follow',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 1,
          verseSpan: 'John 1:35-51',
          versePreview: 'Philip saith unto him, Come and see.',
          reflection: 'Notice how personal invitations lead others straight to genuine fellowship with Jesus.',
        ),
        const ReadingPlanDay(
          dayNumber: 4,
          title: 'The First Sign at Cana',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 2,
          verseSpan: 'John 2:1-12',
          versePreview: 'This beginning of miracles did Jesus in Cana of Galilee, and manifested forth his glory.',
          reflection: 'Jesus brings transformation and divine abundance into ordinary human moments.',
        ),
        const ReadingPlanDay(
          dayNumber: 5,
          title: 'Zeal for the Father\'s House',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 2,
          verseSpan: 'John 2:13-25',
          versePreview: 'Destroy this temple, and in three days I will raise it up.',
          reflection: 'Christ purifies worship and points forward to the temple of His risen body.',
        ),
        const ReadingPlanDay(
          dayNumber: 6,
          title: 'Born of Water and Spirit',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 3,
          verseSpan: 'John 3:1-15',
          versePreview: 'Except a man be born again, he cannot see the kingdom of God.',
          reflection: 'Nicodemus hears the radical necessity of spiritual regeneration by the Holy Spirit.',
        ),
        const ReadingPlanDay(
          dayNumber: 7,
          title: 'God\'s Love for the World',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 3,
          verseSpan: 'John 3:16-36',
          versePreview: 'For God so loved the world, that he gave his only begotten Son.',
          reflection: 'The pinnacle of divine love: self-giving sacrifice offering everlasting life to all who believe.',
        ),
        const ReadingPlanDay(
          dayNumber: 8,
          title: 'Living Water at the Well',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 4,
          verseSpan: 'John 4:1-26',
          versePreview: 'The water that I shall give him shall be in him a well of water springing up into everlasting life.',
          reflection: 'Jesus crosses cultural divides in Samaria to quench deep spiritual thirst.',
        ),
        const ReadingPlanDay(
          dayNumber: 9,
          title: 'Harvest Fields & The Nobleman\'s Son',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 4,
          verseSpan: 'John 4:27-54',
          versePreview: 'Lift up your eyes, and look on the fields; for they are white already to harvest.',
          reflection: 'Faith takes Jesus at His bare word, trusting His command across distance.',
        ),
        const ReadingPlanDay(
          dayNumber: 10,
          title: 'Healing at the Pool of Bethesda',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 5,
          verseSpan: 'John 5:1-18',
          versePreview: 'Rise, take up thy bed, and walk.',
          reflection: 'Christ’s sovereign mercy intervenes where decades of human inability had settled.',
        ),
        const ReadingPlanDay(
          dayNumber: 11,
          title: 'The Authority of the Son',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 5,
          verseSpan: 'John 5:19-47',
          versePreview: 'He that heareth my word, and believeth on him that sent me, hath everlasting life.',
          reflection: 'The Son does nothing of Himself, but whatever the Father does, in perfect divine unity.',
        ),
        const ReadingPlanDay(
          dayNumber: 12,
          title: 'Feeding the Multitude',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 6,
          verseSpan: 'John 6:1-21',
          versePreview: 'It is I; be not afraid.',
          reflection: 'Christ multiplies five loaves and walks atop turbulent waves to comfort His disciples.',
        ),
        const ReadingPlanDay(
          dayNumber: 13,
          title: 'The Bread of Life',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 6,
          verseSpan: 'John 6:22-59',
          versePreview: 'I am the bread of life: he that cometh to me shall never hunger.',
          reflection: 'Look beyond physical bread to true spiritual sustenance in the person of Jesus.',
        ),
        const ReadingPlanDay(
          dayNumber: 14,
          title: 'Words of Eternal Life',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 6,
          verseSpan: 'John 6:60-71',
          versePreview: 'Lord, to whom shall we go? thou hast the words of eternal life.',
          reflection: 'When many turn back, Peter confesses unshakable faith in the Holy One of God.',
        ),
        const ReadingPlanDay(
          dayNumber: 15,
          title: 'Streams of Living Water',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 7,
          verseSpan: 'John 7:1-39',
          versePreview: 'If any man thirst, let him come unto me, and drink.',
          reflection: 'At the Feast of Booths, Jesus promises the outpouring of the Holy Spirit.',
        ),
        const ReadingPlanDay(
          dayNumber: 16,
          title: 'The Light of the World',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 8,
          verseSpan: 'John 8:1-30',
          versePreview: 'I am the light of the world: he that followeth me shall not walk in darkness.',
          reflection: 'Mercy triumphs over condemnation, and divine light guides our footsteps.',
        ),
        const ReadingPlanDay(
          dayNumber: 17,
          title: 'The Truth Shall Make You Free',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 8,
          verseSpan: 'John 8:31-59',
          versePreview: 'Before Abraham was, I am.',
          reflection: 'Jesus boldly claims the divine covenant name Yahweh, promising authentic liberty.',
        ),
        const ReadingPlanDay(
          dayNumber: 18,
          title: 'The Man Born Blind Healed',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 9,
          verseSpan: 'John 9:1-41',
          versePreview: 'One thing I know, that, whereas I was blind, now I see.',
          reflection: 'Physical blindness gives way to sight, exposing spiritual blindness in religious leaders.',
        ),
        const ReadingPlanDay(
          dayNumber: 19,
          title: 'The Good Shepherd & His Sheep',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 10,
          verseSpan: 'John 10:1-42',
          versePreview: 'I am the good shepherd: the good shepherd giveth his life for the sheep.',
          reflection: 'The Shepherd knows each sheep by name, protecting them in the Father\'s hand forever.',
        ),
        const ReadingPlanDay(
          dayNumber: 20,
          title: 'The Resurrection and the Life',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 11,
          verseSpan: 'John 11:1-44',
          versePreview: 'I am the resurrection, and the life: he that believeth in me, though he were dead, yet shall he live.',
          reflection: 'Jesus weeps with sorrow, then commands Lazarus to emerge living from the tomb.',
        ),
        const ReadingPlanDay(
          dayNumber: 21,
          title: 'Anointed for Burial & Triumphal Entry',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 12,
          verseSpan: 'John 12:1-26',
          versePreview: 'Except a corn of wheat fall into the ground and die, it abideth alone: but if it die, it bringeth forth much fruit.',
          reflection: 'Mary pours fragrant spikenard, and Christ enters Jerusalem to lay down His life.',
        ),
        const ReadingPlanDay(
          dayNumber: 22,
          title: 'Washing the Disciples\' Feet',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 13,
          verseSpan: 'John 13:1-38',
          versePreview: 'A new commandment I give unto you, That ye love one another; as I have loved you.',
          reflection: 'The Lord and Teacher wraps a towel around His waist, illustrating humble service.',
        ),
        const ReadingPlanDay(
          dayNumber: 23,
          title: 'The Way, The Truth, and The Life',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 14,
          verseSpan: 'John 14:1-31',
          versePreview: 'Peace I leave with you, my peace I give unto you: not as the world giveth, give I unto you.',
          reflection: 'Jesus comforts troubled hearts, promising the Counselor, the Spirit of Truth.',
        ),
        const ReadingPlanDay(
          dayNumber: 24,
          title: 'Abiding in the True Vine',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 15,
          verseSpan: 'John 15:1-17',
          versePreview: 'I am the vine, ye are the branches: He that abideth in me, and I in him, the same bringeth forth much fruit.',
          reflection: 'Apart from vital union with Christ, we can do nothing; abiding brings joy and fruit.',
        ),
        const ReadingPlanDay(
          dayNumber: 25,
          title: 'Overcoming the World',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 16,
          verseSpan: 'John 16:1-33',
          versePreview: 'In the world ye shall have tribulation: but be of good cheer; I have overcome the world.',
          reflection: 'Tribulation is certain, but Christ’s victory is final and complete.',
        ),
        const ReadingPlanDay(
          dayNumber: 26,
          title: 'The High Priestly Prayer',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 17,
          verseSpan: 'John 17:1-26',
          versePreview: 'And this is life eternal, that they might know thee the only true God, and Jesus Christ.',
          reflection: 'Listen in on Christ praying intimately for your sanctification, unity, and protection.',
        ),
        const ReadingPlanDay(
          dayNumber: 27,
          title: 'Betrayal and Trial before Pilate',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 18,
          verseSpan: 'John 18:1-40',
          versePreview: 'My kingdom is not of this world.',
          reflection: 'Jesus willingly drinks the cup the Father gave Him, standing resolute as King of truth.',
        ),
        const ReadingPlanDay(
          dayNumber: 28,
          title: 'It is Finished: The Crucifixion',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 19,
          verseSpan: 'John 19:1-42',
          versePreview: 'When Jesus therefore had received the vinegar, he said, It is finished: and he bowed his head.',
          reflection: 'Tetelestai — the debt is paid in full; redemption is forever accomplished.',
        ),
        const ReadingPlanDay(
          dayNumber: 29,
          title: 'The Empty Tomb & Risen Lord',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 20,
          verseSpan: 'John 20:1-31',
          versePreview: 'Thomas answered and said unto him, My Lord and my God.',
          reflection: 'Mary Magdalene, Peter, and Thomas encounter the living Savior who conquered the grave.',
        ),
        const ReadingPlanDay(
          dayNumber: 30,
          title: 'Restoration & Feed My Sheep',
          bookCode: 'JHN',
          bookName: 'John',
          chapter: 21,
          verseSpan: 'John 21:1-25',
          versePreview: 'Lord, thou knowest all things; thou knowest that I love thee. Jesus saith unto him, Feed my sheep.',
          reflection: 'Beside the coals of fire, Jesus lovingly restores Peter and commissions him to feed the flock.',
        ),
      ],
    ),
    _RawPlan(
      id: 'paul_prison_epistles_14d',
      title: 'Paul\'s Prison Epistles',
      subtitle: 'Joy, Armor & Christ\'s Preeminence',
      category: 'Pauline Epistles & Christian Walk',
      durationDays: 14,
      gradientColors: const [Color(0xFF1E1B4B), Color(0xFF1E3A8A)],
      badges: const [
        ReadingPlanBadge(
          id: 'prison_badge_1',
          name: 'Armor of God',
          description: 'Completed week 1 studying spiritual warfare and blessings in Ephesians',
          icon: Icons.shield_rounded,
          dayRequirement: 7,
        ),
        ReadingPlanBadge(
          id: 'prison_badge_2',
          name: 'Joy in Chains Scholar',
          description: 'Finished all 14 days of Ephesians, Philippians, Colossians & Philemon',
          icon: Icons.workspace_premium_rounded,
          dayRequirement: 14,
        ),
      ],
      days: [
        const ReadingPlanDay(
          dayNumber: 1,
          title: 'Chosen & Sealed in Christ',
          bookCode: 'EPH',
          bookName: 'Ephesians',
          chapter: 1,
          verseSpan: 'Ephesians 1:1-23',
          versePreview: 'Blessed be the God and Father of our Lord Jesus Christ, who hath blessed us with all spiritual blessings.',
          reflection: 'Ponder your eternal election, redemption through His blood, and the seal of the Holy Spirit.',
        ),
        const ReadingPlanDay(
          dayNumber: 2,
          title: 'Saved by Grace Through Faith',
          bookCode: 'EPH',
          bookName: 'Ephesians',
          chapter: 2,
          verseSpan: 'Ephesians 2:1-22',
          versePreview: 'For by grace are ye saved through faith; and that not of yourselves: it is the gift of God.',
          reflection: 'We were dead in trespasses, but God who is rich in mercy made us alive together with Christ.',
        ),
        const ReadingPlanDay(
          dayNumber: 3,
          title: 'The Mystery Revealed & Divine Love',
          bookCode: 'EPH',
          bookName: 'Ephesians',
          chapter: 3,
          verseSpan: 'Ephesians 3:1-21',
          versePreview: 'To know the love of Christ, which passeth knowledge, that ye might be filled with all the fulness of God.',
          reflection: 'Grasp the breadth, length, depth, and height of God’s love that surpasses human intellect.',
        ),
        const ReadingPlanDay(
          dayNumber: 4,
          title: 'Walk Worthy: The New Self',
          bookCode: 'EPH',
          bookName: 'Ephesians',
          chapter: 4,
          verseSpan: 'Ephesians 4:1-32',
          versePreview: 'Put on the new man, which after God is created in righteousness and true holiness.',
          reflection: 'Maintain unity of the Spirit in the bond of peace and cultivate Christlike speech.',
        ),
        const ReadingPlanDay(
          dayNumber: 5,
          title: 'Walk in Love & The Whole Armor of God',
          bookCode: 'EPH',
          bookName: 'Ephesians',
          chapter: 6,
          verseSpan: 'Ephesians 6:10-24',
          versePreview: 'Put on the whole armour of God, that ye may be able to stand against the wiles of the devil.',
          reflection: 'Equip the belt of truth, breastplate of righteousness, shield of faith, and sword of the Spirit.',
        ),
        const ReadingPlanDay(
          dayNumber: 6,
          title: 'To Live is Christ, To Die is Gain',
          bookCode: 'PHP',
          bookName: 'Philippians',
          chapter: 1,
          verseSpan: 'Philippians 1:1-30',
          versePreview: 'He which hath begun a good work in you will perform it until the day of Jesus Christ.',
          reflection: 'Paul models unwavering joy from a Roman dungeon, magnifying Christ in life and death.',
        ),
        const ReadingPlanDay(
          dayNumber: 7,
          title: 'The Mind of Christ & Kenosis',
          bookCode: 'PHP',
          bookName: 'Philippians',
          chapter: 2,
          verseSpan: 'Philippians 2:1-18',
          versePreview: 'Let this mind be in you, which was also in Christ Jesus... he humbled himself.',
          reflection: 'Behold the supreme humility of the Son who emptied Himself, whom God exalted above all.',
        ),
        const ReadingPlanDay(
          dayNumber: 8,
          title: 'Pressing Toward the Mark',
          bookCode: 'PHP',
          bookName: 'Philippians',
          chapter: 3,
          verseSpan: 'Philippians 3:1-21',
          versePreview: 'I press toward the mark for the prize of the high calling of God in Christ Jesus.',
          reflection: 'Count all earthly pedigree as loss for the surpassing excellence of knowing Christ.',
        ),
        const ReadingPlanDay(
          dayNumber: 9,
          title: 'Rejoice in the Lord Always',
          bookCode: 'PHP',
          bookName: 'Philippians',
          chapter: 4,
          verseSpan: 'Philippians 4:1-23',
          versePreview: 'I can do all things through Christ which strengtheneth me.',
          reflection: 'Trade anxiety for prayer with thanksgiving, resting in God’s transcendent peace.',
        ),
        const ReadingPlanDay(
          dayNumber: 10,
          title: 'The Supremacy of the Firstborn',
          bookCode: 'COL',
          bookName: 'Colossians',
          chapter: 1,
          verseSpan: 'Colossians 1:1-29',
          versePreview: 'He is the image of the invisible God, the firstborn of every creature.',
          reflection: 'By Him all things were created in heaven and earth, and in Him all things hold together.',
        ),
        const ReadingPlanDay(
          dayNumber: 11,
          title: 'Alive in Christ, Nailed to the Cross',
          bookCode: 'COL',
          bookName: 'Colossians',
          chapter: 2,
          verseSpan: 'Colossians 2:1-23',
          versePreview: 'Blotting out the handwriting of ordinances that was against us, which was contrary to us.',
          reflection: 'Christ disarmed principalities and powers, triumphing over them openly at the cross.',
        ),
        const ReadingPlanDay(
          dayNumber: 12,
          title: 'Set Your Affection on Things Above',
          bookCode: 'COL',
          bookName: 'Colossians',
          chapter: 3,
          verseSpan: 'Colossians 3:1-17',
          versePreview: 'Let the word of Christ dwell in you richly in all wisdom.',
          reflection: 'Since you are raised with Christ, seek the heavenly realities where Christ sits at God’s right hand.',
        ),
        const ReadingPlanDay(
          dayNumber: 13,
          title: 'Devoted in Prayer & Gracious Speech',
          bookCode: 'COL',
          bookName: 'Colossians',
          chapter: 4,
          verseSpan: 'Colossians 4:1-18',
          versePreview: 'Let your speech be alway with grace, seasoned with salt.',
          reflection: 'Walk wisely toward outsiders, making the most of every opportunity for the gospel.',
        ),
        const ReadingPlanDay(
          dayNumber: 14,
          title: 'No Longer a Slave, But a Brother',
          bookCode: 'PHM',
          bookName: 'Philemon',
          chapter: 1,
          verseSpan: 'Philemon 1:1-25',
          versePreview: 'Receive him as myself. If he hath wronged thee, or oweth thee ought, put that on mine account.',
          reflection: 'Paul demonstrates gospel restitution and brotherhood, pointing to Christ bearing our debt.',
        ),
      ],
    ),
    _RawPlan(
      id: 'wisdom_literature_21d',
      title: 'Wisdom Literature',
      subtitle: 'Discernment, Proverbs & The Fear of God',
      category: 'Wisdom & Poetic Books',
      durationDays: 21,
      gradientColors: const [Color(0xFF451A03), Color(0xFFB45309)],
      badges: const [
        ReadingPlanBadge(
          id: 'wisdom_badge_1',
          name: 'Path of Understanding',
          description: 'Completed 10 days in the wisdom of Solomon',
          icon: Icons.psychology_rounded,
          dayRequirement: 10,
        ),
        ReadingPlanBadge(
          id: 'wisdom_badge_2',
          name: 'Wisdom Seeker',
          description: 'Finished all 21 days of Proverbs and Ecclesiastes study',
          icon: Icons.diamond_rounded,
          dayRequirement: 21,
        ),
      ],
      days: [
        const ReadingPlanDay(
          dayNumber: 1,
          title: 'The Beginning of Knowledge',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 1,
          verseSpan: 'Proverbs 1:1-33',
          versePreview: 'The fear of the LORD is the beginning of knowledge: but fools despise wisdom and instruction.',
          reflection: 'True understanding starts with reverent awe and submission before Almighty God.',
        ),
        const ReadingPlanDay(
          dayNumber: 2,
          title: 'Seeking Wisdom as Hidden Treasure',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 2,
          verseSpan: 'Proverbs 2:1-22',
          versePreview: 'If thou seekest her as silver, and searchest for her as for hid treasures; then shalt thou understand.',
          reflection: 'Wisdom rewards earnest pursuit, delivering our feet from the treacherous paths of darkness.',
        ),
        const ReadingPlanDay(
          dayNumber: 3,
          title: 'Trust in the LORD with All Thine Heart',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 3,
          verseSpan: 'Proverbs 3:1-35',
          versePreview: 'Trust in the LORD with all thine heart; and lean not unto thine own understanding.',
          reflection: 'Acknowledge God in all your ways, and He will make straight your paths.',
        ),
        const ReadingPlanDay(
          dayNumber: 4,
          title: 'Keep Thy Heart with All Diligence',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 4,
          verseSpan: 'Proverbs 4:1-27',
          versePreview: 'Keep thy heart with all diligence; for out of it are the issues of life.',
          reflection: 'Guard your inner thoughts and affections, for they shape the entire direction of your journey.',
        ),
        const ReadingPlanDay(
          dayNumber: 5,
          title: 'Fleeing Folly and Embracing Wisdom',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 8,
          verseSpan: 'Proverbs 8:1-36',
          versePreview: 'The LORD possessed me in the beginning of his way, before his works of old.',
          reflection: 'Wisdom speaks from eternity, delighting in mankind and bestowing true blessing.',
        ),
        const ReadingPlanDay(
          dayNumber: 6,
          title: 'The Way of Integrity and Truth',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 11,
          verseSpan: 'Proverbs 11:1-31',
          versePreview: 'A false balance is abomination to the LORD: but a just weight is his delight.',
          reflection: 'Integrity guides the upright, while dishonest shortcuts bring ruin.',
        ),
        const ReadingPlanDay(
          dayNumber: 7,
          title: 'Righteous Tongue & Faithful Witness',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 12,
          verseSpan: 'Proverbs 12:1-28',
          versePreview: 'Lying lips are abomination to the LORD: but they that deal truly are his delight.',
          reflection: 'The tongue of the wise brings healing, while reckless words pierce like sword thrusts.',
        ),
        const ReadingPlanDay(
          dayNumber: 8,
          title: 'Walking with Wise Companions',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 13,
          verseSpan: 'Proverbs 13:1-25',
          versePreview: 'He that walketh with wise men shall be wise: but a companion of fools shall be destroyed.',
          reflection: 'Surround yourself with godly mentors and peers who stir up righteousness.',
        ),
        const ReadingPlanDay(
          dayNumber: 9,
          title: 'A Soft Answer Turneth Away Wrath',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 15,
          verseSpan: 'Proverbs 15:1-33',
          versePreview: 'A soft answer turneth away wrath: but grievous words stir up anger.',
          reflection: 'Gentleness de-escalates conflict and reveals spiritual maturity under pressure.',
        ),
        const ReadingPlanDay(
          dayNumber: 10,
          title: 'Commit Thy Works unto the LORD',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 16,
          verseSpan: 'Proverbs 16:1-33',
          versePreview: 'Commit thy works unto the LORD, and thy thoughts shall be established.',
          reflection: 'Man proposes in his heart, but the LORD directs and establishes his steps.',
        ),
        const ReadingPlanDay(
          dayNumber: 11,
          title: 'The Name of the LORD is a Strong Tower',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 18,
          verseSpan: 'Proverbs 18:1-24',
          versePreview: 'The name of the LORD is a strong tower: the righteous runneth into it, and is safe.',
          reflection: 'Find your ultimate refuge in God’s character, not in fragile earthly wealth.',
        ),
        const ReadingPlanDay(
          dayNumber: 12,
          title: 'Counsel in the Heart of Man',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 20,
          verseSpan: 'Proverbs 20:1-30',
          versePreview: 'The spirit of man is the candle of the LORD, searching all the inward parts of the belly.',
          reflection: 'God searches our innermost motives with His divine light.',
        ),
        const ReadingPlanDay(
          dayNumber: 13,
          title: 'A Good Name Rather Than Great Riches',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 22,
          verseSpan: 'Proverbs 22:1-29',
          versePreview: 'A good name is rather to be chosen than great riches, and loving favour rather than silver and gold.',
          reflection: 'Character and godly reputation outlive any material bank account.',
        ),
        const ReadingPlanDay(
          dayNumber: 14,
          title: 'Train Up a Child & Wise Boundaries',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 23,
          verseSpan: 'Proverbs 23:1-35',
          versePreview: 'Buy the truth, and sell it not; also wisdom, and instruction, and understanding.',
          reflection: 'Never compromise or bargain away spiritual truth for momentary indulgence.',
        ),
        const ReadingPlanDay(
          dayNumber: 15,
          title: 'A Friend That Loveth at All Times',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 27,
          verseSpan: 'Proverbs 27:1-27',
          versePreview: 'Iron sharpeneth iron; so a man sharpeneth the countenance of his friend.',
          reflection: 'Cherish constructive honesty from true brothers and sisters in Christ.',
        ),
        const ReadingPlanDay(
          dayNumber: 16,
          title: 'The Righteous are Bold as a Lion',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 28,
          verseSpan: 'Proverbs 28:1-28',
          versePreview: 'The wicked flee when no man pursueth: but the righteous are bold as a lion.',
          reflection: 'A clear conscience before God produces holy confidence and courage.',
        ),
        const ReadingPlanDay(
          dayNumber: 17,
          title: 'Where There is No Vision, The People Perish',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 29,
          verseSpan: 'Proverbs 29:1-27',
          versePreview: 'Where there is no vision, the people perish: but he that keepeth the law, happy is he.',
          reflection: 'Without prophetic revelation of God’s Word, society casts off moral restraint.',
        ),
        const ReadingPlanDay(
          dayNumber: 18,
          title: 'The Words of Agur & Pure Words of God',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 30,
          verseSpan: 'Proverbs 30:1-33',
          versePreview: 'Every word of God is pure: he is a shield unto them that put their trust in him.',
          reflection: 'Rest in the flawless perfection and tested reliability of God’s Word.',
        ),
        const ReadingPlanDay(
          dayNumber: 19,
          title: 'The Noble Woman of Virtue',
          bookCode: 'PRO',
          bookName: 'Proverbs',
          chapter: 31,
          verseSpan: 'Proverbs 31:10-31',
          versePreview: 'Favour is deceitful, and beauty is vain: but a woman that feareth the LORD, she shall be praised.',
          reflection: 'Praise godly diligence, wisdom, generosity, and the reverent fear of God.',
        ),
        const ReadingPlanDay(
          dayNumber: 20,
          title: 'A Time for Every Purpose Under Heaven',
          bookCode: 'ECC',
          bookName: 'Ecclesiastes',
          chapter: 3,
          verseSpan: 'Ecclesiastes 3:1-22',
          versePreview: 'To every thing there is a season, and a time to every purpose under the heaven.',
          reflection: 'God has set eternity in the human heart, making everything beautiful in its time.',
        ),
        const ReadingPlanDay(
          dayNumber: 21,
          title: 'The Conclusion of the Whole Matter',
          bookCode: 'ECC',
          bookName: 'Ecclesiastes',
          chapter: 12,
          verseSpan: 'Ecclesiastes 12:1-14',
          versePreview: 'Fear God, and keep his commandments: for this is the whole duty of man.',
          reflection: 'Beyond the fleeting vanity of earthly pursuits, our eternal purpose rests in honoring God.',
        ),
      ],
    ),
    _RawPlan(
      id: 'messianic_prophecies_10d',
      title: 'Messianic Prophecies Fulfilled',
      subtitle: 'Old Testament Shadows to New Testament Light',
      category: 'Prophecy & Typology',
      durationDays: 10,
      gradientColors: const [Color(0xFF2E1065), Color(0xFF581C87)],
      badges: const [
        ReadingPlanBadge(
          id: 'messiah_badge_1',
          name: 'Prophetic Witness',
          description: 'Completed 5 days tracing Old Testament Messianic promises',
          icon: Icons.star_rounded,
          dayRequirement: 5,
        ),
        ReadingPlanBadge(
          id: 'messiah_badge_2',
          name: 'Crown of Righteousness',
          description: 'Finished all 10 days of Messianic prophecies fulfilled in Jesus',
          icon: Icons.military_tech_rounded,
          dayRequirement: 10,
        ),
      ],
      days: [
        const ReadingPlanDay(
          dayNumber: 1,
          title: 'The Seed of the Woman & Abrahamic Blessing',
          bookCode: 'GEN',
          bookName: 'Genesis',
          chapter: 3,
          verseSpan: 'Genesis 3:14-19',
          versePreview: 'And I will put enmity between thee and the woman, and between thy seed and her seed; it shall bruise thy head.',
          reflection: 'The Protoevangelium — the earliest whisper of Christ’s victory over the serpent at Calvary.',
        ),
        const ReadingPlanDay(
          dayNumber: 2,
          title: 'Born in Bethlehem Ephrathah',
          bookCode: 'MIC',
          bookName: 'Micah',
          chapter: 5,
          verseSpan: 'Micah 5:1-5',
          versePreview: 'But thou, Bethlehem Ephratah, though thou be little among the thousands of Judah, yet out of thee shall he come forth.',
          reflection: 'Centuries in advance, the humble birthplace of the Eternal Ruler is pinpointed.',
        ),
        const ReadingPlanDay(
          dayNumber: 3,
          title: 'A Virgin Shall Conceive: Immanuel',
          bookCode: 'ISA',
          bookName: 'Isaiah',
          chapter: 7,
          verseSpan: 'Isaiah 7:10-17',
          versePreview: 'Behold, a virgin shall conceive, and bear a son, and shall call his name Immanuel.',
          reflection: 'God with us: the miracle of the virgin birth revealing God dwelling among man.',
        ),
        const ReadingPlanDay(
          dayNumber: 4,
          title: 'Unto Us a Child is Born',
          bookCode: 'ISA',
          bookName: 'Isaiah',
          chapter: 9,
          verseSpan: 'Isaiah 9:1-7',
          versePreview: 'His name shall be called Wonderful, Counsellor, The mighty God, The everlasting Father, The Prince of Peace.',
          reflection: 'The divine titles of the Messiah herald an unending kingdom of righteousness.',
        ),
        const ReadingPlanDay(
          dayNumber: 5,
          title: 'The Rod from the Stem of Jesse',
          bookCode: 'ISA',
          bookName: 'Isaiah',
          chapter: 11,
          verseSpan: 'Isaiah 11:1-10',
          versePreview: 'And the spirit of the LORD shall rest upon him, the spirit of wisdom and understanding.',
          reflection: 'The sevenfold Spirit of God empowers the Branch of David to reign in justice.',
        ),
        const ReadingPlanDay(
          dayNumber: 6,
          title: 'My God, My God, Why Hast Thou Forsaken Me?',
          bookCode: 'PSA',
          bookName: 'Psalms',
          chapter: 22,
          verseSpan: 'Psalm 22:1-31',
          versePreview: 'They pierced my hands and my feet. They part my garments among them, and cast lots upon my vesture.',
          reflection: 'David’s prophetic song portrays crucifixion details a thousand years before Roman execution existed.',
        ),
        const ReadingPlanDay(
          dayNumber: 7,
          title: 'The Suffering Servant of Isaiah 53',
          bookCode: 'ISA',
          bookName: 'Isaiah',
          chapter: 53,
          verseSpan: 'Isaiah 53:1-12',
          versePreview: 'He was wounded for our transgressions, he was bruised for our iniquities: the chastisement of our peace was upon him.',
          reflection: 'Substitutionary atonement explained with breathtaking clarity: the innocent Lamb bruised for our guilt.',
        ),
        const ReadingPlanDay(
          dayNumber: 8,
          title: 'The Humble King Riding on a Colt',
          bookCode: 'ZEC',
          bookName: 'Zechariah',
          chapter: 9,
          verseSpan: 'Zechariah 9:9-17',
          versePreview: 'Rejoice greatly, O daughter of Zion... behold, thy King cometh unto thee: he is just, and having salvation; lowly, and riding upon an ass.',
          reflection: 'The Prince of Peace arrives not on a warhorse, but in meekness to bring reconciliation.',
        ),
        const ReadingPlanDay(
          dayNumber: 9,
          title: 'Thirty Pieces of Silver & The Pierced One',
          bookCode: 'ZEC',
          bookName: 'Zechariah',
          chapter: 12,
          verseSpan: 'Zechariah 12:10-14',
          versePreview: 'And they shall look upon me whom they have pierced, and they shall mourn for him, as one mourneth for his only son.',
          reflection: 'The betrayal price and the piercing of the Messiah forecast the sorrow and redemption of Golgotha.',
        ),
        const ReadingPlanDay(
          dayNumber: 10,
          title: 'Thou Wilt Not Leave My Soul in Hell',
          bookCode: 'PSA',
          bookName: 'Psalms',
          chapter: 16,
          verseSpan: 'Psalm 16:1-11',
          versePreview: 'For thou wilt not leave my soul in hell; neither wilt thou suffer thine Holy One to see corruption.',
          reflection: 'The resurrection victory foretold: the grave could not hold the Holy One of God!',
        ),
      ],
    ),
  ];
}

class _RawPlan {
  final String id;
  final String title;
  final String subtitle;
  final String category;
  final int durationDays;
  final List<Color> gradientColors;
  final List<ReadingPlanBadge> badges;
  final List<ReadingPlanDay> days;

  const _RawPlan({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.durationDays,
    required this.gradientColors,
    required this.badges,
    required this.days,
  });
}
