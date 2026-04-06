# IPFSClient

Handles all IPFS uploads and downloads, plus CID ↔ bytes32 conversion.

## Constructor

```typescript
new IPFSClient({
  pinataJwt?: string,   // required for uploads
  gateway?: string,     // default: "https://gateway.pinata.cloud"
})
```

## Instance Methods

### `uploadJSON(data: unknown, name?: string): Promise<string>`

Serialize `data` to JSON and upload to IPFS via Pinata. Returns the CID string.

### `uploadText(text: string, name?: string): Promise<string>`

Upload raw text to IPFS. Returns the CID string.

### `fetchJSON<T>(cid: string): Promise<T>`

Download and parse JSON from IPFS by CID.

### `fetchText(cid: string): Promise<string>`

Download text content from IPFS by CID.

## Static Methods

### `IPFSClient.cidToBytes32(cid: string): Hex`

Convert a CID string to a `bytes32` hex value for on-chain storage.

:::warning
This is a lossy encoding — it stores only the first 32 bytes of the CID. For the full CID, always store the original string off-chain and only use bytes32 as an on-chain reference.
:::

### `IPFSClient.bytes32ToCid(bytes32: Hex): string`

Recover the original CID string from a bytes32 value.

## Example

```typescript
const ipfs = new IPFSClient({ pinataJwt: process.env.PINATA_JWT });

// Upload
const cid = await ipfs.uploadJSON({ documents: [...] }, "input.json");

// Convert for on-chain storage
const bytes32 = IPFSClient.cidToBytes32(cid);  // 0x...

// Recover CID
const recoveredCid = IPFSClient.bytes32ToCid(bytes32);

// Download
const data = await ipfs.fetchJSON<{ documents: string[] }>(recoveredCid);
```
