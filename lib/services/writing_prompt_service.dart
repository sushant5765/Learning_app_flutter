import 'dart:math';

class WritingPromptService {
  WritingPromptService._();

  static final WritingPromptService instance = WritingPromptService._();

  final Map<String, Map<String, List<String>>> _promptCatalogue = {
    'beginner': {
      'animals': [
        'Describe a day caring for a friendly pet.',
        'Write about why your favourite animal makes you smile.',
      ],
      'travel': [
        'Write about going to a park or garden with family.',
        'Describe a short car trip you enjoyed.',
      ],
      'science': [
        'Write about your favourite season and what you do then.',
        'Describe a plant or flower that you like.',
      ],
      'community': [
        'Who helps people in your neighborhood (like mail carriers or firefighters)?',
        'Describe a place in your community you like to visit.',
      ],
      'general': [
        'Explain what makes a rainy day fun.',
        'Write about a small act of kindness you did this week.',
      ],
    },
    'intermediate': {
      'animals': [
        'How do pets help people feel better when they are sad?',
        'Describe how animals adapt to different seasons.',
      ],
      'travel': [
        'Write about a place you wish to visit and what you would do there.',
        'Imagine guiding a friend around your city. What would you show first?',
      ],
      'science': [
        'Explain how a small invention could make life easier for others.',
        'Describe a science experiment you would like to try and why.',
      ],
      'community': [
        'What makes a neighborhood feel like home?',
        'Describe a community event that brings people together.',
      ],
      'general': [
        'Tell the story of a challenge you faced and how you kept going.',
        'Describe a moment when a mistake taught you something useful.',
      ],
    },
    'advanced': {
      'animals': [
        'Discuss the ethical treatment of animals in modern society.',
        'How does climate change affect animal habitats and migration?',
      ],
      'travel': [
        'Discuss the impact of tourism on local cultures and economies.',
        'Is travel a luxury or a necessary part of education?',
      ],
      'science': [
        'How will artificial intelligence change our daily lives in the next 20 years?',
        'Discuss the benefits and risks of genetic engineering.',
      ],
      'community': [
        'Describe a project that could improve your neighbourhood.',
        'Write an opinion piece about why volunteering matters.',
      ],
      'general': [
        'Argue for a change you want to see in your school or community.',
        'Reflect on a book or movie that changed how you think about an important issue.',
      ],
    },
  };

  String generatePrompt({    // ths method used by writing practice
    required String difficulty,
    required String preference,
  }) {
    final difficultyKey = _promptCatalogue.containsKey(difficulty)
        ? difficulty
        : 'beginner';
    final topics = _promptCatalogue[difficultyKey]!;

    final preferenceKey = _pickPreferenceKey(preference, topics.keys);
    final prompts = topics[preferenceKey] ?? topics['general']!;

    return prompts[Random().nextInt(prompts.length)];
  }

  String _pickPreferenceKey(
      String preference,
      Iterable<String> availableKeys,
      ) {
    final cleaned = preference.toLowerCase().split(RegExp(r'[,\s]+'))
      ..removeWhere((e) => e.isEmpty);
    final set = cleaned.toSet();

    for (final key in availableKeys) {
      if (key == 'general') continue;
      if (set.contains(key)) return key;
    }
    return 'general';
  }
}