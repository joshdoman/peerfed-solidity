import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { BaseERC20, ScaledERC20, StablecashFactory } from "../../src/types/contracts";
import type { StablecashFactory__factory } from "../../src/types/factories/contracts";

task("deploy:Stablecash").setAction(async function (taskArguments: TaskArguments, { ethers }) {
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

  console.log("StablecashFactory deployed to: ", factory.address);
  console.log("mShare deployed to: ", mShare.address);
  console.log("bShare deployed to: ", bShare.address);
  console.log("mToken deployed to: ", mToken.address);
  console.log("bToken deployed to: ", bToken.address);
});
