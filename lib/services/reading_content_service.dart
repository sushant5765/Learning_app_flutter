import 'dart:math';

class ReadingContentService {
  ReadingContentService._();

  static final _random = Random();

  static final Map<String, List<_Template>> _levelTemplates = {
    'beginner': [
      _Template(
        sentences: [
          "Today we explore {topic} in a friendly way.",
          "{hook}",
          "{fact}",
          "{reflection}",
        ],
      ),
      _Template(
        sentences: [
          "{topicSentence}",
          "{gentleDetail}",
          "{sensory}",
          "{closingThought}",
        ],
      ),
    ],
    'intermediate': [
      _Template(
        sentences: [
          "Let’s dive into {topic} and discover why it matters.",
          "{hook}",
          "{fact}",
          "{example}",
          "{reflection}",
        ],
      ),
      _Template(
        sentences: [
          "{topicSentence}",
          "{gentleDetail}",
          "{fact}",
          "{connection}",
          "{closingThought}",
        ],
      ),
    ],
    'advanced': [
      _Template(
        sentences: [
          "{topicSentence}",
          "{hook}",
          "{fact}",
          "{example}",
          "{connection}",
          "{reflection}",
        ],
      ),
      _Template(
        sentences: [
          "{topicSentence}",
          "{insight}",
          "{fact}",
          "{example}",
          "{reflection}",
          "{forwardLook}",
        ],
      ),
    ],
  };

