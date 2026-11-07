/** Propuesta inicial del dominio: enteros del 1 al 5, una nota vigente por usuario/material. */
export const MIN_RATING_SCORE = 1;
export const MAX_RATING_SCORE = 5;

export function isValidRatingScore(score: number): boolean {
  return Number.isInteger(score) && score >= MIN_RATING_SCORE && score <= MAX_RATING_SCORE;
}
