import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { Flatcoin, FlatcoinBond, UnmintedFlatcoin } from "../../src/types/contracts";
import type { Flatcoin__factory, FlatcoinBond__factory, UnmintedFlatcoin__factory } from "../../src/types/factories/contracts";

task("deploy:Flatcoin").setAction(async function (taskArguments: TaskArguments, { ethers }) {
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
  const flatcoin: Flatcoin = <Flatcoin>await flatcoinFactory.connect(owner).deploy(flatcoinBond.address, unmintedFlatcoin.address);
  await flatcoin.deployed();

  console.log("FlatcoinBond deployed to: ", flatcoinBond.address);
  console.log("UnmintedFlatcoin deployed to: ", unmintedFlatcoin.address);
  console.log("Flatcoin deployed to: ", flatcoin.address);
});