  static final Map<String, Map<String, List<String>>> _topicSnippets = {     // contains the sentences
    'space exploration': {
      'topicSentence': [
        "Space exploration lets us dream beyond the blue sky.",
        "Scientists study space to understand our place in the universe.",
      ],
      'hook': [
        "For centuries, humans have looked up and wondered if other worlds exist.",
        "Each rocket launch begins with a spark of curiosity.",
      ],
      'fact': [
        "The International Space Station orbits Earth every 90 minutes.",
        "Astronauts must exercise daily to keep their muscles strong in zero gravity.",
      ],
      'example': [
        "When the Perseverance rover landed on Mars, it searched for ancient signs of water.",
        "The James Webb telescope peers deep into galaxies born billions of years ago.",
      ],
      'gentleDetail': [
        "Even a simple star map can help us trace constellations across the night sky.",
        "Back on Earth, telescopes help families spot shining planets on clear evenings.",
      ],
      'connection': [
        "Discoveries from space often improve life here, from weather forecasts to satellite calls.",
        "Exploring distant planets teaches us how precious our own world is.",
      ],
      'reflection': [
        "Every mission reminds us that curiosity can lead to extraordinary discoveries.",
        "Learning about space encourages us to ask big questions about the future.",
      ],
      'sensory': [
        "Imagine the hush of space, where only the hum of a spacecraft can be heard.",
        "From orbit, astronauts see Earth as a bright marble of blues and whites.",
      ],
      'insight': [
        "Space missions are really collaborations between engineers, artists, and dreamers.",
        "Even tiny experiments on satellites can shift how we understand physics.",
      ],
      'forwardLook': [
        "Tomorrow's explorers might step onto Mars, guided by the lessons we learn today.",
        "As technology grows, more students may design their own experiments for space.",
      ],
    },
    'ocean animals': {
      'topicSentence': [
        "The ocean is alive with animals that glide, dart, and glow.",
        "Beneath the blue waves, ocean animals form a world of their own.",
      ],
      'hook': [
        "Some fish light up like stars to stay safe in dark water.",
        "Waves cover secrets of creatures that scientists are still discovering.",
      ],
      'fact': [
        "Whales sing low songs that travel farther than any other animal sound.",
        "Sea turtles can migrate thousands of miles returning to their birth beach.",
      ],
      'example': [
        "Clownfish hide among sea anemones, where gentle tentacles protect them.",
        "Giant kelp forests sway slowly, sheltering playful sea lions.",
      ],
      'gentleDetail': [
        "Sea otters wrap themselves in kelp so the tide will not carry them away.",
        "Crabs scuttle sideways, leaving tiny patterns in the sand.",
      ],
      'connection': [
        "Healthy reefs also protect coastlines from strong waves.",
        "When oceans stay clean, communities enjoy better fishing and tourism.",
      ],
      'reflection': [
        "By respecting the sea, we protect both wildlife and our own future.",
        "Learning about ocean animals reminds us how connected all life is.",
      ],
      'sensory': [
        "Imagine the cool splash of water as dolphins leap beside a boat.",
        "You might hear the crackle of shrimp when divers pause to listen.",
      ],
      'insight': [
        "Each species plays a role; even tiny plankton feed great whales.",
        "Ocean food webs are delicate, balancing energy from sunlight and currents.",
      ],
      'forwardLook': [
        "Marine biologists now use drones and gentle tags to watch animals safely.",
        "Someday, new ocean sanctuaries might protect calm nurseries for young fish.",
      ],
    },
    'ancient egypt': {
      'topicSentence': [
        "Ancient Egypt thrived along the Nile River thousands of years ago.",
        "Stories of pharaohs and pyramids still inspire people around the world.",
      ],
      'hook': [
        "Hieroglyphs carved into stone tell secrets of daily life and royal dreams.",
        "Massive pyramids rose from the desert, aligned perfectly with the stars.",
      ],
      'fact': [
        "The Nile's yearly flood left rich soil that fed entire cities.",
        "Skilled artisans created jewelry from gold, lapis, and bright glass.",
      ],
      'example': [
        "Scribes carefully mixed ink to record laws and trade on papyrus scrolls.",
        "Farmers timed planting by watching the star Sirius appear before dawn.",
      ],
      'gentleDetail': [
        "Children learned to read by tracing glyphs in smooth sand.",
        "Markets buzzed with traders swapping spices, cloth, and carved statues.",
      ],
      'connection': [
        "Many modern calendars still follow ideas shaped beside the Nile.",
        "Architecture today borrows columns and symbols inspired by Egyptian temples.",
      ],
      'reflection': [
        "Studying their achievements reminds us how knowledge can last for millennia.",
        "Ancient Egypt shows how science, art, and belief can weave a powerful culture.",
      ],
      'sensory': [
        "Picture the golden glow of sunrise over polished temple walls.",
        "Hear the gentle splash of oars as boats carried grain downstream.",
      ],
      'insight': [
        "Engineers then used simple tools with clever teamwork to build wonders.",
        "Astronomy, math, and art blended to make monuments that still stand.",
      ],
      'forwardLook': [
        "Archaeologists continue to discover hidden tombs using delicate technology.",
        "New museum exhibits let students virtually tour pyramids from home.",
      ],
    },
    'mindful breathing': {
      'topicSentence': [
        "Mindful breathing gives the mind a calm place to rest.",
        "When life feels busy, slow breaths help us feel steady again.",
      ],
      'hook': [
        "Just five deep breaths can send a message that you are safe.",
        "Sitting still and breathing slowly is like pressing pause for a moment.",
      ],
      'fact': [
        "Studies show mindful breathing can lower heart rate and stress.",
        "Athletes use breathing routines to stay focused before a big event.",
      ],
      'example': [
        "Students who breathe quietly before tests often feel less nervous.",
        "Musicians take calm breaths to steady their hands before playing.",
      ],
      'gentleDetail': [
        "You can breathe in slowly through your nose and out through your mouth.",
        "A quiet corner with soft light makes practice easier for beginners.",
      ],
      'connection': [
        "Sharing the practice with friends builds a supportive routine.",
        "Teachers sometimes guide a whole class through a one-minute pause.",
      ],
      'reflection': [
        "Every calm breath reminds us we can choose how to respond.",
        "Practicing daily grows confidence and kindness toward ourselves.",
      ],
      'sensory': [
        "Notice the cool air as you inhale and the warmth as you exhale.",
        "Feel your shoulders relax and your heartbeat grow gentle.",
      ],
      'insight': [
        "Breathing anchors the mind; it is a portable tool we carry everywhere.",
        "Even busy schedules hold space for a quick mindful pause.",
      ],
      'forwardLook': [
        "With practice, mindful breathing can support deeper meditation.",
        "Apps now guide mindful breaks, but the real power is inside you.",
      ],
    },
    'renewable energy': {
      'topicSentence': [
        "Renewable energy comes from sources that nature replaces quickly.",
        "Communities worldwide are investing in clean power solutions.",
      ],
      'hook': [
        "Sunlight can power homes, and wind can turn giant turbines.",
        "Even ocean tides are being explored as reliable energy partners.",
      ],
      'fact': [
        "Many cities now blend solar panels, wind farms, and battery storage.",
        "Solar panels work best when they can rotate to follow the sun.",
      ],
      'example': [
        "A school roof covered in panels now powers classes and charges devices.",
        "Mountaintop wind turbines send electricity to valley neighborhoods.",
      ],
      'gentleDetail': [
        "Engineers test new blade shapes inspired by the wings of owls and whales.",
        "Some families plant tree buffers to hide and quiet large turbines.",
      ],
      'connection': [
        "Clean energy reduces pollution and keeps air easier to breathe.",
        "Electric buses and bikes help cities stay quiet and efficient.",
      ],
      'reflection': [
        "Choosing renewable energy shows care for future generations.",
        "Innovation grows when people share ideas across science and art.",
      ],
      'sensory': [
        "Imagine the soft whoosh of blades turning high above a meadow.",
        "Solar panels shimmer as clouds glide overhead.",
      ],
      'insight': [
        "Energy teams include designers, analysts, and community planners.",
        "Balancing the grid requires both technology and thoughtful timing.",
      ],
      'forwardLook': [
        "Scientists test new storage batteries so power is ready day and night.",
        "Students today may lead tomorrow's clean-energy breakthroughs.",
      ],
    },
    'friendship': {
      'topicSentence': [
        "Friendship grows from small moments of trust and laughter.",
        "Even quiet acts of kindness can plant the seeds of friendship.",
      ],
      'hook': [
        "Sharing a secret or a joke can bring two people closer.",
        "Listening with patience shows friends they are valued.",
      ],
      'fact': [
        "Psychologists find that friends who celebrate each other's wins feel closer.",
        "Strong friendships can boost happiness and even support good health.",
      ],
      'example': [
        "Two classmates study together and cheer each other before exams.",
        "Neighbors exchange homemade meals when life feels hectic.",
      ],
      'gentleDetail': [
        "A simple note of encouragement can brighten someone's whole day.",
        "Laughing together often creates memories that last for years.",
      ],
      'connection': [
        "Friendship teaches us empathy, patience, and understanding.",
        "Communities become stronger when friendships cross different cultures.",
      ],
      'reflection': [
        "Making time for friends keeps relationships strong and joyful.",
        "Friendship is a journey built on trust, honesty, and shared adventures.",
      ],
      'sensory': [
        "Imagine the warm hug of a friend you haven't seen in a while.",
        "Hear the joyful noise of friends planning their next outing.",
      ],
      'insight': [
        "Friends remind us who we are and who we can become.",
        "Even disagreements can deepen friendship when handled with care.",
      ],
      'forwardLook': [
        "New friendships can begin with a simple hello or shared project.",
        "Digital chats keep friends close, but in-person moments strengthen the bond.",
      ],
    },
  };

