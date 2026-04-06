import OpenAI from "openai";

export interface SummaryEntry {
  index: number;
  summary: string;
  keywords: string[];
}

/**
 * Summarizes a list of documents using GPT-4o-mini.
 * Falls back to a deterministic stub when OPENAI_API_KEY is not set.
 */
export async function summarizeDocuments(documents: string[]): Promise<SummaryEntry[]> {
  const apiKey = process.env["OPENAI_API_KEY"];

  if (!apiKey) {
    console.warn("[worker] No OPENAI_API_KEY — using stub summarizer");
    return documents.map((doc, i) => ({
      index: i,
      summary: doc.slice(0, 97) + (doc.length > 97 ? "..." : ""),
      keywords: doc
        .split(" ")
        .filter((w) => w.length > 5)
        .slice(0, 3)
        .map((w) => w.toLowerCase().replace(/[^a-z]/g, "")),
    }));
  }

  const openai = new OpenAI({ apiKey });

  const prompt = `You are a document summarizer. For each document in the JSON array below, produce a JSON array where each item has:
- "index": the 0-based index of the document
- "summary": a plain text summary of no more than 100 characters
- "keywords": an array of 2-5 keywords from the document

Return ONLY valid JSON, no markdown, no explanation.

Documents:
${JSON.stringify(documents)}`;

  const response = await openai.chat.completions.create({
    model: "gpt-4o-mini",
    messages: [{ role: "user", content: prompt }],
    temperature: 0.3,
    response_format: { type: "json_object" },
  });

  const content = response.choices[0]?.message?.content;
  if (!content) throw new Error("Empty response from OpenAI");

  const parsed = JSON.parse(content) as { summaries?: SummaryEntry[] } | SummaryEntry[];
  if (Array.isArray(parsed)) return parsed;
  if (parsed.summaries) return parsed.summaries;
  throw new Error("Unexpected response format from OpenAI");
}
