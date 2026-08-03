type JsonValue =
  | string
  | number
  | boolean
  | null
  | JsonValue[]
  | { [key: string]: JsonValue };

const toSnake = (key: string) => key.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);
const toCamel = (key: string) => key.replace(/_([a-z])/g, (_, letter: string) => letter.toUpperCase());

function mapKeys(value: JsonValue, convert: (key: string) => string): JsonValue {
  if (Array.isArray(value)) {
    return value.map((item) => mapKeys(item, convert));
  }
  if (value !== null && typeof value === "object") {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [convert(key), mapKeys(item, convert)])
    );
  }
  return value;
}

export function camelize<T>(value: JsonValue): T {
  return mapKeys(value, toCamel) as T;
}

export function snakeize(value: unknown): JsonValue {
  return mapKeys(value as JsonValue, toSnake);
}
