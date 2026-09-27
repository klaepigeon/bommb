// RHAPSODY — dialogue. RDR2-style Greet / Antagonize / Defuse with personality-driven
// reactions, plus scripted talk trees by role. No free text: every exchange is a choice.
'use strict';
(function () {
  const D = R.data, TS = R.TILE;
  const G = () => R.game;
  const pick = (a) => a[Math.floor(R.rng() * a.length)];

  const L = {
    woken: ["Who's there?!", 'Honey, wake up! Someone\'s in the house!', 'I got a bat and I know how to use it!', 'Burglar! BURGLAR!'],
    getup: ['Ugh... my head.', 'What hit me?', 'Where am I?', "I'm calling my lawyer."],
    fleeing: ["He's crazy!", 'Run!', 'Somebody call the cops!', 'Not today, not today!', 'Mama!'],
    cower: ["Don't shoot! Please!", 'I got kids!', "I didn't see nothing!", 'Take whatever you want!', 'Please, mister...'],
    seeGun: ['Gun! He\'s got a gun!', 'Whoa, whoa, put that away!', "I'm outta here."],
    standoff: ["You don't scare me.", 'Go ahead. Try it.', 'Two can play that game.'],
    seeMask: ['Little early for Halloween, pal.', 'Why the mask?', "I don't like the look of this."],
    rivalSpot: ["That's one of Vane's boys!", 'Wrong side of town, mook.', 'Get him!'],
    grudge: ['You! You killed my family!', "I know what you did. You're gonna pay.", 'Murderer!'],
    copWarnGun: ['Holster that weapon. Now.', 'Put it away, pal.', "Don't make me draw on you."],
    copWarnMinor: ["I saw that. Don't let me see it again.", 'Knock it off, or you\'re coming downtown.', 'Last warning, wise guy.'],
    copSaw: ['Police! Freeze!', 'Hold it right there!', "That's it, you're under arrest!"],
    copOk: ['Smart choice.', 'Keep it that way.'],
    copInvestigate: ['Shots fired, checking it out.', 'What was that?', 'Dispatch, investigating a disturbance.'],
    recognise: ["Hold on... I know that face.", 'You match a description.', "Well well. Look who's wanted."],
    arrest: ['Hands where I can see them!', "You're under arrest. Don't make this harder.", 'On your knees. Slowly.'],
    radio: ['Unit responding, code three.', 'En route to the last known location.', 'Copy that, rolling.'],
    reportCop: ['Officer! That man just— he did something terrible!', "Officer, I saw it all! It was a big guy in a fedora!"],
    reportPhone: ['Operator? Get me the police!', 'Hello, police? I need to report a crime!', 'Yes, I saw the whole thing. Hurry!'],
    witness: ["I'm telling the cops!", 'I saw that! Police!', 'Somebody call the law!', "You're going away for that!"],
    sawNothing: ["I didn't see a thing.", 'None of my business.', 'Eyes on the ground, mouth shut.', 'Nice day, huh? Real quiet.'],
    hero: ["Stop right there, creep!", "Not in my neighborhood!", 'I got you now!'],
    tut: ['Real mature.', 'Hooligan.', 'Tsk.', 'Somebody oughta tell your mother.'],
    fightBack: ["You're gonna regret that!", 'Oh, you want some?', "That's it!", 'Big mistake, pal.'],
    beg: ['Okay! Okay! I give!', "Please, I've had enough!", "Don't kill me!", 'Uncle! UNCLE!'],
    hurt: ['Ow! What the hell?!', 'Are you nuts?!', 'Help! Help!'],
    hitByCar: ['Watch where you\'re driving!', 'My leg!', 'Maniac!', 'Learn to drive!'],
    driverYell: ['Move it, pal!', 'Get outta the road!', 'Some of us got places to be!', 'You deaf?!'],
    roadRage: ['Hey! You got a problem?!', "Let's settle this, tough guy!", 'Get outta the car!', 'You scratched my paint!'],
    crashSmall: ['My fender!', "Hey! You'll pay for that!", 'Watch it, jerk!'],
    crashBig: ['You wrecked my car!', "I'm gonna kill you!", 'My insurance!'],
    honkedAt: ['Alright, alright!', 'Keep your shirt on!', 'Jeez!'],
    fire: ['Fire! FIRE!', 'Somebody call the fire department!', "It's spreading!"],
    wet: ['Hey! My hair!', 'Yee-haw, free shower!', "It's a flood!"],
    cheer: ['Hit him!', 'Ooh, that\'s gotta hurt!', 'Five bucks on the big guy!', 'Get him!', 'Fight! Fight!'],
    wedding: ['Congratulations!', 'Kiss the bride!', 'Throw the bouquet!', "Isn't it lovely?"],
    perform: ['This one\'s for the lovers.', 'Spare a dime for the music?', 'Everybody dance now!'],
    preach: ['Repent! The end is near!', 'The Lord sees your sideburns, sinner!', 'Disco is the devil\'s music!'],
  };

  const D2 = (R.dialog = {});
  D2.line = function (kind, h) {
    const arr = L[kind] || ['...'];
    let s = pick(arr);
    const fam = G() && G().player && G().player.family;
    if (kind === 'rivalSpot') s = s.replace('Vane', fam || 'Vane');
    return s;
  };

  // ---------------------------------------------------------------- ambient chatter
  const CHAT = {
    any: ['You catch the game last night?', "Rent's up again.", 'This heat, huh?', 'Have you seen my cat?', 'They say the bank never sleeps.', 'Lotta new faces in town.', 'Gas is 60 cents a gallon now. Criminal.', 'My cousin knows a guy.', 'You still dating that drummer?', 'Heard the Castellanos and the Vanes are feuding again.'],
    rain: ['Raining cats and dogs.', 'Forgot my umbrella, as usual.', 'Good for the crops, bad for my hair.'],
    night: ['Streets ain\'t safe after dark.', "Club Neon's jumping tonight.", 'Walk me home?'],
    reply: ['Tell me about it.', 'You don\'t say.', 'Mm-hmm.', 'No kidding.', 'Ain\'t that the truth.', 'Get outta here!', 'Same old, same old.', 'Far out.'],
  };
  D2.chatter = function (h, o) {
    const g = G();
    if (h.person && o.person && h.person.spouse === o.person.id) return pick(['Honey, did you lock the door?', 'Love you, baby.', 'We\'re late for dinner at your mother\'s.']);
    if (h.person && o.person && R.rng() < 0.4) return `${o.person.first}! ${pick(['How\'s the family?', 'Long time no see.', 'You owe me five bucks.', 'Looking sharp.'])}`;
    if (h.person && R.rng() < 0.35) return g.pop.lifeFact(h.person);
    if (g.env.weather.rain > 0.4 && R.rng() < 0.5) return pick(CHAT.rain);
    if (g.clock.isNight() && R.rng() < 0.4) return pick(CHAT.night);
    const news = g.pop.news.find((n) => n.city === (h.person ? h.person.city : '') && g.pop.day - n.day < 2);
    if (news && R.rng() < 0.4) return `Did you hear? ${news.text}`;
    if (g.player.rep.infamy > 30 && R.rng() < 0.2) return pick(['That mook in the fedora? Word is he\'s trouble.', 'Folks say there\'s a new heavy in town.']);
    return pick(CHAT.any);
  };
  D2.chatterReply = function () { return pick(CHAT.reply); };

  // things people say as the player walks by
  D2.passing = function (h, pl) {
    const g = G();
    if (h.cop) return pick(g.law.totalBounty() > 0 ? ['Keep moving.', "I'm watching you."] : ['Evening.', 'Stay out of trouble.', 'Move along.']);
    if (pl.masked) return pick(['Nice mask. Real subtle.', 'What\'s with the ski mask?', "I'm not looking at you."]);
    if (pl.bloody > 0.3) return pick(['Is that... blood?', 'Rough night, mister?', "You're bleeding on my sidewalk."]);
    if (pl.drunk > 0.4) return pick(['Somebody\'s had a few.', 'Walk it off, pal.', 'Smells like a distillery.']);
    if (h.person && h.person.met) {
      const op = h.person.opinion;
      if (op > 40) return pick([`Hey, ${pl.nick}!`, 'Look who it is!', `Lookin' sharp, ${pl.nick}.`]);
      if (op < -30) return pick(['Oh. You.', 'Keep walking.', "Don't talk to me."]);
    }
    if (pl.rep.infamy > 60) return pick(["That's him. Don't make eye contact.", 'Sir.', 'Good evening, sir. Sir.']);
    if (pl.style && pl.style.hat === 'fedora') return pick(['Nice lid.', 'Who do you think you are, Sinatra?', 'Sharp hat, mister.']);
    if (pl.style && pl.style.facial === 'stache') return pick(['Nice lip caterpillar.', 'That moustache is working for you.']);
    if (pl.outfit === 'tux') return pick(['Wedding or funeral?', 'Nice tux, Travolta.']);
    if (pl.outfit === 'leisure') return pick(['Groovy threads.', 'Is that polyester?']);
    return pick(['Nice suit.', 'Hey.', 'Watch it.', 'Scuse me.', 'Evening.', 'Nice hat.', 'You lost?', 'Afternoon.']);
  };

  // ---------------------------------------------------------------- greet / antagonize
  const PGREET = ['How ya doin\'?', 'Evenin\'.', 'Nice day, huh?', 'Hey there.', 'How\'s it going, friend?', 'Looking good.'];
  const PANTAG = ['What are you lookin\' at?', 'Nice shoes. Your mother pick \'em?', 'You got a problem?', 'Get outta my way.', 'You smell like a fish market.', 'Hey, stupid.', 'You got some nerve standing there.'];
  const PDEFUSE = ['Relax, I\'m just messin\' with ya.', 'Hey, no hard feelings.', 'Easy, easy. We\'re good.'];

  const RESP = {
    warm: ['Well if it ain\'t my favorite fella!', 'Hey you! Good to see ya.', 'Always a pleasure.', 'There he is!'],
    nice: ['Doing alright, thanks.', 'Can\'t complain.', 'Evening to you too.', 'Hey yourself.', 'Nice hat, by the way.'],
    shy: ['Oh! Uh, hi.', 'H-hello.', '...hi.'],
    cold: ['Do I know you?', 'Mm.', 'Sure, whatever.', 'Not interested.', 'Keep walking.'],
    scared: ['P-please, I don\'t want trouble.', 'Yes sir. Hello sir.', 'Whatever you say, mister.'],
    flirt: ['Well hello, handsome.', 'Nice suit. Buy a girl a drink sometime?', 'Aren\'t you a tall glass of trouble.'],
    grumpy: ['What do you want?', 'Yeah, yeah.', 'Don\'t block the sidewalk.'],
    cop: ['Citizen.', 'Keep your nose clean.', 'Evening. Everything alright?'],
    kid: ['Hi mister!', 'Is that a real fedora?', 'My dad says don\'t talk to strangers.'],
    family: ['Hey, it\'s the new guy. Don Vane says hello.', 'Look sharp, kid.', 'You working today?'],
  };
  const ANTRESP = {
    cower: ['I-I\'m sorry! I\'ll move!', 'Please, I don\'t want no trouble!', 'Here, take my wallet, just leave me alone!'],
    retort: ['Nice suit. Did the circus let you keep it?', 'At least my face ain\'t a crime.', 'Go bother somebody your own size.', 'Wow. Did you think of that yourself?', 'Take a hike, fedora.'],
    laugh: ['Ha! You\'re a riot.', 'Whatever you say, sunshine.', 'Aww, somebody needs a hug.'],
    squareUp: ['You wanna go? Let\'s go!', 'Say that again. I dare you.', 'Put \'em up!', 'Big mistake, pal.'],
    cop: ['Keep walking, wise guy.', 'You want a night in the tank?', 'Say that again. Slower.'],
    copArrest: ['That\'s it. Hands behind your back.', 'Disorderly conduct. You\'re coming with me.'],
    kid: ['I\'m telling my mom!', 'Meanie!', 'Waaah!'],
    walkOff: ['Unbelievable.', 'I don\'t have time for this.', 'Ugh. Men.'],
  };

  D2.mood = function (h) {
    const g = G(), pl = g.player;
    const p = h.person;
    let m = (p ? p.opinion : 0) + h.tr.warm * 30 - 10;
    const city = g.world.cityAt((h.x / TS) | 0, (h.y / TS) | 0);
    if (city) m += (pl.standing[city.id] || 0) * 0.3;
    if (pl.masked) m -= 40;
    if (pl.weaponOut) m -= 45;
    if (pl.bloody > 0.3) m -= 25;
    if (R.goods.has(pl, 'mellow')) m += 15;
    if (h.anger) m -= h.anger;
    m += pl.outfitScore();
    return m;
  };
  D2.fear = function (h) {
    const g = G(), pl = g.player;
    let f = (h.person ? h.person.fear : 0) + pl.rep.infamy * 0.4 + (pl.weaponOut ? 50 : 0) + (pl.masked ? 20 : 0) - h.tr.brave * 60;
    if (h.cop) f -= 80;
    return f;
  };

  // player greets h. Returns true if handled
  D2.greet = function (h) {
    const g = G(), pl = g.player, p = h.person;
    g.actors.say(pl, pick(PGREET));
    h.state = 'talk';
    h.timer = 5;
    const mood = this.mood(h), fear = this.fear(h);
    const spam = h.greeted > 1;
    h.greeted++;
    let resp;
    if (h.look.kid) resp = pick(RESP.kid);
    else if (h.cop) resp = pick(RESP.cop);
    else if (fear > 40) resp = pick(RESP.scared);
    else if (h.faction && h.faction === pl.family) resp = pick(RESP.family).replace('Vane', g.jobs.donName(pl.family));
    else if (spam) resp = pick(['Yeah, you said that already.', 'Hello again...', 'You\'re a friendly one, huh?']);
    else if (mood > 35) resp = h.arch === 'flirt' && h.look.fem !== pl.look.fem ? pick(RESP.flirt) : pick(RESP.warm);
    else if (mood > 5) resp = h.arch === 'timid' ? pick(RESP.shy) : h.arch === 'flirt' ? pick(RESP.flirt) : pick(RESP.nice);
    else if (h.arch === 'grumpy') resp = pick(RESP.grumpy);
    else resp = pick(RESP.cold);
    setTimeout(() => {
      if (h.dead || h.removed) return;
      g.actors.say(h, resp);
      // chatty people add something
      if (p && !spam && mood > 0 && R.rng() < h.tr.chatty * 0.7) setTimeout(() => !h.dead && g.actors.say(h, R.rng() < 0.5 ? g.pop.lifeFact(p) : D2.rumor(h)), 1800);
      else if (!p && !spam && mood > 10 && R.rng() < 0.25) setTimeout(() => !h.dead && g.actors.say(h, D2.rumor(h)), 1800);
    }, 700);
    if (p && !spam) {
      if (p.lastGreet !== g.pop.day) { p.opinion = Math.min(100, p.opinion + (mood > 0 ? 4 : 1)); p.lastGreet = g.pop.day; }
      p.fam = Math.min(10, p.fam + 1);
      if (p.fam >= 2 && !p.met) {
        p.met = true;
        setTimeout(() => g.ui.toast(`You know ${g.pop.name(p)} now: ${g.pop.title(p)}${p.work ? ' at ' + g.world.buildings[p.work].name : ''}.`, 'good'), 1500);
      }
    } else if (!p && !h.strangerName && mood > 15 && R.rng() < 0.5) {
      h.strangerName = `${pick(h.look.fem ? D.firstF : D.firstM)} (stranger)`;
    }
    if (!spam) pl.rep.honor = Math.min(100, pl.rep.honor + 0.2);
    h.greetMood = mood;
    return true;
  };

  D2.antagonize = function (h) {
    const g = G(), pl = g.player, p = h.person;
    g.actors.say(pl, pick(PANTAG));
    h.anger = (h.anger || 0) + 25;
    h.antag = (h.antag || 0) + 1;
    const fear = this.fear(h);
    let resp, after = null;
    if (h.look.kid) { resp = pick(ANTRESP.kid); after = () => g.actors.setFlee(h, pl, 6); }
    else if (h.cop) {
      if (h.antag >= 2) { resp = pick(ANTRESP.copArrest); after = () => g.law.startIncident({ type: 'harass', def: { name: 'Disorderly Conduct' }, x: pl.x, y: pl.y, jur: g.law.jurAt(pl.x, pl.y), identified: !pl.masked, lvl: 1, bounty: 5 }, h); }
      else resp = pick(ANTRESP.cop);
    } else if (fear > 35 || h.tr.brave < 0.25) {
      resp = pick(ANTRESP.cower);
      h.intimidated = true;
      if (h.antag >= 2) after = () => g.actors.setFlee(h, pl, 8);
      else { h.state = 'cower'; h.timer = 6; }
    } else if (h.tr.brave > 0.65 || (h.antag >= 2 && h.tr.brave > 0.4) || h.anger > 60) {
      resp = pick(ANTRESP.squareUp);
      after = () => {
        h.brawl = true; // mutual fight: not a crime while fists stay fists
        h.hostile = true;
        g.actors.setFight(h, pl);
        if (h.armed && h.tr.brave > 0.85 && h.weapon !== 'rifle') { h.drawn = true; g.ui.toast(`${g.actors.displayName(h)} pulled a ${D.weapons[h.weapon].name}! Self-defence is fair game.`, 'warn'); }
        else if (h.armed) { h.drawn = false; h.brawlFists = true; h.armedBackup = h.weapon; h.weapon = 'fists'; }
        g.actors.noise(h.x, h.y, TS * 8, 'fight', h);
      };
    } else if (h.arch === 'flirt' || h.arch === 'eccentric') resp = pick(ANTRESP.laugh);
    else if (h.antag >= 2) { resp = pick(ANTRESP.walkOff); after = () => g.actors.setFlee(h, pl, 4); }
    else resp = pick(ANTRESP.retort);
    h.state = h.state === 'cower' ? 'cower' : 'talk';
    h.timer = h.timer || 5;
    setTimeout(() => {
      if (h.dead || h.removed) return;
      g.actors.say(h, resp);
      if (after) after();
    }, 700);
    if (p) {
      p.opinion = Math.max(-100, p.opinion - 8);
      p.fear = Math.min(100, p.fear + 10);
      if (h.antag === 1) g.pop.remember(p, 'antag', `Some wise guy in a fedora mouthed off at me.`, g.pop.day);
    }
    pl.rep.infamy = Math.min(100, pl.rep.infamy + 0.3);
    return true;
  };
  D2.defuse = function (h) {
    const g = G(), pl = g.player;
    g.actors.say(pl, pick(PDEFUSE));
    const ok = R.rng() < 0.75 - (h.anger || 0) / 250 + h.tr.warm * 0.3;
    setTimeout(() => {
      if (h.dead || h.removed) return;
      if (ok) {
        h.anger = 0;
        h.hostile = false;
        h.brawl = false;
        if (h.brawlFists) { h.weapon = h.armedBackup; h.brawlFists = false; }
        h.state = 'idle';
        h.timer = 2;
        g.actors.say(h, pick(['Yeah, alright. Watch yourself.', 'Hmph. Fine.', 'You\'re lucky I\'m in a good mood.', 'Whatever, pal.']));
      } else g.actors.say(h, pick(['Too late for that!', 'Nah, you started this.']));
    }, 600);
  };

  // rumours and leads generated from world state
  D2.rumor = function (h) {
    const g = G();
    const leads = g.jobs.makeLead(h);
    if (leads) return leads;
    return pick(['Nothing new under the sun.', 'I keep my head down, mister.', 'Ask the bartender. They hear everything.']);
  };

  // ---------------------------------------------------------------- talk tree
  // Returns { title, sub, lines:[], options:[{label, fn, close}] }
  // RDR2-style Stop Witness: scare them quiet or pay them off
  D2.bribePrice = (h) => 15 + Math.round((h.witness && h.witness.crime.bounty) || 10);
  D2.stopWitness = function (h, how, sayFn) {
    const g = G(), pl = g.player, p = h.person;
    const say = sayFn || ((t) => g.actors.say(h, t));
    if (!h.witness || h.witness.done || h.witness.silenced) return;
    const silence = (state) => {
      h.witness.silenced = true; h.alert = null; h.state = state; h.timer = 6; h.goal = null;
      g.ui.toast('Witness silenced.', 'good');
      g.audio.sfx(how === 'bribe' ? 'cash' : 'punch');
    };
    if (how === 'bribe') {
      const price = D2.bribePrice(h);
      if (pl.cash < price) { say("That ain't enough to make me forget."); return false; }
      const ok = R.rng() < 0.65 + h.tr.greed * 0.4 - h.tr.lawful * 0.35;
      if (!ok) { say(pick(["Keep your blood money. I'm calling the cops.", 'You think I can be bought?!'])); h.hurry = true; g.actors.startReport(h); return; }
      pl.cash -= price;
      say(pick(['...What crime? I was looking at pigeons.', 'Pleasure doing business. Never saw you.', 'My eyes aren\'t what they used to be.']));
      if (p) { p.opinion = Math.min(100, p.opinion + 4); g.pop.remember(p, 'bribed', 'A man in a sharp suit paid me to forget something.', g.pop.day); }
      silence('idle');
      return;
    }
    const w = D.weapons[pl.weapon];
    const odds = 0.3 + D2.fear(h) / 100 + (pl.weaponOut && w && w.gun ? 0.3 : pl.weaponOut ? 0.15 : 0) + pl.rep.infamy / 300 - h.tr.brave * 0.3 + (h.state === 'cower' || h.state === 'surrender' ? 0.3 : 0) + (pl.masked ? 0.05 : 0);
    if (R.rng() < odds) {
      say(pick(['O-okay! I saw nothing! Nothing!', 'I didn\'t see a thing, I swear on my mother!', 'Please! I got kids! I won\'t say a word!']));
      if (p) { p.fear = Math.min(100, (p.fear || 0) + 50); p.opinion = Math.max(-100, p.opinion - 20); g.pop.remember(p, 'threatened', 'A goon threatened me into keeping quiet.', g.pop.day); }
      silence('cower');
    } else if (h.tr.brave > 0.7 && !h.cop) {
      say(pick(["You don't scare me!", 'Try it, tough guy!'])); h.hostile = true; g.actors.setFight(h, pl);
    } else {
      say(pick(['Help! HELP! Somebody call the cops!', 'Get away from me!'])); h.hurry = true; g.actors.startReport(h);
    }
  };
  D2.tree = function (h) {
    if (h.fearman) return R.ring.fearTree(h);
    if (h.legend && R.legends) return R.legends.tree(h);
    const g = G(), pl = g.player, p = h.person;
    const name = g.actors.displayName(h);
    const opts = [];
    const lines = [];
    const mood = this.mood(h);
    const close = () => g.ui.closeTalk();
    const say = (s) => g.ui.talkLine(s);
    const role = h.role;
    // witnesses can be paid off
    if (h.witness && !h.witness.done && !h.witness.silenced) {
      opts.push({ label: `"Here's ${R.fmtMoney(D2.bribePrice(h))}. You didn't see nothin'."`, fn: () => { if (D2.stopWitness(h, 'bribe', say) !== false) close(); } });
      opts.push({ label: '"Talk and you\'re next."', fn: () => { D2.stopWitness(h, 'intimidate', say); close(); } });
    }
    const job = g.jobs.active;
    if (p && job && job.person === p.id && (job.kind === 'collect' || job.kind === 'scare')) {
      if (job.kind === 'collect' && p.debt > 0) opts.push({ label: `"Don ${g.jobs.donName(job.family)} wants his ${R.fmtMoney(p.debt)}."`, cls: 'go', fn: () => {
        const f = D2.fear(h) + (h.intimidated ? 30 : 0) + (p.fear || 0) * 0.5;
        if (f > 25 || R.rng() < 0.25) { const amt = p.debt; p.debt = 0; say(`Okay, okay! Here's the ${R.fmtMoney(amt)}. Tell him I'm sorry!`); p.fear = Math.min(100, p.fear + 20); }
        else if (h.tr.brave > 0.6) { say("I ain't paying nothing. Come and take it."); close(); h.hostile = true; h.brawl = true; g.actors.setFight(h, pl); }
        else { say("I don't have it! Give me a week!"); h.intimidated = false; p.fear += 10; }
      } });
      if (job.kind === 'scare') opts.push({ label: '"Keep talking to the cops and see what happens."', cls: 'go', fn: () => { p.fear = Math.min(100, p.fear + 35 + (pl.weaponOut ? 25 : 0)); say(p.fear >= 70 ? "I... I won't say another word. I swear on my mother." : 'You think I scare that easy?'); } });
    }
    if (p) {
      lines.push(`${g.pop.title(p)}, age ${p.age}${p.work ? ' · ' + g.world.buildings[p.work].name : ''}`);
      opts.push({ label: '"How\'s life treating you?"', fn: () => say(g.pop.lifeFact(p)) });
      if (p.fam >= 2 || h.tr.chatty > 0.7) opts.push({ label: '"Heard anything worth knowing?"', fn: () => say(D2.rumor(h)) });
      if (p.spouse >= 0 || p.kids.length) opts.push({ label: '"How\'s the family?"', fn: () => {
        const fam = g.pop.family(p).filter(([r]) => r !== 'parent');
        if (!fam.length) return say('It\'s just me these days.');
        const [rel, q] = pick(fam);
        say(q.alive ? `${q.first}? ${rel === 'kid' ? `${q.age} years old${q.age >= 18 ? ', works as a ' + (D.roleNames[q.role] || 'something').toLowerCase() : ''}.` : ''} ${pick(['Keeps me young.', 'Drives me crazy.', 'Best thing that ever happened to me.'])}` : `${q.first} passed. Don't want to talk about it.`);
      } });
    } else lines.push(h.cop ? 'Police officer' : h.look.kid ? 'A neighborhood kid' : 'A stranger');
    // dealers, and people who'll work for you
    if (h.dealer) opts.unshift({ label: '"What are you selling?"', cls: 'go', fn: () => { close(); R.goods.openDealer(h); } });
    if (R.goods.canHire(h)) opts.push({ label: '"Got some work, if you want it."', small: 'Hire them for an errand', fn: () => { close(); R.goods.openHire(h); } });
    // role services
    if (h.arch === 'hustler' && !h.staff) opts.push({ label: 'Shoot dice ($10)', fn: () => { close(); R.mini.dice({ stake: 10 }); } });
    if (role === 'bartender') {
      opts.push({ label: 'Order a whiskey ($3)', fn: () => { if (pl.pay(3)) { pl.drink(); say(pick(['Here ya go.', 'On the rocks.', 'Easy does it, champ.'])); } else say('Cash first.'); } });
      opts.push({ label: '"Heard any strange stories?"', fn: () => say(R.legends.rumor()) });
      opts.push({ label: 'Throw darts with the regulars ($10)', fn: () => { close(); R.mini.darts({ stake: 10 }); } });
      opts.push({ label: 'Buy the room a round ($25)', fn: () => { if (pl.pay(25)) { g.jobs.roundForHouse(h); say('Drinks are on the fella in the fedora!'); } else say('With what money?'); } });
    }
    if (role === 'fence') opts.push({ label: 'Move some merchandise', fn: () => { close(); g.ui.openShop('pawn', h); } });
    if (role === 'doctor' || role === 'nurse') opts.push({ label: 'Patch me up ($20)', fn: () => { if (pl.hp >= pl.maxHp) return say('You look fine to me.'); if (pl.pay(20)) { pl.hp = pl.maxHp; pl.bloody = 0; say('Good as new. Try ducking next time.'); } else say('Hospitals cost money, sweetie.'); } });
    if (role === 'priest') opts.push({ label: 'Confess your sins ($40 donation)', fn: () => { if (pl.pay(40)) { pl.rep.infamy = Math.max(0, pl.rep.infamy - 8); pl.rep.honor = Math.min(100, pl.rep.honor + 5); say('Say ten Hail Marys and stop hitting people.'); } else say('The Lord accepts IOUs. The church does not.'); } });
    if (role === 'mechanic') opts.push({ label: 'Fix my ride', fn: () => { close(); g.ui.openShop('garage', h); } });
    if (role === 'cop' || role === 'detective') {
      const jur = g.law.jurAt(h.x, h.y);
      const b = g.law.bounty[jur] || 0;
      if (b > 0) opts.push({ label: `Pay my bounty (${R.fmtMoney(b)})`, fn: () => { if (g.law.payBounty(jur)) say('Paid in full. Now scram.'); else say("You don't have that kind of cash."); } });
      opts.push({ label: '"Anything I should know, officer?"', fn: () => say(pick([`We're looking for somebody who ${g.law.log[0] ? 'did a ' + g.law.log[0].def.name.toLowerCase() : 'keeps making trouble'}. Seen anything?`, 'Quiet shift. Keep it that way.', `The ${g.jobs.cityFamily(h) || 'mob'} thinks they run this town. They don't.`])) });
      if (pl.cash >= 100 && D2.mood(h) > -20) opts.push({ label: 'Slip him $100 to look the other way', fn: () => {
        if (h.tr.lawful > 0.8) { say('Are you trying to bribe an officer? Beat it before I change my mind.'); if (p) p.opinion -= 20; return; }
        pl.cash -= 100; g.law.bounty[jur] = Math.max(0, (g.law.bounty[jur] || 0) - 80); say('Pleasure doing business. I never saw you.'); if (p) { p.opinion += 10; p.bribed = true; }
      } });
    }
    if (role === 'don' || role === 'capo') opts.push({ label: '"Got any work for me?"', fn: () => { close(); g.jobs.openBoard(h); } });
    if ((role === 'clerk' || role === 'cook' || role === 'barber' || role === 'tailor') && p && p.work) {
      const b = g.world.buildings[p.work];
      if (b && !b.racket && g.jobs.rank() >= 1) opts.push({ label: `"Nice place. Be a shame if something happened to it."`, fn: () => {
        const ok = R.rng() < 0.3 + D2.fear(h) / 100 + g.jobs.rank() * 0.1;
        if (ok) { b.racket = 1; b.racketFamily = pl.family; say(`A-alright. ${R.fmtMoney(20 + b.w * 5)} a week. Just... leave us be.`); g.ui.toast(`${b.name} now pays protection: collect weekly at the door.`, 'good'); if (p) { p.fear += 30; p.opinion -= 20; } g.jobs.progress('racket', b); }
        else { say('I pay the ' + (g.jobs.cityFamily(h) || 'cops') + ' already. Get lost before I call them.'); if (p) p.opinion -= 10; }
      } });
    }
    if (h.look.kid) opts.push({ label: 'Give the kid a buck', fn: () => { if (pl.pay(1)) { say(pick(['Gee, thanks mister!', 'Wow! I\'m gonna buy a comic!', 'My mom says you\'re a hoodlum. I like you.'])); pl.rep.honor += 1; if (p) p.opinion += 10; } } });
    // romance: the old game's sweetheart, now earned through greetings
    if (p && h.arch === 'flirt' && h.look.fem !== pl.look.fem && !h.look.kid && p.age >= 21) {
      if (pl.sweetheart === p.id) {
        opts.push({ label: 'Ask your sweetheart a favor', fn: () => {
          if (pl.favorDay === g.pop.day) return say('I already helped you today, sugar. Don\'t push it.');
          pl.favorDay = g.pop.day;
          if (g.law.active() && g.law.incident.state !== 'pursuit') { g.law.clearIncident(true); say('I told the cops you were with me all night. You owe me dinner.'); }
          else { const c = R.rng.int(20, 60); pl.addCash(c); say(`Here's ${R.fmtMoney(c)}. Pay me back in dancing.`); }
        } });
      } else if (p.opinion > 30 && p.fam >= 3) {
        opts.push({ label: '"Let me take you dancing sometime."', fn: () => {
          if (R.rng() < 0.4 + p.opinion / 150) { pl.sweetheart = p.id; p.opinion = Math.min(100, p.opinion + 20); say('Pick me up at eight. Don\'t be late, and wear the good suit.'); g.ui.toast(`${g.pop.name(p)} is your sweetheart now.`, 'good'); }
          else say('Ha! Maybe. Buy me a drink first, big shot.');
        } });
      }
    }
    // intimidated people can be robbed
    if (!h.cop && (h.intimidated || h.state === 'cower' || h.state === 'surrender' || (pl.weaponOut && D2.fear(h) > 20))) {
      opts.push({ label: 'Rob them', fn: () => { close(); pl.rob(h); } });
    }
    if (!h.cop && !h.look.kid && g.jobs.rank() >= 2 && h.tr.brave > 0.55 && p && p.opinion > 40 && !h.crew && pl.crew.length < 2 && p.role !== 'don') {
      opts.push({ label: '"Want to make some real money? Ride with me."', fn: () => {
        if (R.rng() < 0.5 + p.opinion / 200) { g.player.recruit(h); say(pick(['I\'m in. Just say the word.', 'About time somebody asked.'])); }
        else say('I got a family, pal. Can\'t risk it.');
      } });
    }
    if (h.crew) opts.push({ label: 'Part ways', fn: () => { pl.dismiss(h); say('Call me if you need me.'); } });
    opts.push({ label: 'Goodbye', fn: close, close: true });
    return { title: name, sub: lines.join(' '), options: opts, mood };
  };
})();
