import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeBaseERC20 } from "./BaseERC20.behavior";
import { deployPeerFedFixture } from "./PeerFed.fixture";
import { shouldBehaveLikePeerFedConverter } from "./PeerFedConverter.behavior";
import { shouldBehaveLikePeerFedMint } from "./PeerFedMint.behavior";
import { shouldBehaveLikePeerFedOrchestrator } from "./PeerFedOrchestrator.behavior";
import { shouldBehaveLikeScaledERC20 } from "./ScaledERC20.behavior";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.owner = signers[0];
    this.signers.addr1 = signers[1];
    this.signers.addr2 = signers[2];

    this.loadFixture = loadFixture;
  });

  describe("PeerFedOrchestrator", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken } = await this.loadFixture(deployPeerFedFixture);
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
    });

    shouldBehaveLikePeerFedOrchestrator();
  });

  describe("BaseERC20", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;

      // Mint to owner
      await orchestrator.mint();
    });

    shouldBehaveLikeBaseERC20();
  });

  describe("ScaledERC20", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;

      // Mint to owner
      await orchestrator.mint();
    });

    shouldBehaveLikeScaledERC20();
  });

  describe("PeerFedConverter", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken, converter } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
      this.converter = converter;

      // Mint to owner
      await orchestrator.mint();
    });

    shouldBehaveLikePeerFedConverter();
  });

  describe("PeerFedMint", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken } = await this.loadFixture(deployPeerFedFixture);
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;

      // Mint to owner
      await orchestrator.mint();
    });

    shouldBehaveLikePeerFedMint();
  });
});
