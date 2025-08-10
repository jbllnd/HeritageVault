import { describe, it, expect, beforeEach } from "vitest";

interface Milestone {
  amount: bigint;
  verified: boolean;
}

interface Project {
  proposalId: bigint;
  totalFunded: bigint;
  milestones: Milestone[];
  active: boolean;
}

interface Contribution {
  contributor: string;
  amount: bigint;
}

interface Event {
  eventType: string;
  projectId: bigint;
  sender: string;
  data: string;
}

interface MockCrowdfundingContract {
  admin: string;
  paused: boolean;
  daoContract: string;
  oracle: string;
  projects: Map<bigint, Project>;
  contributions: Map<string, Contribution>;
  projectCount: bigint;
  events: Map<bigint, Event>;
  lastEventId: bigint;
  MAX_PROJECTS: bigint;

  isAdmin(caller: string): boolean;
  setPaused(caller: string, pause: boolean): { value: boolean } | { error: number };
  setDaoContract(caller: string, newDao: string): { value: boolean } | { error: number };
  setOracle(caller: string, newOracle: string): { value: boolean } | { error: number };
  transferAdmin(caller: string, newAdmin: string): { value: boolean } | { error: number };
  createProject(caller: string, proposalId: bigint, milestones: bigint[]): { value: bigint } | { error: number };
  fundProject(caller: string, projectId: bigint, amount: bigint): { value: boolean } | { error: number };
  verifyMilestone(caller: string, projectId: bigint, milestoneIndex: number): { value: boolean } | { error: number };
  releaseFunds(caller: string, projectId: bigint, milestoneIndex: number): { value: boolean } | { error: number };
  refundContributors(caller: string, projectId: bigint): { value: boolean } | { error: number };
}

const mockContract: MockCrowdfundingContract = {
  admin: "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM",
  paused: false,
  daoContract: "SP000000000000000000002Q6VF78",
  oracle: "SP000000000000000000002Q6VF78",
  projects: new Map(),
  contributions: new Map(),
  projectCount: 0n,
  events: new Map(),
  lastEventId: 0n,
  MAX_PROJECTS: 10_000n,

  isAdmin(caller: string) {
    return caller === this.admin;
  },

  setPaused(caller: string, pause: boolean) {
    if (!this.isAdmin(caller)) return { error: 100 };
    this.paused = pause;
    this.events.set(++this.lastEventId, { eventType: "pause-toggled", projectId: 0n, sender: caller, data: pause ? "paused" : "unpaused" });
    return { value: pause };
  },

  setDaoContract(caller: string, newDao: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newDao === "SP000000000000000000002Q6VF78") return { error: 100 };
    this.daoContract = newDao;
    return { value: true };
  },

  setOracle(caller: string, newOracle: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newOracle === "SP000000000000000000002Q6VF78") return { error: 100 };
    this.oracle = newOracle;
    return { value: true };
  },

  transferAdmin(caller: string, newAdmin: string) {
    if (!this.isAdmin(caller)) return { error: 100 };
    if (newAdmin === "SP000000000000000000002Q6VF78") return { error: 100 };
    this.admin = newAdmin;
    this.events.set(++this.lastEventId, { eventType: "admin-transferred", projectId: 0n, sender: caller, data: newAdmin });
    return { value: true };
  },

  createProject(caller: string, proposalId: bigint, milestones: bigint[]) {
    if (caller !== this.daoContract) return { error: 100 };
    if (milestones.length === 0 || this.projectCount >= this.MAX_PROJECTS) return { error: 101 };
    const projectId = ++this.projectCount;
    this.projects.set(projectId, {
      proposalId,
      totalFunded: 0n,
      milestones: milestones.map(amount => ({ amount, verified: false })),
      active: true,
    });
    this.events.set(++this.lastEventId, { eventType: "project-created", projectId, sender: caller, data: proposalId.toString() });
    return { value: projectId };
  },

  fundProject(caller: string, projectId: bigint, amount: bigint) {
    if (this.paused) return { error: 105 };
    if (amount === 0n) return { error: 106 };
    const project = this.projects.get(projectId);
    if (!project || !project.active) return { error: 101 };
    this.contributions.set(`${projectId}-${caller}`, {
      contributor: caller,
      amount: amount + (this.contributions.get(`${projectId}-${caller}`)?.amount || 0n),
    });
    this.projects.set(projectId, { ...project, totalFunded: project.totalFunded + amount });
    this.events.set(++this.lastEventId, { eventType: "project-funded", projectId, sender: caller, data: amount.toString() });
    return { value: true };
  },

  verifyMilestone(caller: string, projectId: bigint, milestoneIndex: number) {
    if (caller !== this.oracle) return { error: 100 };
    const project = this.projects.get(projectId);
    if (!project || !project.active) return { error: 101 };
    if (milestoneIndex >= project.milestones.length) return { error: 102 };
    if (project.milestones[milestoneIndex].verified) return { error: 102 };
    project.milestones[milestoneIndex].verified = true;
    this.projects.set(projectId, project);
    this.events.set(++this.lastEventId, { eventType: "milestone-verified", projectId, sender: caller, data: milestoneIndex.toString() });
    return { value: true };
  },

  releaseFunds(caller: string, projectId: bigint, milestoneIndex: number) {
    if (this.paused) return { error: 105 };
    const project = this.projects.get(projectId);
    if (!project || !project.active) return { error: 101 };
    if (milestoneIndex >= project.milestones.length) return { error: 102 };
    if (!project.milestones[milestoneIndex].verified) return { error: 102 };
    this.events.set(++this.lastEventId, {
      eventType: "funds-released",
      projectId,
      sender: caller,
      data: project.milestones[milestoneIndex].amount.toString(),
    });
    return { value: true };
  },

  refundContributors(caller: string, projectId: bigint) {
    if (caller !== this.daoContract) return { error: 100 };
    const project = this.projects.get(projectId);
    if (!project || !project.active) return { error: 101 };
    this.projects.set(projectId, { ...project, active: false });
    this.events.set(++this.lastEventId, { eventType: "project-refunded", projectId, sender: caller, data: "" });
    return { value: true };
  },
};

