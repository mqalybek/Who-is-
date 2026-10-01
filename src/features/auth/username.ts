// Ник: 3–20 символов, только латиница, цифры и подчёркивание.
// Это проверка только для удобства — окончательно ник проверит сервер (уникальность и формат).
const USERNAME_PATTERN = /^[a-z0-9_]{3,20}$/;

export function normalizeUsername(input: string): string {
  return input.trim().toLowerCase();
}

export function isValidUsername(input: string): boolean {
  return USERNAME_PATTERN.test(normalizeUsername(input));
}
