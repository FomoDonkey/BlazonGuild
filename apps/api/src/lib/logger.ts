/** Minimal structured JSON logger (one line per event, easy to ship to any collector). */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';
export interface Logger {
  debug(msg: string, data?: Record<string, unknown>): void;
  info(msg: string, data?: Record<string, unknown>): void;
  warn(msg: string, data?: Record<string, unknown>): void;
  error(msg: string, data?: Record<string, unknown>): void;
}

const ORDER: Record<LogLevel, number> = { debug: 10, info: 20, warn: 30, error: 40 };

export function createLogger(minLevel: LogLevel = 'info', sink: (line: string) => void = (l) => process.stdout.write(l + '\n')): Logger {
  const emit = (level: LogLevel, msg: string, data?: Record<string, unknown>) => {
    if (ORDER[level] < ORDER[minLevel]) return;
    sink(JSON.stringify({ t: new Date().toISOString(), level, msg, ...data }));
  };
  return {
    debug: (m, d) => emit('debug', m, d),
    info: (m, d) => emit('info', m, d),
    warn: (m, d) => emit('warn', m, d),
    error: (m, d) => emit('error', m, d),
  };
}

export const silentLogger: Logger = { debug() {}, info() {}, warn() {}, error() {} };
