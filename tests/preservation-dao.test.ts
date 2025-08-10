import { describe, it, expect, beforeEach } from "vitest";

interface Proposal {
  creator: string;
  description: string;
  fundingGoal: bigint;
  crowdfundingContract: string;
  votesFor: bigint;
  votesAgainst: bigint;
  endBlock: bigint;
  executed: boolean;
}

interface Vote {
  voter: string;
  amount: bigint;
}

interface Event {
  eventType: string;
  proposalId: bigint;
  sender: string;
  data: string;
}

interface MockDAOContract {
  admin: string;
  paused: boolean;
  tokenContract: string;
  proposals: Map<bigint, Proposal>;
  votes: Map<string, Vote>;
  proposalCount: bigint;
  events: Map<bigint, Event>;
  lastEventId: bigint;
  VOTING_PERIOD: bigint;
  QUORUM_PERCENT: bigint;

  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  setTokenContract(caller: string, newToken: string): { value: boolean } | { error: number };
  transferAdmin(caller: string, newAdmin: string): { value: boolean } | { error: number };
  createProposal(caller: string, description: string, fundingGoal: bigint, crowdfundingContract: string): { value: bigint } | { error: number };
  vote(caller: string, proposalId: bigint, inFavor: boolean, amount: bigint): { value: boolean } | { error: number };
  executeProposal(caller: string, proposalId: bigint): { value: boolean } | { error: number };
}

const mockContract: MockDAOContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  tokenContract: "SP000000000000000000002Q6VF78",
  proposals: new Map(),
  votes: new Map(),
  proposalCount: 0n,
  events: new Map(),
  lastEventId: 0n,
  VOTING_PERIOD: 1440n,
  QUORUM_PERCENT: 50n,

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    this.events.set(++this.lastEventId, { eventType: "pause-toggled", proposalId: 0n, sender: caller, data: pause ? "paused" : "unpaused" });
    return { value: pause };
  },

  setTokenContract(caller: string, newToken: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newToken === "SP000000000000000000002Q6VF78") return { error: 105 };
    this.tokenContract = newToken;
    return { value: true };
  },

  transferAdmin(caller: string, newAdmin: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newAdmin === "SP000000000000000000002Q6VF78") return { error: 100 };
    this.admin = newAdmin;
    this.events.set(++this.lastEventId, { eventType: "admin-transferred", proposalId: 0n, sender: caller, data: newAdmin });
    return { value: true };
  },

  createProposal(caller: string, description: string, fundingGoal: bigint, crowdfundingContract: string) {
    if (this.paused) return { error: 106 };
    if (description.length === 0 || fundingGoal === 0n || crowdfundingContract === "SP000000000000000000002Q6VF78") return { error: 101 };
    const proposalId = ++this.proposalCount;
    this.proposals.set(proposalId, {
      creator: caller,
      description,
      fundingGoal,
      crowdfundingContract,
      votesFor: 0n,
      votesAgainst: 0n,
      endBlock: 100n + this.VOTING_PERIOD,
      executed: false,
    });
    this.events.set(++this.lastEventId, { eventType: "proposal-created", proposalId, sender: caller, data: description });
    return { value: proposalId };
  },

  vote(caller: string, proposalId: bigint, inFavor: boolean, amount: bigint) {
    if (this.paused) return { error: 106 };
    const proposal = this.proposals.get(proposalId);
    if (!proposal) return { error: 101 };
    if (100n > proposal.endBlock) return { error: 102 };
    if (this.votes.has(`${caller}-${proposalId}`)) return { error: 104 };
    if (amount === 0n) return { error: 101 };
    this.votes.set(`${caller}-${proposalId}`, { voter: caller, amount });
    this.proposals.set(proposalId, {
      ...proposal,
      votesFor: inFavor ? proposal.votesFor + amount : proposal.votesFor,
      votesAgainst: inFavor ? proposal.votesAgainst : proposal.votesAgainst + amount,
    });
    this.events.set(++this.lastEventId, { eventType: "vote-cast", proposalId, sender: caller, data: amount.toString() });
    return { value: true };
  },

  executeProposal(caller: string, proposalId: bigint) {
    if (this.paused) return { error: 106 };
    const proposal = this.proposals.get(proposalId);
    if (!proposal) return { error: 101 };
    if (100n <= proposal.endBlock) return { error: 102 };
    if (proposal.executed) return { error: 101 };
    const totalVotes = proposal.votesFor + proposal.votesAgainst;
    if ((proposal.votesFor * 100n) / totalVotes < this.QUORUM_PERCENT) return { error: 103 };
    this.proposals.set(proposalId, { ...proposal, executed: true });
    this.events.set(++this.lastEventId, { eventType: "proposal-executed", proposalId, sender: caller, data: proposal.description });
    return { value: true };
  },
};

describe("HeritageVault Preservation DAO Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.tokenContract = "SP000000000000000000002Q6VF78";
    mockContract.proposals = new Map();
    mockContract.votes = new Map();
    mockContract.proposalCount = 0n;
    mockContract.events = new Map();
    mockContract.lastEventId = 0n;
  });

  it("should create a proposal", () => {
    const result = mockContract.createProposal(
      "ST2CY5...",
      "Restore ancient vase",
      1000n,
      "ST3NB..."
    );
    expect(result).toEqual({ value: 1n });
    expect(mockContract.proposals.get(1n)).toEqual({
      creator: "ST2CY5...",
      description: "Restore ancient vase",
      fundingGoal: 1000n,
      crowdfundingContract: "ST3NB...",
      votesFor: 0n,
      votesAgainst: 0n,
      endBlock: 1540n,
      executed: false,
    });
  });

  it("should allow voting on a proposal", () => {
    mockContract.createProposal("ST2CY5...", "Restore ancient vase", 1000n, "ST3NB...");
    const result = mockContract.vote("ST4RE...", 1n, true, 100n);
    expect(result).toEqual({ value: true });
    expect(mockContract.votes.get("ST4RE...-1")).toEqual({ voter: "ST4RE...", amount: 100n });
    expect(mockContract.proposals.get(1n)?.votesFor).toBe(100n);
  });

  it("should prevent actions when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.createProposal("ST2CY5...", "Restore ancient vase", 1000n, "ST3NB...");
    expect(result).toEqual({ error: 106 });
  });
});