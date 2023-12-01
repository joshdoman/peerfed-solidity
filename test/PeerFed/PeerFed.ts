import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Signers } from "../types";
import { shouldBehaveLikePeerFed } from "./PeerFed.behavior";
import { deployPeerFedFixture } from "./PeerFed.fixture";
import { shouldBehaveLikePeerFedLibrary } from "./PeerFedLibrary.behavior";

describe("Unit tests", function () {
  before(async function () {
    this.signers = {} as Signers;

    const signers: SignerWithAddress[] = await ethers.getSigners();
    this.signers.owner = signers[0];
    this.signers.addr1 = signers[1];
    this.signers.addr2 = signers[2];

    this.loadFixture = loadFixture;
  });

  describe("PeerFedLibrary", function () {
    beforeEach(async function () {
      const { library } = await this.loadFixture(deployPeerFedFixture);
      this.library = library;
    });

    shouldBehaveLikePeerFedLibrary();
  });

  describe("PeerFed", function () {
    beforeEach(async function () {
      const { peerfed, token0, token1, library } = await this.loadFixture(deployPeerFedFixture);
      this.peerfed = peerfed;
      this.token0 = token0;
      this.token1 = token1;
      this.library = library;
    });

    shouldBehaveLikePeerFed();
  });
});
