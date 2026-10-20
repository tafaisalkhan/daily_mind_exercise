// Rebuild the shipped challenge banks. Run: node scripts/tools/generate_game_type_levels.js
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../../assets/data/game_types');
const read = name => JSON.parse(fs.readFileSync(path.join(root, name + '.json'), 'utf8'));
const write = (name, data) => fs.writeFileSync(path.join(root, name + '.json'), JSON.stringify(data));
const copy = value => JSON.parse(JSON.stringify(value));

function build(name, starterCount, make) {
  const data = read(name);
  const starters = data.levels.slice(0, starterCount).map(copy);
  data.levels = Array.from({length: 1000}, (_, i) => {
    const level = i < starters.length ? starters[i] : make(i, starters);
    return {level: i + 1, ...level};
  });
  write(name, data);
  console.log(name, data.levels.length);
}

const synonymPairs = [
  ['happy','joyful'],['quick','fast'],['small','tiny'],['begin','start'],['large','big'],
  ['silent','quiet'],['smart','clever'],['angry','furious'],['pretty','lovely'],['brave','bold'],
  ['kind','gentle'],['close','shut'],['easy','simple'],['hard','tough'],['gift','present'],
  ['sick','ill'],['rich','wealthy'],['funny','amusing'],['neat','tidy'],['glad','pleased'],
  ['calm','peaceful'],['cold','chilly'],['sad','unhappy'],['look','see'],['jump','leap'],
  ['speak','talk'],['finish','end'],['dull','boring'],['safe','secure'],['true','real']
];
const antonymPairs = [
  ['hot','cold'],['up','down'],['happy','sad'],['fast','slow'],['high','low'],
  ['big','small'],['early','late'],['day','night'],['open','closed'],['light','dark'],
  ['hard','soft'],['clean','dirty'],['full','empty'],['young','old'],['wet','dry'],
  ['strong','weak'],['near','far'],['in','out'],['left','right'],['first','last'],
  ['thick','thin'],['long','short'],['loud','quiet'],['brave','afraid'],['safe','risky'],
  ['sweet','sour'],['smooth','rough'],['above','below'],['front','back'],['win','lose']
];
build('synonyms', 2, i => {
  const opposite = i % 2 === 1;
  const pool = opposite ? antonymPairs : synonymPairs;
  const chosen = [];
  let seed = (i * 7919 + 17) >>> 0;
  while (chosen.length < 4) {
    seed = (Math.imul(seed, 1664525) + 1013904223) >>> 0;
    const n = seed % pool.length;
    if (!chosen.includes(n)) chosen.push(n);
  }
  return {
    prompt: opposite ? 'Match words with opposite meanings.' : 'Match words that mean the same.',
    relation: opposite ? 'ANTONYMS' : 'SYNONYMS', time: 65,
    balloons: chosen.flatMap((n, j) => pool[n].map(word => ({word, pair: j + 1})))
  };
});

const nouns = ['fox','bear','child','bird','puppy','artist','teacher','rabbit','tiger','mouse',
  'farmer','sailor','monkey','kitten','painter','dancer','friend','robot','wizard','doctor'];
const verbs = ['finds','carries','holds','paints','watches','moves','opens','draws','follows','builds'];
const objects = [['a','map.'],['the','box.'],['a','kite.'],['the','gate.'],['a','house.']];
build('sentence_train', 2, i => {
  const n = i - 2;
  const answers = ['The', nouns[n % nouns.length], verbs[Math.floor(n / 20) % 10],
    ...objects[Math.floor(n / 200) % 5]];
  const choices = [answers[2], answers[4], answers[0], answers[3], answers[1]];
  return {prompt: 'Arrange the words to make a sentence.', choices, answers, time: 95};
});

