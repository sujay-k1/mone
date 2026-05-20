// ============================================================================
// Deterministic Seeded Random Number Generator
// ============================================================================
// Uses mulberry32 PRNG — fast, deterministic, good distribution.
// Every dataset gets a unique seed for reproducibility.

export class SeededRandom {
  private state: number;

  constructor(seed: string) {
    this.state = this.hashSeed(seed);
  }

  private hashSeed(seed: string): number {
    let hash = 0;
    for (let i = 0; i < seed.length; i++) {
      const char = seed.charCodeAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & hash; // Convert to 32-bit integer
    }
    return Math.abs(hash) || 1;
  }

  private next(): number {
    this.state |= 0;
    this.state = (this.state + 0x6D2B79F5) | 0;
    let t = Math.imul(this.state ^ (this.state >>> 15), 1 | this.state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  }

  float(min: number, max: number): number {
    return min + this.next() * (max - min);
  }

  int(min: number, max: number): number {
    return Math.floor(this.float(min, max + 1));
  }

  choice<T>(array: T[]): T {
    return array[this.int(0, array.length - 1)];
  }

  weighted<T>(options: T[], weights: number[]): T {
    const totalWeight = weights.reduce((sum, w) => sum + w, 0);
    let random = this.next() * totalWeight;
    for (let i = 0; i < options.length; i++) {
      random -= weights[i];
      if (random <= 0) return options[i];
    }
    return options[options.length - 1];
  }

  gaussian(mean: number, stddev: number): number {
    // Box-Muller transform
    const u1 = this.next();
    const u2 = this.next();
    const z0 = Math.sqrt(-2 * Math.log(u1 || 0.0001)) * Math.cos(2 * Math.PI * u2);
    return mean + z0 * stddev;
  }

  gaussianClamped(mean: number, stddev: number, min: number, max: number): number {
    const value = this.gaussian(mean, stddev);
    return Math.max(min, Math.min(max, Math.round(value)));
  }

  amount(min: number, max: number): number {
    const mean = (min + max) / 2;
    const stddev = (max - min) / 4;
    const value = this.gaussian(mean, stddev);
    return Math.max(min, Math.min(max, Math.round(value * 100) / 100));
  }

  shouldOccur(probability: number): boolean {
    return this.next() < probability;
  }

  jitterDays(baseDay: number, maxJitter: number): number {
    const jitter = this.int(-maxJitter, maxJitter);
    return Math.max(1, Math.min(28, baseDay + jitter));
  }

  timeInRange(hourStart: number, hourEnd: number): { hour: number; minute: number } {
    const hour = this.int(hourStart, hourEnd);
    const minute = this.int(0, 59);
    return { hour, minute };
  }

  shuffle<T>(array: T[]): T[] {
    const result = [...array];
    for (let i = result.length - 1; i > 0; i--) {
      const j = this.int(0, i);
      [result[i], result[j]] = [result[j], result[i]];
    }
    return result;
  }

  subset<T>(array: T[], minCount: number, maxCount: number): T[] {
    const count = this.int(minCount, Math.min(maxCount, array.length));
    const shuffled = this.shuffle(array);
    return shuffled.slice(0, count);
  }

  pickN<T>(array: T[], n: number): T[] {
    return this.subset(array, n, n);
  }

  uuid(): string {
    const hex = () => this.int(0, 15).toString(16);
    const s = (n: number) => Array.from({ length: n }, hex).join("");
    return `${s(8)}-${s(4)}-4${s(3)}-${this.choice(["8", "9", "a", "b"])}${s(3)}-${s(12)}`;
  }

  referenceNumber(): string {
    return Array.from({ length: 9 }, () => this.int(0, 9)).join("");
  }

  txnId(prefix: string): string {
    const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    const suffix = Array.from({ length: 12 }, () => this.choice(chars.split(""))).join("");
    return `${prefix}${suffix}`;
  }
}

// Formatting helpers

export function formatTimestamp(date: string, hour: number, minute: number, second = 0): string {
  const h = String(hour).padStart(2, "0");
  const m = String(minute).padStart(2, "0");
  const s = String(second).padStart(2, "0");
  return `${date}T${h}:${m}:${s}+05:30`;
}

export function formatAmount(amount: number): string {
  return amount.toFixed(2);
}

export function daysInMonth(year: number, month: number): number {
  return new Date(year, month, 0).getDate();
}

export function dayOfWeekName(date: string): "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday" | "sunday" {
  const days: ("sunday" | "monday" | "tuesday" | "wednesday" | "thursday" | "friday" | "saturday")[] = [
    "sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
  ];
  return days[new Date(date).getDay()];
}

export function isWeekend(dayName: string): boolean {
  return dayName === "saturday" || dayName === "sunday";
}

export function timeOfDayFromHour(hour: number): "morning" | "afternoon" | "evening" | "night" | "late_night" {
  if (hour >= 5 && hour < 12) return "morning";
  if (hour >= 12 && hour < 17) return "afternoon";
  if (hour >= 17 && hour < 21) return "evening";
  if (hour >= 21 && hour < 24) return "night";
  return "late_night";
}

export function addDays(dateStr: string, days: number): string {
  const d = new Date(dateStr);
  d.setDate(d.getDate() + days);
  return d.toISOString().slice(0, 10);
}

export function monthsBetween(start: string, end: string): { year: number; month: number }[] {
  const result: { year: number; month: number }[] = [];
  const [sy, sm] = start.split("-").map(Number);
  const [ey, em] = end.split("-").map(Number);

  let y = sy, m = sm;
  while (y < ey || (y === ey && m <= em)) {
    result.push({ year: y, month: m });
    m++;
    if (m > 12) { m = 1; y++; }
  }
  return result;
}
