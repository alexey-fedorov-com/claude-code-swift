import type {
  ContentBlockParam,
  ImageBlockParam,
  TextBlockParam,
} from '@anthropic-ai/sdk/resources/index.mjs'
import { getFeatureValue_CACHED_MAY_BE_STALE } from '../services/analytics/growthbook.js'
import {
  countMessagesTokensWithAPI,
  roughTokenCountEstimation,
} from '../services/tokenEstimation.js'
import { compressImageBlock } from './imageResizer.js'
import { logError } from './log.js'

export const MCP_TOKEN_COUNT_THRESHOLD_FACTOR = 0.5
export const IMAGE_TOKEN_ESTIMATE = 1600
const DEFAULT_MAX_MCP_OUTPUT_TOKENS = 25000

/**
 * Maximum allowed value for _meta["anthropic/maxResultSizeChars"] override.
 * MCP tools can request up to 500K chars for large results like DB schemas.
 */
const MAX_RESULT_SIZE_CHARS_CEILING = 500_000

/**
 * Resolve the MCP output token cap. Precedence:
 *   1. MAX_MCP_OUTPUT_TOKENS env var (explicit user override)
 *   2. tengu_satin_quoll GrowthBook flag's `mcp_tool` key (tokens, not chars —
 *      unlike the other keys in that map which getPersistenceThreshold reads
 *      as chars; MCP has its own truncation layer upstream of that)
 *   3. Hardcoded default
 */
export function getMaxMcpOutputTokens(): number {
  const envValue = process.env.MAX_MCP_OUTPUT_TOKENS
  if (envValue) {
    const parsed = parseInt(envValue, 10)
    if (Number.isFinite(parsed) && parsed > 0) {
      return parsed
    }
  }
  const overrides = getFeatureValue_CACHED_MAY_BE_STALE<Record<
    string,
    number
  > | null>('tengu_satin_quoll', {})
  const override = overrides?.['mcp_tool']
  if (
    typeof override === 'number' &&
    Number.isFinite(override) &&
    override > 0
  ) {
    return override
  }
  return DEFAULT_MAX_MCP_OUTPUT_TOKENS
}

export type MCPToolResult = string | ContentBlockParam[] | undefined

function isTextBlock(block: ContentBlockParam): block is TextBlockParam {
  return block.type === 'text'
}

function isImageBlock(block: ContentBlockParam): block is ImageBlockParam {
  return block.type === 'image'
}

export function getContentSizeEstimate(content: MCPToolResult): number {
  if (!content) return 0

  if (typeof content === 'string') {
    return roughTokenCountEstimation(content)
  }

  return content.reduce((total, block) => {
    if (isTextBlock(block)) {
      return total + roughTokenCountEstimation(block.text)
    } else if (isImageBlock(block)) {
      // Estimate for image tokens
      return total + IMAGE_TOKEN_ESTIMATE
    }
    return total
  }, 0)
}

function getMaxMcpOutputChars(): number {
  return getMaxMcpOutputTokens() * 4
}

function getTruncationMessage(): string {
  return `\n\n[OUTPUT TRUNCATED - exceeded ${getMaxMcpOutputTokens()} token limit]

The tool output was truncated. If this MCP server provides pagination or filtering tools, use them to retrieve specific portions of the data. If pagination is not available, inform the user that you are working with truncated output and results may be incomplete.`
}

function truncateString(content: string, maxChars: number): string {
  if (content.length <= maxChars) {
    return content
  }
  return content.slice(0, maxChars)
}

