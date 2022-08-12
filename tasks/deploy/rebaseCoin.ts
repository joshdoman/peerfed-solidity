import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";
import { UniswapV2Deployer } from "uniswap-v2-deploy-plugin";

import type { BondOrchestrator, RebaseCoin } from "../../src/types/contracts";
import type { RebaseCoin__factory } from "../../src/types/factories/contracts";

task("deploy:RebaseCoin").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  // let factory: IUniswapV2Factory;
  const { factory } = await UniswapV2Deployer.deploy(owner);
  console.log("Uniswap Factory deployed to: ", factory.address);

  const rebaseCoinFactory: RebaseCoin__factory = <RebaseCoin__factory>await ethers.getContractFactory("RebaseCoin");
  const rebaseCoin: RebaseCoin = <RebaseCoin>await rebaseCoinFactory.connect(owner).deploy(factory.address);
  await rebaseCoin.deployed();

  console.log("RebaseCoin deployed to: ", rebaseCoin.address);

  const bondOrchestratorAddr = await rebaseCoin.bondOrchestrator();
  const bondOrchestrator: BondOrchestrator = <BondOrchestrator>(
    await ethers.getContractAt("BondOrchestrator", bondOrchestratorAddr)
  );

  console.log("BondOrchestrator deployed to: ", bondOrchestrator.address);
});
