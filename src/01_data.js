// RHAPSODY — static game data: cities, buildings, jobs, items, vehicles, names.
'use strict';
(function () {
  const D = (R.data = {});

  // 70s-forever palette used across art + UI
  D.pal = {
    ink: '#1b1410', cream: '#f2e2c0', orange: '#d9621e', mustard: '#e4a92a', avocado: '#7a8a2e',
    teal: '#2a7d7a', brown: '#6b3f22', rust: '#a8401c', plum: '#5c2a4a', sky: '#8fc1c9',
  };

  // Tile ids
  D.T = {
    DEEP: 0, WATER: 1, SAND: 2, GRASS: 3, FOREST: 4, DIRT: 5, DESERT: 6, MARSH: 7, ROCK: 8,
    ROAD: 9, WALK: 10, BLDG: 11, LOT: 12, PARK: 13, DIRTROAD: 14, BRIDGE: 15, PLAZA: 16,
    FIELD: 17, SNOW: 18, BURNT: 19, SITE: 20, DOCK: 21, PARKING: 22, HWY: 23,
    VOID: 24, WALL: 25, WOOD: 26, TILEF: 27, CARPET: 28, CONCRETE: 29, DANCE: 30, EXITMAT: 31,
  };
  const T = D.T;
  D.solidTile = new Uint8Array(32);
  D.solidTile[T.ROCK] = 1;
  D.solidTile[T.BLDG] = 1;
  D.solidTile[T.WALL] = 1;
  D.solidTile[T.VOID] = 1;
  D.waterTile = new Uint8Array(32);
  D.waterTile[T.DEEP] = 1;
  D.waterTile[T.WATER] = 1;
  D.roadTile = new Uint8Array(32);
  D.roadTile[T.ROAD] = D.roadTile[T.DIRTROAD] = D.roadTile[T.BRIDGE] = D.roadTile[T.HWY] = 1;
  D.flammableTile = new Float32Array(32); // base ignition chance per tick
  D.flammableTile[T.GRASS] = 0.5;
  D.flammableTile[T.FOREST] = 0.8;
  D.flammableTile[T.FIELD] = 0.9;
  D.flammableTile[T.PARK] = 0.4;
  D.flammableTile[T.LOT] = 0.3;
  D.flammableTile[T.MARSH] = 0.08;
  D.flammableTile[T.DESERT] = 0.05;
  D.flammableTile[T.DIRT] = 0.1;
  D.flammableTile[T.SITE] = 0.3;

  // Object layer
  D.O = {
    NONE: 0, TREE: 1, PINE: 2, CACTUS: 3, BUSH: 4, BOULDER: 5, LAMP: 6, HYDRANT: 7, PHONE: 8,
    BENCH: 9, FENCE: 10, PUMP: 11, TRASH: 12, STUMP: 13, BARREL: 14, CONE: 15, REED: 16,
    PALM: 17, MAILBOX: 18, FLOWERS: 19, DEADTREE: 20, CRATE: 21, SIGNPOST: 22,
    // interior furniture
    COUNTER: 23, STOOL: 24, TABLE: 25, BED: 26, DRESSER: 27, SHELF: 28, FRIDGE: 29, REGISTER: 30, DESK: 31,
    LOCKER: 32, CABINET: 33, SAFE: 34, POOL: 35, JUKEBOX: 36, PEW: 37, ALTAR: 38, HOSPBED: 39, BARS: 40,
    RACK: 41, GUNRACK: 42, SLOT: 43, CARDTABLE: 44, ARCADE: 45, WASHER: 46, BCHAIR: 47, PLANT: 48, TV: 49,
    SOFA: 50, STOVE: 51, BOOKCASE: 52, PIANO: 53, VAULT: 54, LIFT: 55, CHAIR: 56, MIC: 57, FLOORLAMP: 58, RUG: 59,
  };
  const O = D.O;
  D.solidObj = new Uint8Array(64);
  [O.TREE, O.PINE, O.CACTUS, O.BOULDER, O.PUMP, O.PHONE, O.FENCE, O.PALM, O.DEADTREE, O.CRATE, O.BARREL].forEach((o) => (D.solidObj[o] = 1));
  D.smallObj = new Uint8Array(64); // solid for cars only (lamps, hydrants), peds walk around
  [O.LAMP, O.HYDRANT, O.MAILBOX, O.SIGNPOST, O.BENCH, O.TRASH].forEach((o) => (D.smallObj[o] = 1));
  [O.COUNTER, O.TABLE, O.BED, O.DRESSER, O.SHELF, O.FRIDGE, O.REGISTER, O.DESK, O.LOCKER, O.CABINET, O.SAFE, O.POOL, O.JUKEBOX, O.PEW, O.ALTAR,
    O.HOSPBED, O.BARS, O.RACK, O.GUNRACK, O.SLOT, O.CARDTABLE, O.ARCADE, O.WASHER, O.PLANT, O.TV, O.SOFA, O.STOVE, O.BOOKCASE, O.PIANO, O.VAULT, O.FLOORLAMP].forEach((o) => (D.solidObj[o] = 1));
  // what the USE button does with a piece of furniture (verbs + loot from the original build)
  D.furniture = {
    [O.DRESSER]: { verb: 'Search the dresser', cash: [5, 40], items: ['watch', 'ring', 'chain', 'bandage'] },
    [O.SHELF]: { verb: 'Search the shelf', cash: [0, 15], items: ['sandwich', 'ammo', 'bandage', 'eight'] },
    [O.FRIDGE]: { verb: 'Raid the fridge', cash: [0, 0], items: ['sandwich', 'sandwich', 'whiskey'] },
    [O.LOCKER]: { verb: 'Force the locker', cash: [5, 30], items: ['ammo', 'bandage', 'radio'] },
    [O.DESK]: { verb: 'Rifle through the desk', cash: [5, 50], items: ['watch', 'cam', 'bonds'] },
    [O.CABINET]: { verb: 'Pry open the cabinet', cash: [10, 45], items: ['bandage', 'tonic', 'silver'] },
    [O.BOOKCASE]: { verb: 'Check behind the books', cash: [0, 25], items: ['bonds', 'painting', 'eight'] },
    [O.SAFE]: { verb: 'Crack the safe', cash: [80, 300], items: ['jewels', 'bonds'], slow: 1, safe: 1 },
    [O.REGISTER]: { verb: 'Rob the register', register: 1 },
    [O.COUNTER]: { verb: 'Counter', service: 1 },
    [O.RACK]: { verb: 'Browse the suits', shop: 'tailor' },
    [O.GUNRACK]: { verb: 'Browse the guns', shop: 'guns' },
    [O.LIFT]: { verb: 'Garage services', shop: 'garage' },
    [O.BED]: { verb: 'Sleep', bed: 1 },
    [O.HOSPBED]: { verb: 'Lie down (heal $30)', heal: 1 },
    [O.JUKEBOX]: { verb: 'Play the jukebox', jukebox: 1 },
    [O.POOL]: { verb: 'Shoot pool ($10)', mini: 'pool' },
    [O.SLOT]: { verb: 'Play the slots ($5)', mini: 'slots' },
    [O.CARDTABLE]: { verb: 'Play blackjack', mini: 'blackjack' },
    [O.ARCADE]: { verb: 'Play pinball ($1)', arcade: 1 },
    [O.WASHER]: { verb: 'Wash your suit ($2)', wash: 1 },
    [O.BCHAIR]: { verb: 'Sit in the barber chair', barber: 1 },
    [O.PEW]: { verb: 'Sit and pray', pray: 1 },
    [O.ALTAR]: { verb: 'Confess ($40)', confess: 1 },
    [O.PIANO]: { verb: 'Play the piano', piano: 1 },
    [O.TV]: { verb: 'Watch the news', tv: 1 },
    [O.VAULT]: { verb: 'Rob the vault', vault: 1 },
    [O.PHONE]: { verb: 'Use the phone', phone: 1 },
    [O.STOVE]: { verb: 'Cook something', cook: 1 },
  };
  D.flammableObj = new Uint8Array(64);
  [O.TREE, O.PINE, O.BUSH, O.FENCE, O.PALM, O.REED, O.DEADTREE, O.CRATE, O.BENCH, O.FLOWERS].forEach((o) => (D.flammableObj[o] = 1));

  // ---------------- Cities ----------------
  D.cities = [
    {
      id: 'port', name: 'Port Hollow', tag: 'fog, fish and favors', fx: 0.2, fy: 0.46, blocks: 5, biome: 'coast',
      family: 'Vane', don: 'Augustin "Gus" Vane', color: '#2a7d7a', hue: 190, pop: 190,
    },
    {
      id: 'avalon', name: 'New Avalon', tag: 'neon never sleeps', fx: 0.52, fy: 0.5, blocks: 7, biome: 'plains',
      family: 'Castellano', don: 'Carmine Castellano', color: '#d9621e', hue: 20, pop: 330,
    },
    {
      id: 'dust', name: 'Dustwater', tag: 'hot wind, cold money', fx: 0.8, fy: 0.78, blocks: 4, biome: 'desert',
      family: 'Reyes', don: 'Soledad Reyes', color: '#e4a92a', hue: 42, pop: 140,
    },
    {
      id: 'pine', name: 'Pinecrest', tag: 'saws, snow and silence', fx: 0.56, fy: 0.15, blocks: 4, biome: 'forest',
      family: "O'Malley", don: 'Declan O\'Malley', color: '#7a8a2e', hue: 80, pop: 140,
    },
    {
      id: 'bayou', name: 'Bayou Clair', tag: 'hush money and humidity', fx: 0.27, fy: 0.82, blocks: 4, biome: 'marsh',
      family: 'Thibodeaux', don: 'Mama Odile Thibodeaux', color: '#5c2a4a', hue: 320, pop: 140,
    },
  ];
  D.hamlets = [
    { name: "Kessler's Crossing", fx: 0.36, fy: 0.33 },
    { name: 'Coyote Flats', fx: 0.7, fy: 0.62 },
    { name: 'Mercy Falls', fx: 0.8, fy: 0.3 },
    { name: 'Tupelo Bend', fx: 0.42, fy: 0.72 },
  ];

  // ---------------- Buildings ----------------
  // jobs: role -> count. house: residents capacity. hours: [open, close] (24h, close may wrap)
  D.btypes = {
    house: { name: 'House', w: [7, 8], h: [5, 7], roof: ['#8b4a2b', '#6b5a3a', '#4f6b4a', '#7a3a3a', '#5a4a6a'], wall: ['#e6d3a8', '#c9b48a', '#b7c9b0', '#d8b89a'], house: 5, fl: 1 },
    apartment: { name: 'Apartments', w: [10, 13], h: [7, 10], roof: ['#5a4a42', '#4a4a52'], wall: ['#b86b4b', '#9a7a5a', '#c7a27a'], house: 14, fl: 0.6 },
    general: { name: 'General Store', w: [8, 10], h: [7, 7], roof: ['#6e4a2a'], wall: ['#d9c08a'], jobs: { clerk: 2 }, hours: [7, 22], shop: 'general', fl: 0.8, rob: 1 },
    liquor: { name: 'Liquor', w: [7, 8], h: [5, 7], roof: ['#3f2a4a'], wall: ['#c79a5a'], jobs: { clerk: 1 }, hours: [10, 2], shop: 'liquor', fl: 0.8, rob: 1 },
    pharmacy: { name: 'Pharmacy', w: [7, 8], h: [7, 7], roof: ['#2f5a5a'], wall: ['#e0e0d0'], jobs: { clerk: 1, doctor: 1 }, hours: [8, 20], shop: 'pharmacy', fl: 0.6, rob: 1 },
    diner: { name: 'Diner', w: [8, 12], h: [7, 7], roof: ['#b84a3a'], wall: ['#f0e0c0'], jobs: { cook: 2, waitress: 2 }, hours: [6, 23], shop: 'diner', fl: 0.8, rob: 1, leisure: 1 },
    bar: { name: 'Bar', w: [8, 10], h: [7, 8], roof: ['#4a2a1a'], wall: ['#7a4a2a'], jobs: { bartender: 2, bouncer: 1 }, hours: [15, 3], shop: 'bar', fl: 1, rob: 1, leisure: 3 },
    club: { name: 'Disco', w: [10, 13], h: [8, 10], roof: ['#2a1a3a'], wall: ['#3a2a5a'], jobs: { dj: 1, bartender: 2, bouncer: 2 }, hours: [20, 4], shop: 'club', fl: 0.7, leisure: 4, neon: 1 },
    pawn: { name: 'Pawn & Loan', w: [7, 8], h: [5, 7], roof: ['#3a3a2a'], wall: ['#a89a6a'], jobs: { fence: 1 }, hours: [9, 21], shop: 'pawn', fl: 0.8, rob: 1 },
    gunshop: { name: 'Gun Store', w: [7, 8], h: [7, 7], roof: ['#2a3a2a'], wall: ['#8a8a6a'], jobs: { gunsmith: 1 }, hours: [9, 19], shop: 'guns', fl: 0.6 },
    tailor: { name: 'Tailor', w: [7, 8], h: [5, 7], roof: ['#6a2a4a'], wall: ['#e0c8b0'], jobs: { tailor: 1 }, hours: [9, 19], shop: 'tailor', fl: 0.9 },
    bank: { name: 'Bank', w: [12, 13], h: [8, 10], roof: ['#5a5a5a'], wall: ['#d8d0b8'], jobs: { teller: 3, guard: 1 }, hours: [9, 16], shop: 'bank', fl: 0.2, heist: 1 },
    police: { name: 'Police', w: [12, 13], h: [8, 10], roof: ['#2a3a5a'], wall: ['#c0c8d0'], jobs: { cop: 6, detective: 1 }, hours: [0, 24], shop: 'police', fl: 0.2 },
    hospital: { name: 'Hospital', w: [13, 15], h: [10, 10], roof: ['#e0e0e0'], wall: ['#f0f0f0'], jobs: { doctor: 2, nurse: 3 }, hours: [0, 24], shop: 'hospital', fl: 0.2 },
    garage: { name: 'Garage', w: [10, 12], h: [7, 8], roof: ['#4a4a4a'], wall: ['#b0a080'], jobs: { mechanic: 2 }, hours: [8, 20], shop: 'garage', fl: 0.5 },
    hotel: { name: 'Hotel', w: [10, 13], h: [8, 10], roof: ['#5a3a2a'], wall: ['#d0b090'], jobs: { clerk: 1 }, hours: [0, 24], shop: 'hotel', fl: 0.7, house: 4 },
    church: { name: 'Church', w: [8, 10], h: [10, 12], roof: ['#5a5a6a'], wall: ['#e8e0d0'], jobs: { priest: 1 }, hours: [7, 21], shop: 'church', fl: 0.5, leisure: 2 },
    social: { name: 'Social Club', w: [8, 10], h: [7, 8], roof: ['#1a1a1a'], wall: ['#6a2a2a'], jobs: { capo: 1, soldier: 3 }, hours: [0, 24], shop: 'social', fl: 0.7 },
    gas: { name: 'Gas', w: [8, 10], h: [5, 5], roof: ['#c04030'], wall: ['#f0f0e0'], jobs: { attendant: 1 }, hours: [0, 24], shop: 'gas', fl: 1.5, rob: 1 },
    butcher: { name: 'Butcher & Trapper', w: [7, 8], h: [5, 7], roof: ['#6a3a2a'], wall: ['#d0b8a0'], jobs: { butcher: 1 }, hours: [7, 19], shop: 'butcher', fl: 0.8 },
    casino: { name: 'Casino', w: [15, 16], h: [10, 12], roof: ['#3a1a1a'], wall: ['#c8a040'], jobs: { dealer: 4, guard: 2 }, hours: [0, 24], shop: 'casino', fl: 0.4, leisure: 4, neon: 1 },
    school: { name: 'School', w: [13, 15], h: [8, 10], roof: ['#7a4a3a'], wall: ['#d8c098'], jobs: { teacher: 3 }, hours: [8, 15], shop: 'school', fl: 0.5 },
    factory: { name: 'Works', w: [13, 16], h: [10, 12], roof: ['#5a5046'], wall: ['#8a7a6a'], jobs: { worker: 8 }, hours: [6, 22], shop: 'work', fl: 0.4 },
    office: { name: 'Offices', w: [10, 13], h: [8, 12], roof: ['#4a5058'], wall: ['#a8b0b8'], jobs: { clerk: 6 }, hours: [8, 18], shop: 'work', fl: 0.4 },
    laundry: { name: 'Laundromat', w: [7, 8], h: [5, 7], roof: ['#3a6a7a'], wall: ['#e0e8e0'], jobs: { clerk: 1 }, hours: [7, 23], shop: 'laundry', fl: 0.5, leisure: 1 },
    barber: { name: 'Barber', w: [7, 7], h: [5, 5], roof: ['#7a2a2a'], wall: ['#f0e0e0'], jobs: { barber: 1 }, hours: [9, 19], shop: 'barber', fl: 0.8, leisure: 1 },
    arcade: { name: 'Arcade', w: [8, 10], h: [7, 7], roof: ['#2a2a4a'], wall: ['#4a4a8a'], jobs: { clerk: 1 }, hours: [12, 24], shop: 'arcade', fl: 0.6, leisure: 2, neon: 1 },
    warehouse: { name: 'Warehouse', w: [12, 15], h: [8, 10], roof: ['#6a6a5a'], wall: ['#8a8070'], jobs: { dockhand: 4 }, hours: [5, 20], shop: 'work', fl: 0.6 },
    barn: { name: 'Farm', w: [8, 10], h: [7, 8], roof: ['#8a2a1a'], wall: ['#a8402a'], jobs: { farmer: 2 }, hours: [5, 20], shop: 'farm', fl: 1.3, house: 3 },
    cabin: { name: 'Cabin', w: [7, 7], h: [5, 5], roof: ['#5a3a2a'], wall: ['#8a5a3a'], house: 3, fl: 1.2 },
    costume: { name: 'Costume & Novelty', w: [7, 8], h: [5, 7], roof: ['#7a2a6a'], wall: ['#e8c850'], jobs: { clerk: 1 }, hours: [10, 21], shop: 'costume', fl: 0.8, rob: 1 },
    strip: { name: 'Strip Club', w: [10, 12], h: [8, 9], roof: ['#3a0a2a'], wall: ['#7a1a4a'], jobs: { dancer: 4, bartender: 1, bouncer: 1 }, hours: [19, 5], shop: 'strip', fl: 0.7, leisure: 4, neon: 1, adult: 1 },
    motel: { name: 'Motel', w: [12, 13], h: [5, 7], roof: ['#3a6a6a'], wall: ['#e0c8a0'], jobs: { clerk: 1 }, hours: [0, 24], shop: 'hotel', fl: 0.9, house: 2 },
  };
  // How cities spend their lots. Downtown = inner blocks.
  D.cityMix = {
    core: [['bank', 1], ['office', 4], ['hotel', 2], ['apartment', 5], ['club', 1.2], ['bar', 2], ['diner', 1.5], ['tailor', 1], ['pawn', 1], ['casino', 0.6], ['arcade', 0.8], ['liquor', 1], ['barber', 0.8], ['general', 1]],
    mid: [['apartment', 5], ['house', 4], ['general', 1.2], ['diner', 1], ['bar', 1.3], ['laundry', 0.8], ['pharmacy', 0.7], ['liquor', 0.8], ['barber', 0.6], ['gunshop', 0.5], ['garage', 0.7], ['church', 0.4], ['school', 0.3], ['gas', 0.4], ['pawn', 0.4]],
    edge: [['house', 10], ['factory', 1], ['warehouse', 1], ['gas', 0.5], ['garage', 0.4], ['motel', 0.4]],
  };
  // Buildings every city must have
  D.cityRequired = ['police', 'hospital', 'social', 'bank', 'bar', 'general', 'diner', 'pawn', 'gunshop', 'tailor', 'garage', 'church', 'hotel', 'butcher', 'gas', 'school', 'club', 'pharmacy', 'costume', 'strip'];

  D.roleNames = {
    clerk: 'Clerk', cook: 'Cook', waitress: 'Waitress', bartender: 'Bartender', bouncer: 'Bouncer', dj: 'DJ', fence: 'Fence',
    gunsmith: 'Gunsmith', tailor: 'Tailor', teller: 'Bank Teller', guard: 'Security', cop: 'Cop', detective: 'Detective',
    doctor: 'Doctor', nurse: 'Nurse', mechanic: 'Mechanic', priest: 'Priest', capo: 'Capo', soldier: 'Made Man', attendant: 'Pump Jockey',
    butcher: 'Butcher', dealer: 'Card Dealer', teacher: 'Teacher', worker: 'Line Worker', dockhand: 'Dockhand', farmer: 'Farmer',
    barber: 'Barber', dancer: 'Dancer', none: 'Out of Work', retired: 'Retired', kid: 'Kid', student: 'Student', don: 'Don', hustler: 'Hustler',
    hunter: 'Trapper', fisher: 'Fisherman', drifter: 'Drifter', musician: 'Street Musician', artist: 'Painter', preacher: 'Street Preacher',
  };

  // Archetypes drive how named people and strangers respond.
  D.archetypes = {
    tough: { brave: 0.85, warm: 0.3, lawful: 0.3, chatty: 0.4, greed: 0.5 },
    timid: { brave: 0.1, warm: 0.5, lawful: 0.7, chatty: 0.3, greed: 0.3 },
    friendly: { brave: 0.4, warm: 0.9, lawful: 0.6, chatty: 0.8, greed: 0.2 },
    grumpy: { brave: 0.55, warm: 0.15, lawful: 0.6, chatty: 0.3, greed: 0.5 },
    flirt: { brave: 0.45, warm: 0.8, lawful: 0.4, chatty: 0.8, greed: 0.4 },
    gossip: { brave: 0.3, warm: 0.6, lawful: 0.5, chatty: 1.0, greed: 0.4 },
    square: { brave: 0.4, warm: 0.5, lawful: 0.95, chatty: 0.5, greed: 0.2 },
    hustler: { brave: 0.5, warm: 0.5, lawful: 0.15, chatty: 0.7, greed: 0.9 },
    eccentric: { brave: 0.5, warm: 0.6, lawful: 0.4, chatty: 0.9, greed: 0.3 },
    pious: { brave: 0.3, warm: 0.8, lawful: 0.85, chatty: 0.5, greed: 0.1 },
  };

  // ---------------- Items ----------------
  D.weapons = {
    fists: { name: 'Fists', melee: 1, dmg: 9, range: 18, rate: 0.35, knock: 60 },
    knuckles: { name: 'Brass Knuckles', melee: 1, dmg: 16, range: 18, rate: 0.35, knock: 110, price: 40 },
    bat: { name: 'Louisville Slugger', melee: 1, dmg: 24, range: 24, rate: 0.55, knock: 160, price: 35 },
    knife: { name: 'Switchblade', melee: 1, blade: 1, dmg: 32, range: 18, rate: 0.4, knock: 40, price: 50 },
    revolver: { name: '.38 Snub Nose', gun: 1, dmg: 34, range: 190, rate: 0.42, clip: 6, spread: 0.05, ammo: 'pistol', price: 180, loud: 1 },
    magnum: { name: '.357 Magnum', gun: 1, dmg: 58, range: 230, rate: 0.7, clip: 6, spread: 0.03, ammo: 'pistol', price: 420, loud: 1.3 },
    shotgun: { name: 'Pump Shotgun', gun: 1, dmg: 13, pellets: 7, range: 120, rate: 0.9, clip: 5, spread: 0.22, ammo: 'shells', price: 350, loud: 1.5 },
    chopper: { name: 'Chopper SMG', gun: 1, dmg: 15, range: 170, rate: 0.09, clip: 30, spread: 0.1, ammo: 'smg', price: 900, loud: 1.4, auto: 1, sil: 1 },
    rifle: { name: 'Hunting Rifle', gun: 1, dmg: 80, range: 330, rate: 1.1, clip: 5, spread: 0.01, ammo: 'rifle', price: 300, loud: 1.4 },
    derringer: { name: '.22 Derringer', gun: 1, dmg: 24, range: 120, rate: 0.5, clip: 2, spread: 0.06, ammo: 'pistol', price: 90, loud: 0.6, sil: 1 },
    colt45: { name: 'M1911 .45', gun: 1, dmg: 40, range: 200, rate: 0.36, clip: 7, spread: 0.04, ammo: 'pistol', price: 320, loud: 1.1, sil: 1 },
    sawedoff: { name: 'Sawed-Off', gun: 1, dmg: 16, pellets: 9, range: 80, rate: 1.0, clip: 2, spread: 0.32, ammo: 'shells', price: 260, loud: 1.7 },
    carbine: { name: 'M1 Carbine', gun: 1, dmg: 46, range: 280, rate: 0.34, clip: 15, spread: 0.025, ammo: 'rifle', price: 700, loud: 1.3 },
    crossbow: { name: 'Crossbow', gun: 1, dmg: 75, range: 220, rate: 1.4, clip: 1, spread: 0.01, ammo: 'bolts', price: 250, loud: 0, silent: 1 },
    tommy: { name: 'Tommy Gun', gun: 1, dmg: 17, range: 180, rate: 0.075, clip: 50, spread: 0.12, ammo: 'smg', price: 1500, loud: 1.5, auto: 1 },
    razor: { name: 'Straight Razor', melee: 1, blade: 1, dmg: 28, range: 14, rate: 0.28, knock: 20, price: 30 },
    machete: { name: 'Machete', melee: 1, blade: 1, dmg: 40, range: 21, rate: 0.5, knock: 70, price: 60 },
    hatchet: { name: 'Hatchet', melee: 1, blade: 1, dmg: 35, range: 19, rate: 0.52, knock: 90, price: 45 },
    crowbar: { name: 'Crowbar', melee: 1, dmg: 23, range: 22, rate: 0.45, knock: 130, price: 25 },
    sap: { name: 'Leather Sap', melee: 1, dmg: 12, range: 15, rate: 0.5, knock: 50, price: 20, ko: 1 },
    molotov: { name: 'Molotov', thrown: 1, dmg: 20, range: 110, rate: 0.8, ammo: 'molotov', price: 25, fire: 1 },
    dynamite: { name: 'Dynamite', thrown: 1, dmg: 120, range: 100, rate: 1.0, ammo: 'dynamite', price: 60, blast: 1 },
  };
  D.ammoNames = { pistol: 'Pistol rounds', shells: 'Shells', smg: 'SMG mags', rifle: 'Rifle rounds', bolts: 'Crossbow bolts', molotov: 'Molotovs', dynamite: 'Dynamite' };
  D.ammoPrice = { pistol: [12, 18], shells: [10, 16], smg: [30, 40], rifle: [5, 18], bolts: [6, 15] }; // [amount, price]

  // Loot sells at pawn. value in $.
  D.loot = {
    watch: { name: 'Gold Watch', v: 45 }, ring: { name: 'Diamond Ring', v: 90 }, chain: { name: 'Gold Chain', v: 60 },
    eight: { name: '8-Track Tapes', v: 8 }, tv: { name: 'Portable TV', v: 55 }, silver: { name: 'Silverware', v: 30 },
    fur: { name: 'Fur Coat', v: 120 }, jewels: { name: 'Jewelry Box', v: 150 }, cam: { name: 'Instamatic Camera', v: 25 },
    radio: { name: 'Transistor Radio', v: 18 }, bonds: { name: 'Bearer Bonds', v: 400 }, painting: { name: 'Oil Painting', v: 220 },
    pelt_rabbit: { name: 'Rabbit Pelt', v: 6, pelt: 1 }, pelt_deer: { name: 'Deer Hide', v: 18, pelt: 1 }, pelt_wolf: { name: 'Wolf Pelt', v: 30, pelt: 1 },
    pelt_bear: { name: 'Bear Pelt', v: 80, pelt: 1 }, pelt_gator: { name: 'Gator Skin', v: 55, pelt: 1 }, pelt_coyote: { name: 'Coyote Pelt', v: 14, pelt: 1 },
    pelt_boar: { name: 'Boar Hide', v: 20, pelt: 1 }, meat: { name: 'Game Meat', v: 5, pelt: 1 }, fish: { name: 'Fresh Fish', v: 7, pelt: 1 },
    bigfish: { name: 'Prize Bass', v: 28, pelt: 1 },
  };
  D.consumables = {
    bandage: { name: 'Bandage', heal: 30, price: 12 },
    whiskey: { name: 'Whiskey', cool: 35, drunk: 0.3, price: 6 },
    smokes: { name: 'Smokes', cool: 20, price: 3 },
    coffee: { name: 'Coffee', sober: 1, heal: 5, price: 2 },
    sandwich: { name: 'Hero Sandwich', heal: 25, price: 5 },
    tonic: { name: 'Snake Oil Tonic', heal: 60, cool: 20, price: 30 },
  };
  D.tools = {
    lockpick: { name: 'Lockpick', price: 15 }, gascan: { name: 'Gas Can', price: 20 }, rod: { name: 'Fishing Rod', price: 30 },
    mask: { name: 'Ski Mask', price: 10 }, bait: { name: 'Bait', price: 2 }, rope: { name: 'Rope', price: 6 }, tape: { name: 'Duct Tape', price: 3 },
  };

  // Outfits change your silhouette (and reset recognition)
  D.outfits = {
    mook: { name: 'The Mook (pinstripe)', suit: '#2b2f3a', stripe: '#6a7086', shirt: '#e8d9b0', hat: '#1f1a17', price: 0 },
    velvet: { name: 'Crushed Velvet', suit: '#5c2a4a', stripe: '#7c3a6a', shirt: '#f0d890', hat: '#2a1a24', price: 120 },
    leisure: { name: 'Leisure Suit', suit: '#b88a3a', stripe: '#c89a4a', shirt: '#6a3a1a', hat: null, price: 80 },
    tracksuit: { name: 'Velour Tracksuit', suit: '#2a5a8a', stripe: '#ffffff', shirt: '#2a5a8a', hat: null, price: 60 },
    leather: { name: 'Leather & Denim', suit: '#3a2418', stripe: '#3a2418', shirt: '#4a6a9a', hat: null, price: 150 },
    workman: { name: 'Dock Coveralls', suit: '#4a5a3a', stripe: '#4a5a3a', shirt: '#8a8a6a', hat: '#6a3a1a', price: 40 },
    tux: { name: 'Powder Blue Tux', suit: '#8ab0d0', stripe: '#9ac0e0', shirt: '#ffffff', hat: null, price: 250 },
    camelcoat: { name: 'Camel Overcoat', suit: '#b0885a', stripe: '#a07848', shirt: '#2a2020', hat: '#3a2a1a', price: 300 },
  };

  // ---------------- Vehicles ----------------
  D.vehicles = {
    sedan: { name: 'Ponce Grand', w: 40, h: 16, top: 150, acc: 130, hp: 100, colors: ['#8a3a2a', '#2a4a6a', '#6a6a3a', '#c8b060', '#3a5a3a', '#7a5a8a', '#d0d0c0'], price: 900 },
    wagon: { name: 'Brougham Wagon', w: 46, h: 17, top: 135, acc: 110, hp: 110, colors: ['#8a6a3a', '#5a7a5a', '#c8a060', '#8a3a3a'], wood: 1, price: 700 },
    muscle: { name: 'Stallion GT', w: 40, h: 16, top: 230, acc: 220, hp: 90, colors: ['#c83a1a', '#1a1a1a', '#e4a92a', '#2a6ac0', '#f0f0f0'], stripes: 1, price: 2600 },
    pickup: { name: 'Bison Pickup', w: 42, h: 17, top: 145, acc: 140, hp: 130, colors: ['#6a4a2a', '#3a5a6a', '#8a8a6a', '#a83a2a'], bed: 1, price: 800 },
    van: { name: 'Mystic Van', w: 40, h: 17, top: 125, acc: 100, hp: 120, colors: ['#5c2a4a', '#2a7d7a', '#d9621e'], mural: 1, price: 1100 },
    coupe: { name: 'Monarch Coupe', w: 39, h: 15, top: 190, acc: 180, hp: 85, colors: ['#e0c090', '#4a2a1a', '#2a4a3a', '#8ab0d0'], vinyl: 1, price: 1800 },
    taxi: { name: 'Checker Cab', w: 42, h: 16, top: 150, acc: 130, hp: 110, colors: ['#e8c030'], checker: 1 },
    police: { name: 'Interceptor', w: 42, h: 16, top: 220, acc: 210, hp: 140, colors: ['#1a1a24'], police: 1 },
    bus: { name: 'City Bus', w: 73, h: 17, top: 110, acc: 70, hp: 250, colors: ['#e4a92a', '#2a7d7a'], bus: 1 },
    truck: { name: 'Hauler', w: 68, h: 17, top: 115, acc: 70, hp: 250, colors: ['#8a3a2a', '#3a4a5a', '#d0d0c0'], box: 1 },
    ambulance: { name: 'Ambulance', w: 46, h: 17, top: 190, acc: 160, hp: 150, colors: ['#f0f0f0'], medic: 1 },
    firetruck: { name: 'Fire Engine', w: 68, h: 17, top: 160, acc: 110, hp: 300, colors: ['#c02020'], fire: 1 },
  };
  D.civCars = [['sedan', 6], ['wagon', 3], ['muscle', 1], ['pickup', 3], ['van', 1.2], ['coupe', 2], ['taxi', 1.5], ['truck', 0.8]];
  D.ruralCars = [['pickup', 6], ['wagon', 2], ['sedan', 2], ['truck', 2], ['van', 1], ['muscle', 0.6]];

  // ---------------- Animals ----------------
  D.animals = {
    rabbit: { name: 'Rabbit', size: 5, hp: 8, speed: 95, prey: 1, pelt: 'pelt_rabbit', col: '#a89078', biome: ['grass', 'forest', 'field', 'desert'] },
    deer: { name: 'Deer', size: 9, hp: 40, speed: 110, prey: 1, pelt: 'pelt_deer', col: '#a8703a', biome: ['forest', 'grass'], herd: [2, 4] },
    wolf: { name: 'Wolf', size: 9, hp: 55, speed: 115, predator: 1, dmg: 12, pelt: 'pelt_wolf', col: '#6a6a70', biome: ['forest', 'snow'], herd: [2, 4], night: 1.8 },
    bear: { name: 'Black Bear', size: 13, hp: 180, speed: 95, predator: 1, dmg: 28, pelt: 'pelt_bear', col: '#2a2020', biome: ['forest'], rare: 1 },
    coyote: { name: 'Coyote', size: 8, hp: 30, speed: 110, predator: 1, dmg: 7, pelt: 'pelt_coyote', col: '#b08a5a', biome: ['desert', 'grass'], herd: [1, 3], night: 1.5 },
    gator: { name: 'Gator', size: 12, hp: 120, speed: 70, predator: 1, dmg: 30, pelt: 'pelt_gator', col: '#3a4a2a', biome: ['marsh'], ambush: 1 },
    boar: { name: 'Wild Boar', size: 9, hp: 60, speed: 90, predator: 0, angry: 1, dmg: 12, pelt: 'pelt_boar', col: '#4a3a2a', biome: ['forest', 'marsh'], herd: [1, 3] },
    snake: { name: 'Rattlesnake', size: 5, hp: 6, speed: 40, predator: 1, dmg: 10, col: '#8a7a4a', biome: ['desert'], ambush: 1 },
    crow: { name: 'Crow', size: 4, hp: 3, speed: 140, bird: 1, col: '#1a1a1a', biome: ['grass', 'field', 'city', 'forest'], herd: [3, 7] },
    gull: { name: 'Gull', size: 4, hp: 3, speed: 140, bird: 1, col: '#e8e8e0', biome: ['coast', 'city'], herd: [3, 6] },
    heron: { name: 'Heron', size: 6, hp: 6, speed: 120, bird: 1, col: '#9aa8b8', biome: ['marsh'] },
    vulture: { name: 'Vulture', size: 6, hp: 8, speed: 120, bird: 1, col: '#3a2a2a', biome: ['desert'], herd: [2, 4] },
    dog: { name: 'Stray Dog', size: 7, hp: 30, speed: 110, dog: 1, dmg: 6, col: '#8a6a4a', biome: ['city'] },
    cattle: { name: 'Cattle', size: 12, hp: 90, speed: 50, prey: 1, pelt: 'meat', col: '#6a4a3a', biome: ['field'], herd: [3, 6] },
  };

  // ---------------- Names ----------------
  D.firstM = ('Sal Vinnie Frankie Tony Carmine Nicky Joey Lou Sonny Ray Eddie Bobby Jimmy Dom Artie Paulie Gus Vito Rocco Benny Marty Richie Stan Earl Clint Wade Hank Buck Dale Travis Duane Rex Cletus Luther Otis Curtis Marvin Isaac Reggie Darnell Leroy Floyd Clyde Chester Walt Harold Leon Marco Enzo Aldo Ignacio Rafael Hector Ruben Esteban Luis Cruz Diego Declan Seamus Fergus Liam Padraig Owen Colm Tobias Emile Remy Beau Lucien Jules Gaston Pierre Felix Dexter Barry Lenny Morty Irving Saul Abe Sid Murray Nate Ike Gil Mack Russ Chuck Burt Dewey Jerome Lamar Rufus Virgil Amos Moses Ezra Jonah Silas').split(' ');
  D.firstF = ('Rosa Connie Gina Loretta Angie Theresa Dolores Carla Maria Lucia Francesca Sophia Donna Linda Barbara Debbie Cheryl Brenda Tammy Peggy Darlene Wanda Rhonda Loretta Faye Opal Pearl Hazel Mabel Ruby Etta Gladys Bernice Coretta Aretha Shirley Denise Yvonne Gloria Pam Farrah Stevie Cher Joni Janis Carmen Lupe Elena Marisol Alma Inez Soledad Bridget Maeve Siobhan Nora Colleen Fiona Odile Celeste Marguerite Josette Delphine Claudette Evangeline Sadie Trixie Dixie Candy Bunny Roxanne Veronica Marlene Lorraine Joanne Irene Vera Minnie Lottie Beatrice Ada Iris Ivy June').split(' ');
  D.lastAll = {
    port: 'Marino Kowalski Fitzgerald Delacroix Haddad Olsen Pereira Nakamura Sweeney Brandt Costa Lindqvist Moreau MacLeod Silva Novak Hayes Doyle Rasmussen Bianchi Vane Corrigan Pike Salter Mooring Fenwick'.split(' '),
    avalon: 'Castellano Russo Esposito Romano Greco Goldberg Weiss Johnson Washington Jackson Kaplan Rossi Ferrara Moretti Lombardi Coleman Brooks Rosen Fontaine Chen Park Walker Pryor Gallo Lucchese DeLuca Barzini Tattaglia Katz Levin'.split(' '),
    dust: 'Reyes Montoya Vargas Castillo Ortega Guerrero Delgado Maldonado Cody Pruitt Tate Lyle Coburn Earp Holliday Dawson Skaggs Fontana Salazar Ruiz Navarro Cardenas'.split(' '),
    pine: "O'Malley Sullivan Flynn Brennan Gallagher Lindgren Halvorsen Bjork Kowalczyk Tremblay Gagnon Nilsson Harlan Sawyer Woods Birch Ashford Mulroney Keane Byrne".split(' '),
    bayou: 'Thibodeaux Boudreaux Landry Guidry Hebert Broussard LeBlanc Fontenot Arceneaux Richard Batiste Toussaint Duplantis Robichaux Benoit Cormier Mouton Savoie'.split(' '),
  };
  D.nick = ['Big', 'Little', 'Knuckles', 'The Ox', 'Two-Tone', 'Specs', 'Fats', 'Lucky', 'Slim', 'Mouse', 'Hammer', 'The Weasel', 'Buttons', 'Sugar', 'Tiny', 'Ice', 'Doc', 'Loafers', 'Sideburns', 'Disco', 'Spats', 'Cadillac'];
  D.shopNames = {
    general: ['{L} Mercantile', '{L} & Sons Grocery', 'Sunrise Market', 'Corner Store', 'Stop-N-Save'],
    liquor: ['Bottle King', "{F}'s Liquors", 'Happy Hour Package', 'Top Shelf'],
    pharmacy: ['{L} Drugs', 'Rexall of {C}', 'Apothecary {L}'],
    diner: ['The Blue Plate', "{F}'s Diner", 'Silver Spoon', 'Rise & Shine', 'Chrome Cup'],
    bar: ['The Rusty Anchor', 'Last Call', "{L}'s Tavern", 'The Velvet Rope', 'Bottom of the Glass', 'The Loose Caboose', 'The Crooked Fedora'],
    club: ['Club Neon', 'Studio 77', 'The Mirrorball', 'Boogie Palace', 'Starlight Lounge'],
    costume: ['Masquerade {L}', 'Funhouse Novelties', 'Mask & Mayhem', '{F}\'s Costumes', 'The Joke Shop'],
    strip: ['The Velvet Pole', 'Club Tease', 'The Pink Pussycat', 'Satin & Sin', 'The Honey Pot', 'Studs & Sequins'],
    pawn: ["{F}'s Pawn", 'Honest {F} Loans', 'Second Chance Pawn'],
    gunshop: ["{L} Arms", 'Sportsman Supply', 'Iron & Oak'],
    tailor: ['{L} Tailoring', 'The Dapper Needle', 'Sharp Dressed'],
    bank: ['{C} Savings & Loan', 'First National', 'Merchants Trust'],
    police: ['{C} PD'], hospital: ['{C} General'], garage: ["{F}'s Garage", '{L} Motors', 'Chrome & Rubber'],
    hotel: ['The Marlowe', 'Hotel {L}', 'The Grand {C}'], church: ['St. {F}', 'First Baptist', 'Our Lady of {C}'],
    social: ['{Fam} Social Club', '{Fam} & Co. Imports'], gas: ['Gulfstar', 'Sunoco-ish', 'Texaco-ish', 'Flying Eagle Gas'],
    butcher: ['{L} Meats & Hides', 'Trapper {F}'], casino: ['The Golden Horseshoe', 'Casino Royale Avalon'],
    school: ['{C} High'], factory: ['{L} Works', '{C} Canning', 'Allied Steel'], office: ['{L} Building', 'Mutual Plaza'],
    laundry: ['Suds City', 'Spin Cycle'], barber: ["{F}'s Chair", 'Clip Joint'], arcade: ['Pinball Wizard', 'Galaxy Arcade'],
    warehouse: ['{L} Freight', 'Pier {N}'], barn: ['{L} Farm', '{L} Ranch'], cabin: ['{L} Cabin'], motel: ['Starlite Motel', 'Rest-Eez Motor Inn'],
    house: ['{L} Residence'], apartment: ['{L} Arms', '{C} Towers', 'The {L}'],
  };

  // Radio stations (procedural music + DJ lines)
  D.stations = [
    { id: 'funk', name: 'KFNK 70.7 — The Funk', dj: ['Stay groovy, Avalon.', 'That was hotter than a stolen Stallion.', 'KFNK. Keep your collar wide and your wheels clean.'] },
    { id: 'disco', name: 'WDSC 99.9 — Mirrorball', dj: ['Dance like the cops aren\'t watching.', 'Four on the floor, all night, every night.', 'Mirrorball radio — sequins mandatory.'] },
    { id: 'outlaw', name: 'KCTR 88.1 — Outlaw Country', dj: ['This one goes out to everybody on the lam.', 'Dustwater\'s own. Long roads, short tempers.', 'Pour one out and keep driving.'] },
    { id: 'off', name: 'Radio Off', dj: [] },
  ];
})();
