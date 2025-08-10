import { describe, it, expect, beforeEach } from "vitest";

interface NFT {
  owner: string;
  metadataUri: string;
  verified: boolean;
}

interface ProvenanceEntry {
  owner: string;
  timestamp: bigint;
}

interface Event {
  eventType: string;
  tokenId: bigint;
  sender: string;
  data: string;
}

interface MockNFTContract {
  admin: string;
  paused: boolean;
  totalNfts: bigint;
  oracle: string;
  nfts: Map<bigint, NFT>;
  provenance: Map<bigint, ProvenanceEntry[]>;
  events: Map<bigint, Event>;
  lastEventId: bigint;
  MAX_NFTS: bigint;

  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  setOracle(caller: string, newOracle: string): { value: boolean } | { error: number };
  transferAdmin(caller: string, newAdmin: string): { value: boolean } | { error: number };
  mintArtifact(caller: string, recipient: string, metadataUri: string, artifactId: bigint): { value: bigint } | { error: number };
  verifyArtifact(caller: string, tokenId: bigint): { value: boolean } | { error: number };
  updateMetadata(caller: string, tokenId: bigint, newMetadataUri: string, dao: string): { value: boolean } | { error: number };
  transferArtifact(caller: string, tokenId: bigint, newOwner: string): { value: boolean } | { error: number };
}

const mockContract: MockNFTContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  totalNfts: 0n,
  oracle: "SP000000000000000000002Q6VF78",
  nfts: new Map(),
  provenance: new Map(),
  events: new Map(),
  lastEventId: 0n,
  MAX_NFTS: 1_000_000n,

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    this.events.set(++this.lastEventId, { eventType: "pause-toggled", tokenId: 0n, sender: caller, data: pause ? "paused" : "unpaused" });
    return { value: pause };
  },

  setOracle(caller: string, newOracle: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newOracle === "SP000000000000000000002Q6VF78") return { error: 101 };
    this.oracle = newOracle;
    return { value: true };
  },

  transferAdmin(caller: string, newAdmin: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newAdmin === "SP000000000000000000002Q6VF78") return { error: 101 };
    this.admin = newAdmin;
    this.events.set(++this.lastEventId, { eventType: "admin-transferred", tokenId: 0n, sender: caller, data: newAdmin });
    return { value: true };
  },

  mintArtifact(caller: string, recipient: string, metadataUri: string, artifactId: bigint) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (recipient === "SP000000000000000000002Q6VF78") return { error: 101 };
    if (metadataUri.length === 0) return { error: 105 };
    if (this.totalNfts >= this.MAX_NFTS) return { error: 103 };
    const tokenId = ++this.totalNfts;
    this.nfts.set(tokenId, { owner: recipient, metadataUri, verified: false });
    this.provenance.set(tokenId, [{ owner: recipient, timestamp: 100n }]);
    this.events.set(++this.lastEventId, { eventType: "nft-minted", tokenId, sender: caller, data: metadataUri });
    return { value: tokenId };
  },

  verifyArtifact(caller: string, tokenId: bigint) {
    if (caller !== this.oracle) return { error: 100 };
    const nft = this.nfts.get(tokenId);
    if (!nft) return { error: 102 };
    this.nfts.set(tokenId, { ...nft, verified: true });
    this.events.set(++this.lastEventId, { eventType: "nft-verified", tokenId, sender: caller, data: "" });
    return { value: true };
  },

  updateMetadata(caller: string, tokenId: bigint, newMetadataUri: string, dao: string) {
    if (caller !== dao) return { error: 100 };
    if (newMetadataUri.length === 0) return { error: 105 };
    const nft = this.nfts.get(tokenId);
    if (!nft) return { error: 102 };
    if (!nft.verified) return { error: 106 };
    this.nfts.set(tokenId, { ...nft, metadataUri: newMetadataUri });
    this.events.set(++this.lastEventId, { eventType: "metadata-updated", tokenId, sender: caller, data: newMetadataUri });
    return { value: true };
  },

  transferArtifact(caller: string, tokenId: bigint, newOwner: string) {
    if (this.paused) return { error: 104 };
    if (newOwner === "SP000000000000000000002Q6VF78") return { error: 101 };
    const nft = this.nfts.get(tokenId);
    if (!nft) return { error: 102 };
    if (nft.owner !== caller) return { error: 103 };
    if (!nft.verified) return { error: 106 };
    this.nfts.set(tokenId, { ...nft, owner: newOwner });
    const provenance = this.provenance.get(tokenId) || [];
    this.provenance.set(tokenId, [{ owner: newOwner, timestamp: 101n }, ...provenance]);
    this.events.set(++this.lastEventId, { eventType: "nft-transferred", tokenId, sender: caller, data: newOwner });
    return { value: true };
  },
};

