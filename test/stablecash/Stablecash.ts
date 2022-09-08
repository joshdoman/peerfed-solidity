import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeBaseERC20 } from "./BaseERC20.behavior";
import { shouldBehaveLikeScaledERC20 } from "./ScaledERC20.behavior";
import { deployStablecashFixture } from "./Stablecash.fixture";
import { shouldBehaveLikeStablecashFactory } from "./StablecashFactory.behavior";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.owner = signers[0];
    this.signers.addr1 = signers[1];
    this.signers.addr2 = signers[2];

    this.loadFixture = loadFixture;
  });

  describe("StablecashFactory", function () {
    beforeEach(async function () {
      const { factory, mShare, bShare, mToken, bToken } = await this.loadFixture(deployStablecashFixture);
      this.factory = factory;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
    });

    shouldBehaveLikeStablecashFactory();
  });

  describe("BaseERC20", function () {
    beforeEach(async function () {
      const { factory, mShare, bShare, mToken, bToken } = await this.loadFixture(deployStablecashFixture);
      this.factory = factory;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
    });

    shouldBehaveLikeBaseERC20();
  });

  describe("ScaledERC20", function () {
    beforeEach(async function () {
      const { factory, mShare, bShare, mToken, bToken } = await this.loadFixture(deployStablecashFixture);
      this.factory = factory;
      this.mShare = mShare;
      this.bShare = bShare;
      this.mToken = mToken;
      this.bToken = bToken;
    });

    shouldBehaveLikeScaledERC20();
  });
});
