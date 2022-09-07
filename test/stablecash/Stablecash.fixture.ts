import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { BaseERC20, ScaledERC20, StablecashFactory } from "../../src/types/contracts";
import type { StablecashFactory__factory } from "../../src/types/factories/contracts";

export async function deployStablecashFixture(): Promise<{
  factory: StablecashFactory;
  mShare: BaseERC20;
  bShare: BaseERC20;
  mToken: ScaledERC20;
  bToken: ScaledERC20;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const factoryDeployer: StablecashFactory__factory = <StablecashFactory__factory>(
    await ethers.getContractFactory("StablecashFactory")
  );
  const factory: StablecashFactory = <StablecashFactory>await factoryDeployer.connect(owner).deploy();
  await factory.deployed();

  const mShareAddress = await factory.mShare();
  const mShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", mShareAddress);

  const bShareAddress = await factory.bShare();
  const bShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", bShareAddress);

  const mTokenAddress = await factory.mToken();
  const mToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", mTokenAddress);

  const bTokenAddress = await factory.bToken();
  const bToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", bTokenAddress);

  return { factory, mShare, bShare, mToken, bToken };
}
