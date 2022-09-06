import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";

// import { shouldBehaveLikeExchangeableERC20 } from "./ExchangeableERC20.behavior";
// import { shouldBehaveLikeFlatcoin } from "./Stablecash.behavior";
// import { deployFlatcoinFixture } from "./Stablecash.fixture";

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
    // beforeEach(async function () {
    //   const { flatcoin, flatcoinBond, unmintedFlatcoin } = await this.loadFixture(deployFlatcoinFixture);
    //   this.flatcoin = flatcoin;
    //   this.flatcoinBond = flatcoinBond;
    //   this.unmintedFlatcoin = unmintedFlatcoin;
    // });
    //
    // shouldBehaveLikeFlatcoin();
  });

  describe("ExchangeableERC20", function () {
    // beforeEach(async function () {
    //   const { flatcoin, flatcoinBond, flatcoinTotal, exchange, factory } = await this.loadFixture(
    //     deployFlatcoinFixture,
    //   );
    //   this.flatcoin = flatcoin;
    //   this.flatcoinBond = flatcoinBond;
    //   this.flatcoinTotal = flatcoinTotal;
    //   this.exchange = exchange;
    //   this.factory = factory;
    // });
    //
    // shouldBehaveLikeERC20Swappable();
  });
});
