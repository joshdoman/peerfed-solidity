import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeBaseERC20 } from "./BaseERC20.behavior";
import { shouldBehaveLikeScaledERC20 } from "./ScaledERC20.behavior";
import { deployOwnerBalanceFixture, deployPeerFedFixture } from "./PeerFed.fixture";
import { shouldBehaveLikePeerFedAuctionHouse } from "./PeerFedAuctionHouse.behavior";
import { shouldBehaveLikePeerFedExchange } from "./PeerFedExchange.behavior";
import { shouldBehaveLikePeerFedOrchestrator } from "./PeerFedOrchestrator.behavior";

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
      const { orchestrator, mShare, bShare, mToken, bToken, auctionHouse } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;

      await deployOwnerBalanceFixture(auctionHouse);
    });

    shouldBehaveLikeBaseERC20();
  });

  describe("ScaledERC20", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken, auctionHouse } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;

      await deployOwnerBalanceFixture(auctionHouse);
    });

    shouldBehaveLikeScaledERC20();
  });

  describe("PeerFedExchange", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken, exchange, auctionHouse } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
      this.exchange = exchange;

      await deployOwnerBalanceFixture(auctionHouse);
    });

    shouldBehaveLikePeerFedExchange();
  });

  describe("PeerFedAuctionHouse", function () {
    beforeEach(async function () {
      const { orchestrator, mShare, bShare, mToken, bToken, auctionHouse } = await this.loadFixture(
        deployPeerFedFixture,
      );
      this.orchestrator = orchestrator;
      this.mShare = mShare;
      this.bShare = bShare;
      this.auctionHouse = auctionHouse;
    });

    shouldBehaveLikePeerFedAuctionHouse();
  });
});