describe("HeritageVault Crowdfunding Contract", () => {
  beforeEach(() => {
    mockContract.admin = "ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM";
    mockContract.paused = false;
    mockContract.daoContract = "SP000000000000000000002Q6VF78";
    mockContract.oracle = "SP000000000000000000002Q6VF78";
    mockContract.projects = new Map();
    mockContract.contributions = new Map();
    mockContract.projectCount = 0n;
    mockContract.events = new Map();
    mockContract.lastEventId = 0n;
  });

  it("should create a project by DAO", () => {
    mockContract.daoContract = "ST2CY5...";
    const result = mockContract.createProject("ST2CY5...", 1n, [100n, 200n]);
    expect(result).toEqual({ value: 1n });
    expect(mockContract.projects.get(1n)).toEqual({
      proposalId: 1n,
      totalFunded: 0n,
      milestones: [{ amount: 100n, verified: false }, { amount: 200n, verified: false }],
      active: true,
    });
  });

  it("should allow funding a project", () => {
    mockContract.daoContract = "ST2CY5...";
    mockContract.createProject("ST2CY5...", 1n, [100n, 200n]);
    const result = mockContract.fundProject("ST3NB...", 1n, 50n);
    expect(result).toEqual({ value: true });
    expect(mockContract.contributions.get("1-ST3NB...")).toEqual({ contributor: "ST3NB...", amount: 50n });
    expect(mockContract.projects.get(1n)?.totalFunded).toBe(50n);
  });

  it("should verify a milestone by oracle", () => {
    mockContract.daoContract = "ST2CY5...";
    mockContract.oracle = "ST4RE...";
    mockContract.createProject("ST2CY5...", 1n, [100n, 200n]);
    const result = mockContract.verifyMilestone("ST4RE...", 1n, 0);
    expect(result).toEqual({ value: true });
    expect(mockContract.projects.get(1n)?.milestones[0].verified).toBe(true);
  });

  it("should refund contributors by DAO", () => {
    mockContract.daoContract = "ST2CY5...";
    mockContract.createProject("ST2CY5...", 1n, [100n, 200n]);
    const result = mockContract.refundContributors("ST2CY5...", 1n);
    expect(result).toEqual({ value: true });
    expect(mockContract.projects.get(1n)?.active).toBe(false);
  });

  it("should prevent funding when paused", () => {
    mockContract.setPaused(mockContract.admin, true);
    const result = mockContract.fundProject("ST3NB...", 1n, 50n);
    expect(result).toEqual({ error: 105 });
  });
});