async function truncateContentBlocks(
  blocks: ContentBlockParam[],
  maxChars: number,
): Promise<ContentBlockParam[]> {
  const result: ContentBlockParam[] = []
  let currentChars = 0

  for (const block of blocks) {
    if (isTextBlock(block)) {
      const remainingChars = maxChars - currentChars
      if (remainingChars <= 0) break

      if (block.text.length <= remainingChars) {
        result.push(block)
        currentChars += block.text.length
      } else {
        result.push({ type: 'text', text: block.text.slice(0, remainingChars) })
        break
      }
    } else if (isImageBlock(block)) {
      // Include images but count their estimated size
      const imageChars = IMAGE_TOKEN_ESTIMATE * 4
      if (currentChars + imageChars <= maxChars) {
        result.push(block)
        currentChars += imageChars
      } else {
        // Image exceeds budget - try to compress it to fit remaining space
        const remainingChars = maxChars - currentChars
        if (remainingChars > 0) {
          // Convert remaining chars to bytes for compression
          // base64 uses ~4/3 the original size, so we calculate max bytes
          const remainingBytes = Math.floor(remainingChars * 0.75)
          try {
            const compressedBlock = await compressImageBlock(
              block,
              remainingBytes,
            )
            result.push(compressedBlock)
            // Update currentChars based on compressed image size
            if (compressedBlock.source.type === 'base64') {
              currentChars += compressedBlock.source.data.length
            } else {
              currentChars += imageChars
            }
          } catch {
            // If compression fails, skip the image
          }
        }
      }
    } else {
      result.push(block)
    }
  }

  return result
}

/**
 * Resolve the effective max MCP output chars, considering a tool-level
 * _meta["anthropic/maxResultSizeChars"] override. The override is capped
 * at MAX_RESULT_SIZE_CHARS_CEILING (500K) to prevent unbounded context bloat.
 */
export function resolveMaxMcpOutputChars(metaOverrideChars?: number): number {
  if (
    typeof metaOverrideChars === 'number' &&
    Number.isFinite(metaOverrideChars) &&
    metaOverrideChars > 0
  ) {
    return Math.min(metaOverrideChars, MAX_RESULT_SIZE_CHARS_CEILING)
  }
  return getMaxMcpOutputChars()
}

export async function mcpContentNeedsTruncation(
  content: MCPToolResult,
  metaOverrideChars?: number,
): Promise<boolean> {
  if (!content) return false

  const effectiveMaxTokens = metaOverrideChars
    ? Math.ceil(resolveMaxMcpOutputChars(metaOverrideChars) / 4)
    : getMaxMcpOutputTokens()

  // Use size check as a heuristic to avoid unnecessary token counting API calls
  const contentSizeEstimate = getContentSizeEstimate(content)
  if (
    contentSizeEstimate <=
    effectiveMaxTokens * MCP_TOKEN_COUNT_THRESHOLD_FACTOR
  ) {
    return false
  }

  try {
    const messages =
      typeof content === 'string'
        ? [{ role: 'user' as const, content }]
        : [{ role: 'user' as const, content }]

    const tokenCount = await countMessagesTokensWithAPI(messages, [])
    return !!(tokenCount && tokenCount > effectiveMaxTokens)
  } catch (error) {
    logError(error)
    // Assume no truncation needed on error
    return false
  }
}

export async function truncateMcpContent(
  content: MCPToolResult,
  metaOverrideChars?: number,
): Promise<MCPToolResult> {
  if (!content) return content

  const maxChars = resolveMaxMcpOutputChars(metaOverrideChars)
  const effectiveTokens = Math.ceil(maxChars / 4)
  const truncationMsg = `\n\n[OUTPUT TRUNCATED - exceeded ${effectiveTokens} token limit]

The tool output was truncated. If this MCP server provides pagination or filtering tools, use them to retrieve specific portions of the data. If pagination is not available, inform the user that you are working with truncated output and results may be incomplete.`

  if (typeof content === 'string') {
    return truncateString(content, maxChars) + truncationMsg
  } else {
    const truncatedBlocks = await truncateContentBlocks(
      content as ContentBlockParam[],
      maxChars,
    )
    truncatedBlocks.push({ type: 'text', text: truncationMsg })
    return truncatedBlocks
  }
}

export async function truncateMcpContentIfNeeded(
  content: MCPToolResult,
  metaOverrideChars?: number,
): Promise<MCPToolResult> {
  if (!(await mcpContentNeedsTruncation(content, metaOverrideChars))) {
    return content
  }

  return await truncateMcpContent(content, metaOverrideChars)
}
