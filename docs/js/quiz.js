/* Random ~50-question quiz. Untimed. Answers + explanations shown only after Submit.
   Passage clusters (Reading Comprehension / Cloze) are kept whole: a passage is
   either included in full or not at all, never split across the sample. */
const QUIZ_SIZE = 50;
let pool = [];
let units = [];          // array of question-arrays (singletons or whole clusters)
let current = [];        // flat list of questions in this attempt
let answers = {};        // id -> chosen letter
let submitted = false;
let quizSection = null;  // null = all sections

function $(id){ return document.getElementById(id); }

/* Only answerable questions: not defective-shaped, valid a-d answer, exactly 4 options. */
function gradeablePool() {
  return VT.questions.filter(q =>
    (!quizSection || q.subject === quizSection) &&
    !q.defective &&
    q.answer && LETTERS.includes(q.answer) &&
    (q.options || []).filter(o => o !== '').length === 4
  );
}

/* Group the pool into units: each passage cluster is one unit; each standalone
   question is its own unit. Preserves first-seen order within a cluster. */
function buildUnits(list) {
  const idx = new Map(); const out = [];
  list.forEach(q => {
    const pid = q.passageId;
    if (pid) {
      if (idx.has(pid)) { idx.get(pid).push(q); }
      else { const arr = [q]; idx.set(pid, arr); out.push(arr); }
    } else { out.push([q]); }
  });
  // keep each cluster's questions in paper order
  out.forEach(u => u.sort((a, b) => (a.qno - b.qno)));
  return out;
}

function passageBlock(item) {
  const paras = String(item.passageText || '').split(/\n\n+/).filter(p => p.trim() !== '');
  const body = paras.map(p => `<p>${esc(p)}</p>`).join('');
  const dir = item.directions ? `<div class="passage-dir">${esc(item.directions)}</div>` : '';
  return `<div class="passage-block">
    <div class="passage-label">Passage</div>
    ${dir}
    <div class="passage-text">${body}</div>
  </div>`;
}

function intro() {
  const max = pool.length;
  const backHref = quizSection ? 'browse.html?section=' + encodeURIComponent(quizSection) : 'index.html';
  const scopeTitle = quizSection ? `${esc(quizSection)} - Random Quiz` : `Random Quiz`;
  const scopeText = quizSection
    ? `Pulled at random from <b>${max}</b> answerable ${esc(quizSection)} questions.`
    : `Pulled at random from all <b>${max}</b> answerable questions across every section, type and year.`;
  $('quiz').innerHTML = `
    <div class="quiz-intro">
      <a class="back" href="${backHref}">← Back</a>
      <h2>${scopeTitle}</h2>
      <p>${scopeText} About ${Math.min(QUIZ_SIZE, max)} questions per attempt (whole reading/cloze passages are kept together). Untimed - pick your answers, then <b>Submit</b> to see your score with the correct answers and explanations.</p>
      <button class="btn block" id="start">Start quiz</button>
    </div>`;
  $('start').addEventListener('click', startQuiz);
}

/* Select whole units at random until we reach about QUIZ_SIZE questions. */
function pickQuestions() {
  const shuffled = shuffle(units);
  const chosen = [];
  let count = 0;
  for (const u of shuffled) {
    if (count >= QUIZ_SIZE) break;
    chosen.push(u);
    count += u.length;
  }
  const flat = [];
  chosen.forEach(u => u.forEach(q => flat.push(q)));
  return flat;
}

function startQuiz() {
  current = pickQuestions();
  answers = {};
  submitted = false;
  renderQuiz();
  window.scrollTo({ top: 0, behavior: 'auto' });
}

function quizCard(item, n) {
  const subsHtml = (item.subs && item.subs.length)
    ? `<ul class="subs">${item.subs.map(s => `<li>${esc(s)}</li>`).join('')}</ul>` : '';
  const opts = item.options.map((o, i) => {
    if (o === '') return '';
    const L = LETTERS[i];
    return `<label class="opt quiz-opt" data-letter="${L}">
      <input type="radio" name="q_${esc(item.id)}" value="${L}">
      <span class="ol">${L})</span><span>${esc(o)}</span>
    </label>`;
  }).join('');
  const stemHtml = item.stem ? `<div class="qstem">${esc(item.stem)}</div>` : '';
  return `<article class="qcard" data-id="${esc(item.id)}">
    <div class="qtop">
      <span class="tag">Q${n}</span>
      <span class="qmeta"><span class="tag topic">${esc(item.subject)}${item.subtopic ? ' · ' + esc(item.subtopic) : ''}</span></span>
    </div>
    ${stemHtml}
    ${subsHtml}
    <div class="opts">${opts}</div>
    <div class="reveal" hidden></div>
  </article>`;
}

