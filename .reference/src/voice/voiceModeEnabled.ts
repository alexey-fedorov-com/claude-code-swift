import { getFeatureValue_CACHED_MAY_BE_STALE } from '../services/analytics/growthbook.js'

/**
 * Kill-switch check for voice mode. Returns true unless the
 * `tengu_amber_quartz_disabled` GrowthBook flag is flipped on (emergency
 * off). Default `false` means a missing/stale disk cache reads as "not
 * killed" — so fresh installs get voice working immediately without
 * waiting for GrowthBook init.
 */
export function isVoiceGrowthBookEnabled(): boolean {
  return !getFeatureValue_CACHED_MAY_BE_STALE('tengu_amber_quartz_disabled', false)
}

/**
 * Auth-only check for voice mode. Bypassed in this build — voice is
 * always available when enabled via /voice.
 */
export function hasVoiceAuth(): boolean {
  return true
}

/**
 * Full runtime check. Voice is always available in this build.
 */
export function isVoiceModeEnabled(): boolean {
  return true
}
