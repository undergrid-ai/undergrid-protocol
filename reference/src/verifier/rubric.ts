import type { SummaryEntry } from "../worker/summarizer.js";

export interface VerificationReport {
  passed: boolean;
  score: number; // 0-100
  issues: string[];
  details: Array<{ index: number; passed: boolean; reason?: string }>;
}

/**
 * Evaluates a summarization result against the success criteria:
 * - Each entry has required fields (index, summary, keywords)
 * - Summary is ≤ 100 characters
 * - Has 2-5 keywords
 * - Summary is non-empty and non-trivial
 */
export function verifyResult(
  result: SummaryEntry[],
  originalDocuments: string[]
): VerificationReport {
  const issues: string[] = [];
  const details: Array<{ index: number; passed: boolean; reason?: string }> = [];
  let passed = 0;

  if (!Array.isArray(result)) {
    return { passed: false, score: 0, issues: ["Result is not an array"], details: [] };
  }

  if (result.length !== originalDocuments.length) {
    issues.push(
      `Expected ${originalDocuments.length} summaries, got ${result.length}`
    );
  }

  for (let i = 0; i < originalDocuments.length; i++) {
    const entry = result.find((e) => e.index === i);

    if (!entry) {
      details.push({ index: i, passed: false, reason: "Missing entry" });
      continue;
    }

    const entryIssues: string[] = [];

    if (typeof entry.summary !== "string" || entry.summary.trim().length === 0) {
      entryIssues.push("Empty or missing summary");
    } else if (entry.summary.length > 100) {
      entryIssues.push(`Summary too long (${entry.summary.length} chars, max 100)`);
    }

    if (!Array.isArray(entry.keywords)) {
      entryIssues.push("keywords must be an array");
    } else if (entry.keywords.length < 2 || entry.keywords.length > 5) {
      entryIssues.push(`Expected 2-5 keywords, got ${entry.keywords.length}`);
    }

    if (entryIssues.length === 0) {
      passed++;
      details.push({ index: i, passed: true });
    } else {
      details.push({ index: i, passed: false, reason: entryIssues.join("; ") });
      issues.push(...entryIssues.map((msg) => `doc[${i}]: ${msg}`));
    }
  }

  const score = Math.round((passed / originalDocuments.length) * 100);
  const overallPassed = score >= 80; // 80% pass threshold

  return { passed: overallPassed, score, issues, details };
}