describe("HeritageVault Artifact NFT Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.totalNfts = 0n;
    mockContract.oracle = "SP000000000000000000002Q6VF78";
    mockContract.nfts = new Map();
    mockContract.provenance = new Map();
    mockContract.events = new Map();
    mockContract.lastEventId = 0n;
  });

  it("should mint an NFT when called by admin", () => {
    const result = mockContract.mintArtifact(
      mockContract.admin,
      "ST2CY5...",
      "ipfs://metadata",
      1n
    );
    expect(result).toEqual({ value: 1n });
    expect(mockContract.nfts.get(1n)).toEqual({
      owner: "ST2CY5...",
      metadataUri: "ipfs://metadata",
      verified: false,
    });
    expect(mockContract.provenance.get(1n)).toEqual([
      { owner: "ST2CY5...", timestamp: 100n },
    ]);
  });

  it("should prevent minting by non-admin", () => {
    const result = mockContract.mintArtifact(
      "ST3NB...",
      "ST2CY5...",
      "ipfs://metadata",
      1n
    );
    expect(result).toEqual({ error: 100 });
  });

  it("should verify an NFT by oracle", () => {
    mockContract.mintArtifact(mockContract.admin, "ST2CY5...", "ipfs://metadata", 1n);
    mockContract.oracle = "ST4RE...";
    const result = mockContract.verifyArtifact("ST4RE...", 1n);
    expect(result).toEqual({ value: true });
    expect(mockContract.nfts.get(1n)?.verified).toBe(true);
  });

  it("should update metadata with DAO approval", () => {
    mockContract.mintArtifact(mockContract.admin, "ST2CY5...", "ipfs://metadata", 1n);
    mockContract.verifyArtifact(mockContract.oracle, 1n);
    const result = mockContract.updateMetadata(
      "ST5DA...",
      1n,
      "ipfs://new-metadata",
      "ST5DA..."
    );
    expect(result).toEqual({ value: true });
    expect(mockContract.nfts.get(1n)?.metadataUri).toBe("ipfs://new-metadata");
  });

  it("should transfer an NFT by owner", () => {
    mockContract.mintArtifact(mockContract.admin, "ST2CY5...", "ipfs://metadata", 1n);
    mockContract.verifyArtifact(mockContract.oracle, 1n);
    const result = mockContract.transferArtifact("ST2CY5...", 1n, "ST3NB...");
    expect(result).toEqual({ value: true });
    expect(mockContract.nfts.get(1n)?.owner).toBe("ST3NB...");
    expect(mockContract.provenance.get(1n)).toContainEqual({
      owner: "ST3NB...",
      timestamp: 101n,
    });
  });

  it("should prevent transfers when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.transferArtifact("ST2CY5...", 1n, "ST3NB...");
    expect(result).toEqual({ error: 104 });
  });

  it("should emit events for minting", () => {
    mockContract.mintArtifact(mockContract.admin, "ST2CY5...", "ipfs://metadata", 1n);
    expect(mockContract.events.get(1n)).toEqual({
      eventType: "nft-minted",
      tokenId: 1n,
      sender: mockContract.admin,
      data: "ipfs://metadata",
    });
  });
});