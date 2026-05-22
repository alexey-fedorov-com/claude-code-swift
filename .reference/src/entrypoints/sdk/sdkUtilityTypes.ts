// SDK utility types
import type { ModelUsage } from './coreTypes.generated.js';

export type NonNullableUsage = {
  [K in keyof ModelUsage]-?: NonNullable<ModelUsage[K]>;
};
