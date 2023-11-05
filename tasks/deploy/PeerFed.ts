import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { PeerFed } from "../../src/types/contracts";
import type { PeerFed__factory } from "../../src/types/factories/contracts";

task("deploy:PeerFed").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];
  const factory: PeerFed__factory = <PeerFed__factory>await ethers.getContractFactory("PeerFed");
  const peerfed: PeerFed = <PeerFed>await factory.connect(owner).deploy();
  await peerfed.deployed();

  const token0 = await peerfed.token0();
  const token1 = await peerfed.token1();

  console.log("PeerFed deployed to: ", peerfed.address);
  console.log("token0 deployed to: ", token0);
  console.log("token1 deployed to: ", token1);
});
