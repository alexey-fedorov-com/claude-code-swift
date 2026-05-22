/**
 * Fast ANSI escape code stripper.
 * Uses Bun.stripANSI when available (native, significantly faster),
 * falls back to the strip-ansi npm package.
 */
import stripAnsiPkg from 'strip-ansi'

const bunStripAnsi =
  typeof Bun !== 'undefined' && typeof (Bun as any).stripANSI === 'function'
    ? (Bun as any).stripANSI as (str: string) => string
    : null

const stripAnsi: (str: string) => string = bunStripAnsi ?? stripAnsiPkg

export default stripAnsi
