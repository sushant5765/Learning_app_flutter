class ReadingPassages {
  // Beginner Passages (Simple, short, high-frequency words)
  static const List<String> beginnerPassages = [
    "The sun sets and the sky turns orange. Birds fly home to rest.",
    "Tom has a red ball. He kicks it high and laughs with joy.",
    "Jack's cat sleeps on the bed. It purrs softly when he pets it.",
    "The park is full of flowers. Children run and play together.",
    "It rains outside. The drops fall on the roof with a gentle sound.",
    "My dog runs fast. He loves to chase his blue ball in the yard.",
    "We eat lunch at noon. The food is warm and tastes very good.",
    "She reads a book. The story is fun and makes her smile.",
    "I see a big tree. Green leaves move in the cool wind.",
    "He has a new friend. They play games every day after school.",
    "The car is red. It goes very fast down the long road.",
    "Mom makes cake. The sweet smell fills our whole house.",
    "Fish swim in water. They are shiny and move so quick.",
    "We go to the shop. I get milk and bread for my mom.",
    "Stars shine at night. The moon is bright and round up high."
  ];

  // Intermediate Passages (Longer sentences, some complex words, dyslexia-friendly)
  static const List<String> intermediatePassages = [
    "In the village square, people meet to share news and laughter.",
    "The river flows past green fields, carrying small boats downstream.",
    "A little boy holds his kite tight as the wind pulls it higher.",
    "She opened her book and lost herself in a world of magic and adventure.",
    "The old tree stood tall, giving shade to travelers on the hot road.",
    "The kind teacher helped the student understand the difficult problem.",
    "Fresh bread baked in the oven filled the kitchen with warmth and comfort.",
    "Children built a fort from blankets and shared stories until bedtime.",
    "The determined athlete practiced every day to achieve her important goal.",
    "Gardens bloom with colorful flowers that attract bees and butterflies.",
    "The curious explorer discovered ancient ruins hidden deep in the forest.",
    "Families gather around the table to enjoy meals and conversation together.",
    "The gentle musician played soft melodies that calmed everyone who listened.",
    "Winter brings snow that covers the landscape in a quiet white blanket.",
    "The brave firefighter rescued the frightened kitten from the tall tree."
  ];

  // Advanced Passages (Complex sentences, richer vocabulary, meaningful content)
  static const List<String> advancedPassages = [
    "Courage is not the absence of fear, but the decision to move forward despite it.",
    "The library was filled with ancient books, each holding wisdom from the past.",
    "Progress comes when people work together, sharing ideas and building trust.",
    "The scientist studied the stars, searching for answers about the universe.",
    "History shows us that even small steps can lead to great change over time.",
    "Innovation requires both creativity and perseverance to transform ideas into reality.",
    "True friendship develops through shared experiences and mutual understanding over years.",
    "The artist expressed complex emotions through bold colors and dynamic compositions.",
    "Education empowers individuals to overcome obstacles and achieve their full potential.",
    "Nature's balance depends on the intricate relationships between all living organisms.",
    "Cultural diversity enriches societies by introducing different perspectives and traditions.",
    "Technological advancement should complement human interaction rather than replace it.",
    "Environmental conservation requires global cooperation and sustainable practices.",
    "Literary classics explore universal themes that remain relevant across generations.",
    "Personal growth often occurs when we step outside our comfort zones and face challenges."
  ];

  // Get all passages (for backward compatibility)
  static List<String> get passages => [
    ...beginnerPassages,
    ...intermediatePassages,
    ...advancedPassages,
  ];

  // Helper method to get passages by difficulty level
  static List<String> getPassagesByLevel(String level) {             // called by reading practice screen
    switch (level.toLowerCase()) {
      case 'beginner':
        return beginnerPassages;
      case 'intermediate':
        return intermediatePassages;
      case 'advanced':
        return advancedPassages;
      default:
        return passages;
    }
  }
}