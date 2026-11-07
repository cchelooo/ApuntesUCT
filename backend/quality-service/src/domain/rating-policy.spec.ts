import { isValidRatingScore } from './rating-policy';

describe('Rating policy', () => {
  it.each([1, 2, 3, 4, 5])('acepta %s', (score) => {
    expect(isValidRatingScore(score)).toBe(true);
  });
  it.each([0, -1, 6, 2.5, NaN, Infinity])('rechaza %s', (score) => {
    expect(isValidRatingScore(score)).toBe(false);
  });
});
