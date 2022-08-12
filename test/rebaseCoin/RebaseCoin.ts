import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeBondOrchestrator } from "./BondOrchestrator.behavior";
import { shouldBehaveLikeRebaseCoin } from "./RebaseCoin.behavior";
import { deployRebaseCoinFixture } from "./RebaseCoin.fixture";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.owner = signers[0];
    this.signers.addr1 = signers[1];
    this.signers.addr2 = signers[2];

    this.loadFixture = loadFixture;
  });

  describe("RebaseCoin", function () {
    beforeEach(async function () {
      const { rebaseCoin, rebaseToken, bondOrchestrator, factory, router } = await this.loadFixture(
        deployRebaseCoinFixture,
      );
      this.rebaseCoin = rebaseCoin;
      this.rebaseToken = rebaseToken;
      this.bondOrchestrator = bondOrchestrator;
      this.factory = factory;
      this.router = router;
    });

    shouldBehaveLikeRebaseCoin();
  });

  describe("BondOrchestrator", function () {
    beforeEach(async function () {
      const { rebaseCoin, rebaseToken, bondOrchestrator, factory, router } = await this.loadFixture(
        deployRebaseCoinFixture,
      );
      this.rebaseCoin = rebaseCoin;
      this.rebaseToken = rebaseToken;
      this.bondOrchestrator = bondOrchestrator;
      this.factory = factory;
      this.router = router;
    });

    shouldBehaveLikeBondOrchestrator();
  });
});
