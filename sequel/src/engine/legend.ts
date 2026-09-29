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
);
export {};
