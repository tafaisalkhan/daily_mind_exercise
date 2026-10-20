const assert = require('assert');
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '../../assets/data/game_types');
const names = ['synonyms','word_builder','sentence_train','number_bridge',
  'number_balance','number_maze','number_hunt','word_relay'];
for (const name of names) {
  const data = JSON.parse(fs.readFileSync(path.join(root, name + '.json'), 'utf8'));
  assert.strictEqual(data.levels.length, 1000, `${name}: count`);
  const puzzleKeys = data.levels.map(level => JSON.stringify(Object.fromEntries(
    Object.entries(level).filter(([key]) => !['level','time','prompt','instruction'].includes(key)))));
  assert.strictEqual(new Set(puzzleKeys).size, 1000, `${name}: repeated challenge`);
  data.levels.forEach((level, index) => {
    assert.strictEqual(level.level, index + 1, `${name}: level ID ${index + 1}`);
    assert(level.time > 0, `${name}: timer ${index + 1}`);
    if (name === 'synonyms') {
      const pairs = new Map();
      for (const balloon of level.balloons) pairs.set(balloon.pair, (pairs.get(balloon.pair) || 0) + 1);
      assert([...pairs.values()].every(count => count === 2), `${name}: pairs ${index + 1}`);
    } else if (name === 'word_builder') {
      assert(level.target_word.length > 0, `${name}: word ${index + 1}`);
      if (level.mode === 'missing' || level.mode === 'fix_mistake') {
        for (const answer of level.answers) assert(level.choices.includes(answer), `${name}: choice ${index + 1}`);
      }
    } else if (name === 'sentence_train' || name === 'number_bridge') {
      for (const answer of level.answers) assert(level.choices.includes(answer), `${name}: choice ${index + 1}`);
    } else if (name === 'number_balance') {
      const left = level.left_balls.reduce((a,b) => a+b, 0);
      const right = level.right_balls.reduce((a,b) => a+b, 0);
      const answer = level.answers.reduce((a,b) => a+Number(b), 0);
      assert.strictEqual(left, right + answer, `${name}: balance ${index + 1}`);
      for (const value of level.answers) assert(level.choices.includes(value), `${name}: choice ${index + 1}`);
    } else if (name === 'number_maze') {
      let value = level.start;
      for (const step of level.steps) {
        assert(level.choices.includes(step.addend), `${name}: tile ${index + 1}`);
        value += step.op === '+' ? step.addend : -step.addend;
        assert.strictEqual(value, step.target, `${name}: target ${index + 1}`);
      }
    } else if (name === 'number_hunt') {
      assert(level.questions.length >= level.catches, `${name}: questions ${index + 1}`);
      for (const question of level.questions)
        assert(question.numbers.includes(question.answer), `${name}: orb ${index + 1}`);
    } else if (name === 'word_relay') {
      for (let j = 1; j < level.chain.length; j++) {
        const changes = [...level.chain[j]].filter((c, k) => c !== level.chain[j-1][k]).length;
        assert.strictEqual(changes, 1, `${name}: word ladder ${index + 1}`);
      }
      for (let j = 0; j < level.chain.length; j++) {
        if (!level.fixed_indices.includes(j))
          assert(level.choices.includes(level.chain[j]), `${name}: missing word ${index + 1}`);
      }
    }
  });
  console.log(`${name}: 1000 valid levels`);
}
