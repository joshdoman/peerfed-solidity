import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Flatcoin } from "../../src/types/contracts";
import type { Flatcoin__factory } from "../../src/types/factories/contracts";

export async function deployFlatcoinFixture(): Promise<{ flatcoin: Flatcoin }> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const flatcoinFactory: Flatcoin__factory = <Flatcoin__factory>await ethers.getContractFactory("Flatcoin");
  const flatcoin: Flatcoin = <Flatcoin>await flatcoinFactory.connect(owner).deploy();
  await flatcoin.deployed();

  return { flatcoin };
}
