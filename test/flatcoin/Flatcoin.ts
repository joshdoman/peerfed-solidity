import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikeFlatcoin } from "./Flatcoin.behavior";
import { deployFlatcoinFixture } from "./Flatcoin.fixture";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.owner = signers[0];
    this.signers.addr1 = signers[1];
    this.signers.addr2 = signers[2];

    this.loadFixture = loadFixture;
  });

  describe("Flatcoin", function () {
    beforeEach(async function () {
      const { flatcoin } = await this.loadFixture(deployFlatcoinFixture);
      this.flatcoin = flatcoin;
    });

    shouldBehaveLikeFlatcoin();
  });
});
