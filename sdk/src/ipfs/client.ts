import type { Hex } from "viem";

export interface IPFSConfig {
  /** Pinata JWT for authenticated uploads. */
  pinataJwt?: string;
  /** Custom gateway for fetching (default: https://gateway.pinata.cloud) */
  gateway?: string;
}

/**
 * Minimal IPFS client using the Pinata HTTP API.
 * Converts between arbitrary JSON/content and the bytes32 CID representation
 * used on-chain.
 */
export class IPFSClient {
  private readonly pinataJwt: string | undefined;
  private readonly gateway: string;
  private readonly pinataBaseUrl = "https://api.pinata.cloud";

  constructor(config: IPFSConfig = {}) {
    this.pinataJwt = config.pinataJwt;
    this.gateway = config.gateway ?? "https://gateway.pinata.cloud";
  }

  // -------------------------------------------------------------------------
  // Upload
  // -------------------------------------------------------------------------

  /** Upload JSON data and return the CIDv1 string. */
  async uploadJSON(data: unknown, name?: string): Promise<string> {
    const body = JSON.stringify(data);
    return this._upload(
      new Blob([body], { type: "application/json" }),
      name ?? "data.json"
    );
  }

  /** Upload raw text and return the CIDv1 string. */
  async uploadText(text: string, name?: string): Promise<string> {
    return this._upload(
      new Blob([text], { type: "text/plain" }),
      name ?? "data.txt"
    );
  }

  private async _upload(blob: Blob, name: string): Promise<string> {
    if (!this.pinataJwt) {
      throw new Error("Pinata JWT required for uploads. Set IPFSConfig.pinataJwt.");
    }

    const formData = new FormData();
    formData.append("file", blob, name);
    formData.append(
      "pinataMetadata",
      JSON.stringify({ name })
    );
    formData.append(
      "pinataOptions",
      JSON.stringify({ cidVersion: 1 })
    );

    const res = await fetch(`${this.pinataBaseUrl}/pinning/pinFileToIPFS`, {
      method: "POST",
      headers: { Authorization: `Bearer ${this.pinataJwt}` },
      body: formData,
    });

    if (!res.ok) {
      const text = await res.text();
      throw new Error(`IPFS upload failed: ${res.status} ${text}`);
    }

    const result = (await res.json()) as { IpfsHash: string };
    return result.IpfsHash;
  }

  // -------------------------------------------------------------------------
  // Download
  // -------------------------------------------------------------------------

  async fetchJSON<T = unknown>(cid: string): Promise<T> {
    const res = await fetch(`${this.gateway}/ipfs/${cid}`);
    if (!res.ok) throw new Error(`IPFS fetch failed: ${res.status}`);
    return res.json() as Promise<T>;
  }

  async fetchText(cid: string): Promise<string> {
    const res = await fetch(`${this.gateway}/ipfs/${cid}`);
    if (!res.ok) throw new Error(`IPFS fetch failed: ${res.status}`);
    return res.text();
  }

  // -------------------------------------------------------------------------
  // CID ↔ bytes32 conversion
  // -------------------------------------------------------------------------

  /**
   * Converts a base58/base32 CID string to a bytes32 hex string for on-chain storage.
   * Only the first 32 bytes of the multihash are kept — suitable for CIDv0 (sha2-256).
   * For CIDv1, store the full CID off-chain and use this as a deterministic reference.
   */
  static cidToBytes32(cid: string): Hex {
    // Encode CID string as UTF-8 bytes then left-pad/truncate to 32 bytes
    const encoder = new TextEncoder();
    const bytes = encoder.encode(cid);
    const padded = new Uint8Array(32);
    padded.set(bytes.slice(0, 32));
    return `0x${Buffer.from(padded).toString("hex")}` as Hex;
  }

  static bytes32ToCid(bytes32: Hex): string {
    const buf = Buffer.from(bytes32.slice(2), "hex");
    const decoder = new TextDecoder();
    return decoder.decode(buf).replace(/\0/g, "");
  }
}
