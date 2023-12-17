import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { SwappableERC20, Util, UtilLibraryExternal } from "../../src/types/contracts";
import type { UtilLibraryExternal__factory, Util__factory } from "../../src/types/factories/contracts";

export async function deployUtilFixture(): Promise<{
  util: Util;
  token0: SwappableERC20;
  token1: SwappableERC20;
  library: UtilLibraryExternal;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const factory: Util__factory = <Util__factory>await ethers.getContractFactory("Util");
  const util: Util = <Util>await factory.connect(owner).deploy();
  await util.deployed();

  const token0: SwappableERC20 = <SwappableERC20>await ethers.getContractAt("SwappableERC20", await util.token0());
  const token1: SwappableERC20 = <SwappableERC20>await ethers.getContractAt("SwappableERC20", await util.token1());

  const libraryFactory: UtilLibraryExternal__factory = <UtilLibraryExternal__factory>(
    await ethers.getContractFactory("UtilLibraryExternal")
  );
  const library: UtilLibraryExternal = <UtilLibraryExternal>await libraryFactory.connect(owner).deploy();
  await library.deployed();

  return { util, token0, token1, library };
}