  static String generatePassage({            // main function decides topic &level
    required String topic,
    String level = 'beginner',
    bool longForm = false,
  }) {
    final normalisedLevel = _levelTemplates.containsKey(level.toLowerCase())
        ? level.toLowerCase()
        : 'beginner';
    final lowTopic = topic.toLowerCase().trim();
    final snippets = _topicSnippets[lowTopic] ?? _topicSnippets['friendship']!;
    final template =
        _pickRandomTemplate(_levelTemplates[normalisedLevel] ?? []);                  //picks template random template

    if (longForm) {
      final paragraphs = <String>[];
      for (var i = 0; i < 3; i++) {
        paragraphs.add(_fillTemplate(
          template,
          snippets,
          topic: topic,
          variation: i,
        ));
      }
      return paragraphs.join('\n\n');
    }

    return _fillTemplate(template, snippets, topic: topic, variation: 0);
  }

  static _Template _pickRandomTemplate(List<_Template> templates) {
    if (templates.isEmpty) {
      return const _Template(sentences: ["{topicSentence}"]);
    }
    return templates[_random.nextInt(templates.length)];
  }

  static String _fillTemplate(                       // replaces placeholder with actual sentences
    _Template template,
    Map<String, List<String>> snippets, {
    required String topic,
    required int variation,
  }) {
    final buffer = StringBuffer();                     // processed sentence combined to passage
    for (final sentence in template.sentences) {
      var filled = sentence;
      final placeholders =
          RegExp(r'\{([a-zA-Z]+)\}').allMatches(sentence).map((m) => m[1]);  //looks for pattern in text creates placeholders

      for (final placeholder in placeholders) {
        if (placeholder == null) continue;
        if (placeholder == 'topic') {
          filled = filled.replaceAll('{topic}', topic);
          continue;
        }
        final options = snippets[placeholder];
        if (options == null || options.isEmpty) {
          filled = filled.replaceAll('{$placeholder}', '');
        } else {
          final choice =
              options[(variation + _random.nextInt(options.length)) % options.length];
          filled = filled.replaceAll('{$placeholder}', choice);
        }
      }

      final finalSentence = filled.trim();
      if (finalSentence.isNotEmpty) {
        buffer.write(finalSentence);
        if (!finalSentence.endsWith('.')) buffer.write('.');
        buffer.write(' ');
      }
    }

    return buffer.toString().trim();
  }
}

class _Template {
  const _Template({required this.sentences});
  final List<String> sentences;
}

