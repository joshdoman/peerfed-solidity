import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { Flatcoin } from "../../src/types/contracts";
import type { Flatcoin__factory } from "../../src/types/factories/contracts";

task("deploy:Flatcoin").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const flatcoinFactory: Flatcoin__factory = <Flatcoin__factory>await ethers.getContractFactory("Flatcoin");
  const flatcoin: Flatcoin = <Flatcoin>await flatcoinFactory.connect(owner).deploy();
  await flatcoin.deployed();

  console.log("Flatcoin deployed to: ", flatcoin.address);
});
