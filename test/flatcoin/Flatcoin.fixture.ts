import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { Flatcoin, FlatcoinBond, UnmintedFlatcoin } from "../../src/types/contracts";
import type {
  FlatcoinBond__factory,
  Flatcoin__factory,
  UnmintedFlatcoin__factory,
} from "../../src/types/factories/contracts";

export async function deployFlatcoinFixture(): Promise<{
  flatcoin: Flatcoin;
  flatcoinBond: FlatcoinBond;
  unmintedFlatcoin: UnmintedFlatcoin;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const flatcoinBondFactory: FlatcoinBond__factory = <FlatcoinBond__factory>(
    await ethers.getContractFactory("FlatcoinBond")
  );
  const flatcoinBond: FlatcoinBond = <FlatcoinBond>await flatcoinBondFactory.connect(owner).deploy();
  await flatcoinBond.deployed();

  const unmintedFlatcoinFactory: UnmintedFlatcoin__factory = <UnmintedFlatcoin__factory>(
    await ethers.getContractFactory("UnmintedFlatcoin")
  );
  const unmintedFlatcoin: UnmintedFlatcoin = <UnmintedFlatcoin>await unmintedFlatcoinFactory.connect(owner).deploy();
  await unmintedFlatcoin.deployed();

  const flatcoinFactory: Flatcoin__factory = <Flatcoin__factory>await ethers.getContractFactory("Flatcoin");
  const flatcoin: Flatcoin = <Flatcoin>(
    await flatcoinFactory.connect(owner).deploy(flatcoinBond.address, unmintedFlatcoin.address)
  );
  await flatcoin.deployed();

  return { flatcoin, flatcoinBond, unmintedFlatcoin };
}
