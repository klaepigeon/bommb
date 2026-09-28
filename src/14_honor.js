// RHAPSODY — your name on the street. Two reputations pull against each other. Honor is
// what the neighbourhood thinks of you: shopkeepers give you the regulars' price and a
// witness who likes you might decide they didn't see anything. Infamy is what they're
// afraid of: nobody haggles with you and some witnesses are too scared to talk, but the
// police take your name personally and every bounty on you is steeper.
'use strict';
(function () {
  const G = () => R.game;
  const HN = (R.honor = {});
  const SHOPS = new Set(['general', 'gunshop', 'tailor', 'barber', 'pawn', 'diner', 'pharmacy', 'liquor', 'butcher', 'bar', 'club', 'costume', 'garage', 'gas', 'hardware']);

  HN.respected = function () { const r = G().player.rep; return r.honor >= 60 && r.infamy < 50; };
  HN.feared = function () { return G().player.rep.infamy >= 60; };
  HN.title = function () {
    const r = G().player.rep;
    if (this.respected()) return r.honor >= 85 ? 'A pillar of the community' : 'Respected';
    if (this.feared()) return r.infamy >= 85 ? 'A name people whisper' : 'Feared';
    if (r.honor >= 35) return 'Decent enough';
    if (r.infamy >= 30) return 'Trouble';
    return 'Nobody, yet';
  };

  HN.wrap = function () {
    const g0 = G();
    // shop prices
    const PP = R.Player.prototype, pay = PP.pay;
    PP.pay = function (n) {
      const b = this.room && this.room.b;
      if (b && SHOPS.has(b.type) && n > 4 && this === G().player) {
        const k = HN.respected() ? 0.9 : HN.feared() ? 0.85 : 1;
        if (k < 1) {
          const m = Math.max(1, Math.round(n * k));
          if ((this.discountToast || 0) < G().clock.real) { this.discountToast = G().clock.real + 30; G().ui.toast(HN.respected() ? 'The regulars\' price. They like you here.' : 'Nobody in here wants to argue about the price.', 'good'); }
          return pay.call(this, m);
        }
      }
      return pay.call(this, n);
    };
    // witnesses
    const LP = R.Law.prototype, rep = LP.report, ab = LP.addBounty;
    LP.report = function (crime, witness) {
      const g = this.game, p = witness && witness.person;
      if (p && !witness.cop && crime.type !== 'copMurder') {
        if (HN.respected() && (p.opinion || 0) >= 0 && R.rng() < 0.35) { g.ui.toast('A witness saw it, and decided they didn\'t. People like you around here.', 'good'); return; }
        if (HN.feared() && R.rng() < 0.3) { g.ui.toast('A witness saw it, and knows exactly who you are. They keep their mouth shut.', 'warn'); p.fear = Math.min(100, (p.fear || 0) + 15); return; }
      }
      return rep.call(this, crime, witness);
    };
    // the police take a feared name personally
    LP.addBounty = function (crime) {
      if (HN.feared() && crime.bounty > 0) { const b = crime.bounty; crime.bounty = Math.round(b * 1.25); const r = ab.call(this, crime); crime.bounty = b; return r; }
      return ab.call(this, crime);
    };
    void g0;
  };

  HN.html = function () {
    const r = G().player.rep;
    const perks = [];
    if (this.respected()) perks.push('Shops give you the regulars\' price (−10%)', 'Witnesses who like you sometimes look away');
    if (this.feared()) perks.push('Nobody haggles with you (−15% in shops)', 'Some witnesses are too scared to talk', 'Bounties on you are 25% steeper');
    if (!perks.length) perks.push(r.honor > r.infamy ? `Reach 60 honor for the regulars' price and friendlier witnesses` : `Reach 60 infamy and people start to fear you`);
    return `<div class="sect">Your name on the street</div><p><b>${this.title()}</b> · honor ${Math.round(r.honor)} · infamy ${Math.round(r.infamy)}</p>${perks.map((p) => `<p><small>• ${p}</small></p>`).join('')}`;
  };

  HN.init = function () {
    if (this.wrapped) return;
    this.wrapped = true;
    this.wrap();
    const cj = R.campaign.jobsHtml;
    R.campaign.jobsHtml = function () { return HN.html() + cj.call(this); };
  };
})();
