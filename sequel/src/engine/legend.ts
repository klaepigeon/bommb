// XX8X's achievements, on top of game 1's (R.feats): the frontier, the stars and the story.

import { SQ } from './state';

const A = () => SQ.achieved || {};
const F = (R as any).feats;
if (F) F.list.push(
  { id: 'orbit', name: 'Slipped the Clamp', how: 'Get the Fear Man\'s clamp off your ship', test: () => !SQ.flags.clamp },
  { id: 'fearman', name: 'Fear Itself', how: 'Kill the Fear Man', test: () => !!SQ.flags.fearDead },
  { id: 'star', name: 'Another Sun', how: 'Jump to another star', test: () => (SQ.known || []).length > 1 },
  { id: 'far', name: 'Far From Home', how: 'Chart five star systems', test: () => (SQ.known || []).length >= 5 },
  { id: 'colony', name: 'Founding Father', how: 'Found a colony', test: () => Object.keys(SQ.colonies || {}).length > 0 },
  { id: 'base', name: 'Station Master', how: 'Build an orbital base', test: () => (SQ.bases || []).length > 0 },
  { id: 'crew', name: 'Full Complement', how: 'Fly with three crew', test: () => (SQ.crew || []).length >= 3 },
  { id: 'hauler', name: 'Long Haul', how: 'Deliver five contracts', test: () => (A().deliveries || 0) >= 5 },
  { id: 'bounty', name: 'Dead, Not Alive', how: 'Collect an Imperial bounty', test: () => (A().bounties || 0) >= 1 },
  { id: 'rescue', name: 'Good Samaritan', how: 'Answer a distress call', test: () => (A().rescues || 0) >= 1 },
  { id: 'shake', name: 'Stand and Deliver', how: 'Shake down a freighter', test: () => (A().shakedowns || 0) >= 1 },
  { id: 'race', name: 'Faster Than Raven', how: 'Win a street race', test: () => (A().races || 0) >= 1 },
  { id: 'pit', name: 'Champion of the Pit', how: 'Win the Pit', test: () => (A().pit || 0) >= 1 },
  { id: 'chrome', name: 'More Machine', how: 'Install two implants', test: () => Object.keys(SQ.implants || {}).length >= 2 },
  { id: 'contact', name: 'First Contact', how: 'Sing with the deep ones under Europa', test: () => !!SQ.flags.europa },
  { id: 'source', name: 'The Source', how: 'Finish the Choir\'s story', test: () => !!SQ.flags.ending },
  { id: 'dread', name: 'Giant Killer', how: 'Destroy the Imperial dreadnought', test: () => !!SQ.flags.dreadDead },
  { id: 'convoy', name: 'Shepherd', how: 'See a convoy home', test: () => (A().convoys || 0) >= 1 },
  { id: 'tithe', name: 'Render Unto Caesar', how: 'Crack a tithe barge', test: () => (A().tithes || 0) >= 1 },
  { id: 'song', name: 'Whale Song', how: 'Sell a leviathan\'s song on Luna', test: () => (SQ.flags.songsSold || 0) >= 1 },
  { id: 'ahab', name: 'Ahab', how: 'Kill a leviathan', test: () => (A().whales || 0) >= 1 },
  { id: 'fares', name: 'Cabbie of the Void', how: 'Carry ten passengers', test: () => (A().fares || 0) >= 10 },
  { id: 'rayner', name: 'In Blackest Night', how: 'Do the Fear Man\'s job', test: () => SQ.flags.rayner === 2 },
  { id: 'parallax', name: 'Emerald Twilight', how: 'Defeat Parallax on Mars', test: () => SQ.flags.parallax === 2 },
  { id: 'crowd', name: 'Face on the Wall', how: 'Break a Peacekeeper line in a riot', test: () => (SQ.flags.riotHero || 0) >= 1 },
);
export {};