const words = [
  'APPLE','BANANA','ORANGE','GRAPES','CHERRY','LEMON','PEACH','MELON','BERRY','PEAR',
  'TIGER','RABBIT','MONKEY','HORSE','ZEBRA','PANDA','SHEEP','GOOSE','MOUSE','WHALE',
  'RIVER','OCEAN','FOREST','GARDEN','FLOWER','MOUNTAIN','DESERT','VALLEY','ISLAND','BRIDGE',
  'SCHOOL','PENCIL','PAPER','BOOK','TABLE','CHAIR','WINDOW','DOOR','CLOCK','LAMP',
  'SUMMER','WINTER','SPRING','AUTUMN','CLOUD','SUNSHINE','RAINBOW','THUNDER','BREEZE','STORM',
  'FRIEND','FAMILY','MOTHER','FATHER','SISTER','BROTHER','CHILD','BABY','PEOPLE','PERSON'
];
build('word_builder', 12, i => {
  const n = i - 12, word = words[n % words.length];
  const variant = Math.floor(n / words.length);
  const target_word = [...word];
  const word_slots = [...target_word];
  const alphabet = 'AEIOUYRSTL';
  const choices = [...new Set([...target_word, ...alphabet])].slice(0, 10);
  if (variant === 16) {
    return {mode:'already_ok', category:'SPELLING CHECK', prompt:'Check this word carefully.',
      word_slots, target_word, choices:['✓ OK'], answers:['✓ OK'], time:55,
      instruction:'Tap the word or WORD IS OK if it is correct.'};
  }
  if (variant < 10) {
    const blank_indices = [];
    if (variant < word.length) blank_indices.push(variant);
    else {
      const pairs = [];
      for (let a = 0; a < word.length; a++)
        for (let b = a + 1; b < word.length; b++) pairs.push([a,b]);
      blank_indices.push(...pairs[(variant - word.length) % pairs.length]);
    }
    for (const index of blank_indices) word_slots[index] = '_';
    return {mode:'missing', category:'MISSING LETTER', prompt:'Complete the word.',
      word_slots, target_word, choices, answers:blank_indices.map(index => target_word[index]), time:60,
      instruction:'Tap the blank, then choose its letter.'};
  }
  const index = (variant - 10) % word.length;
  const wrong = alphabet[(variant + n) % alphabet.length] === target_word[index] ? 'X' : alphabet[(variant + n) % alphabet.length];
  word_slots[index] = wrong;
  return {mode:'fix_mistake', category:'SPELLING MISTAKE', prompt:'Find and fix the wrong letter.',
    word_slots, mistake_index:index, target_word, choices, answers:[target_word[index]], time:65,
    instruction:'Tap the wrong letter, then choose the correct one.'};
});

build('number_bridge', 12, i => {
  const start = 2 + (i * 17) % 87;
  const step = 2 + Math.floor(i / 37) % 28;
  const seq = Array.from({length: 6}, (_, j) => start + j * step);
  const answers = [String(seq[2]), String(seq[4])];
  const choices = [...new Set([...answers, String(seq[2] + 1), String(seq[4] - 1),
    String(seq[4] + step), String(seq[2] - 1)])];
  return {prompt:`Complete the pattern: ${seq[0]}, ${seq[1]}, ?, ${seq[3]}, ?, ${seq[5]}`,
    choices, answers, time:60};
});

build('number_balance', 10, i => {
  const a = 3 + i % 32, b = 4 + Math.floor(i / 32);
  const onRight = i % 3 === 0 ? 1 + i % 8 : 0;
  const answer = a + b - onRight;
  const choices = [...new Set([answer, answer - 2, answer - 1, answer + 1, answer + 2, answer + 4])].map(String);
  return {prompt:'Place one numbered ball on the right pan. Hold the scale balanced for 3 seconds.',
    left_balls:[a,b], right_balls:onRight ? [onRight] : [], max_user_balls:1,
    choices, answers:[String(answer)], time:55};
});

build('number_maze', 4, i => {
  const start = 20 + (i * 7) % 45;
  const addends = [2 + i % 7, 4 + Math.floor(i / 7) % 8,
    3 + Math.floor(i / 53) % 7, 5 + Math.floor(i / 101) % 8];
  let total = start;
  const steps = addends.map((addend, j) => {
    const op = j === 1 || j === 3 ? '-' : '+';
    total += op === '+' ? addend : -addend;
    return {op, addend, target:total};
  });
  const choices = [...new Set([...addends, 1, 9, 11, 13])].slice(0, 7);
  return {prompt:'Combine your number with a tile. Drag it to the glowing stone to cross the maze.',
    start, steps, choices, time:105};
});

const ladders = [
  ['COLD','CORD','CARD','WARD','WARM'],
  ['HEAD','HEAL','TEAL','TELL','TALL','TAIL'],
  ['FALL','FAIL','FOIL','FOWL','BOWL'],
  ['SAND','BAND','BEND','SEND','SEED'],
  ['CAT','COT','DOT','DOG'],
  ['DOG','DIG','FIG','FOG'],
  ['CATS','BATS','BAGS','BUGS'],
  ['MIND','WIND','WINE','LINE'],
  ['FIRE','FIRM','FARM','HARM'],
  ['BOOK','BOOT','BOAT','GOAT']
];
const relayDecoys = [...new Set(ladders.flat())];
build('word_relay', 4, i => {
  const n = i - 4;
  const chain = [...ladders[n % ladders.length]];
  if (Math.floor(n / ladders.length) % 2) chain.reverse();
  const fixed_indices = [0, chain.length - 1];
  if (Math.floor(n / 20) % 2) fixed_indices.push(2);
  const missing = chain.filter((_, j) => !fixed_indices.includes(j));
  const choices = [...missing];
  const decoys = relayDecoys.filter(word => !chain.includes(word));
  let cursor = Math.floor(n / 40) % decoys.length;
  while (choices.length < 6) {
    choices.push(decoys[cursor++ % decoys.length]);
  }
  return {prompt:`Change one letter each step. Drag the missing words from ${chain[0]} to ${chain.at(-1)}.`,
    chain, fixed_indices, choices, time:80};
});

// Number Hunt already has 1,000 authored JSON entries. Add explicit level IDs.
const hunt = read('number_hunt');
hunt.levels = hunt.levels.map((entry, i) => ({...entry, level:i + 1}));
write('number_hunt', hunt);