function renderQuiz() {
  const wrap = $('quiz');
  let cards = '';
  let lastPid = '';
  current.forEach((q, i) => {
    if (q.passageId && q.passageId !== lastPid) { cards += passageBlock(q); }
    lastPid = q.passageId || '';
    cards += quizCard(q, i + 1);
  });
  wrap.innerHTML = `
    <div class="quizbar">
      <span class="prog" id="prog">0 / ${current.length} answered</span>
      <button class="btn" id="submit">Submit quiz</button>
    </div>
    <div id="qlist">${cards}</div>
    <button class="btn block" id="submit2" style="margin-top:8px">Submit quiz</button>`;

  wrap.querySelectorAll('input[type=radio]').forEach(r => {
    r.addEventListener('change', e => {
      const id = e.target.name.slice(2);
      answers[id] = e.target.value;
      updateProgress();
    });
  });
  $('submit').addEventListener('click', submitQuiz);
  $('submit2').addEventListener('click', submitQuiz);
  updateProgress();
}

function updateProgress() {
  if (submitted) return;
  $('prog').textContent = `${Object.keys(answers).length} / ${current.length} answered`;
}

function submitQuiz() {
  if (submitted) return;
  const unanswered = current.length - Object.keys(answers).length;
  if (unanswered > 0 &&
      !confirm(`${unanswered} question(s) are unanswered and will be marked wrong. Submit anyway?`)) {
    return;
  }
  submitted = true;
  let correct = 0;

  current.forEach(item => {
    const card = document.querySelector(`.qcard[data-id="${cssEsc(item.id)}"]`);
    const chosen = answers[item.id];
    const right = item.answer;
    if (chosen === right) correct++;

    card.classList.add('answered');
    card.querySelectorAll('input[type=radio]').forEach(r => r.disabled = true);
    const correctEl = card.querySelector(`.opt[data-letter="${right}"]`);
    if (correctEl) correctEl.classList.add('correct');
    if (chosen && chosen !== right) {
      const wrongEl = card.querySelector(`.opt[data-letter="${chosen}"]`);
      if (wrongEl) wrongEl.classList.add('chosen-wrong');
    }
    const reveal = card.querySelector('.reveal');
    const idx = LETTERS.indexOf(right);
    let html = `<div class="ans">Correct: ${right}) ${esc(item.options[idx] || '')}</div>`;
    if (!chosen) html += `<div class="note">You did not answer this question.</div>`;
    if (item.explanation) html += `<div class="expl">${esc(item.explanation)}</div>`;
    html += `<div class="expl" style="margin-top:6px;color:#6b7585">${esc(item.paper)}</div>`;
    reveal.innerHTML = html;
    reveal.hidden = false;
  });

  const pct = Math.round((correct / current.length) * 100);
  const bar = `
    <div class="scorecard">
      <div class="big">${correct} / ${current.length}</div>
      <div class="pct">${pct}% correct</div>
      <div class="meta">Scroll down to review every question with the correct answer and explanation.</div>
      <div style="margin-top:14px"><button class="btn" id="again">Take a new quiz</button></div>
    </div>`;
  const qlist = $('qlist');
  qlist.insertAdjacentHTML('beforebegin', bar);
  $('again').addEventListener('click', startQuiz);

  $('prog').textContent = `Score: ${correct} / ${current.length}`;
  $('submit').textContent = 'New quiz';
  $('submit').onclick = startQuiz;
  const s2 = $('submit2'); if (s2) s2.remove();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* CSS.escape fallback for older browsers */
function cssEsc(s) {
  return (window.CSS && CSS.escape) ? CSS.escape(s) : s.replace(/[^a-zA-Z0-9_-]/g, '\\$&');
}

async function init() {
  initBanner();
  try {
    await loadManifest();
    const param = new URLSearchParams(location.search).get('section');
    quizSection = param && VT.manifest.subjects.some(s => s.name === param) ? param : null;
    await loadSubjects(quizSection ? [quizSection] : VT.manifest.subjects.map(s => s.name));
  } catch (err) {
    $('quiz').innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }
  pool = gradeablePool();
  units = buildUnits(pool);
  if (!pool.length) {
    $('quiz').innerHTML = `<div class="empty">No answerable questions available yet.</div>`;
    return;
  }
  intro();
}
document.addEventListener('DOMContentLoaded', init);
