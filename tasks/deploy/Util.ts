import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { Util, UtilLibraryExternal } from "../../src/types/contracts";
import type { UtilLibraryExternal__factory, Util__factory } from "../../src/types/factories/contracts";

task("deploy:Util").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];
  const factory: Util__factory = <Util__factory>await ethers.getContractFactory("Util");
  const util: Util = <Util>await factory.connect(owner).deploy();
  await util.deployed();

  const token0 = await util.token0();
  const token1 = await util.token1();

  const libraryFactory: UtilLibraryExternal__factory = <UtilLibraryExternal__factory>(
    await ethers.getContractFactory("UtilLibraryExternal")
  );
  const library: UtilLibraryExternal = <UtilLibraryExternal>await libraryFactory.connect(owner).deploy();
  await library.deployed();

  console.log("Util deployed to: ", util.address);
  console.log("token0 deployed to: ", token0);
  console.log("token1 deployed to: ", token1);
  console.log("UtilLibraryExternal deployed to: ", library.address);
});
