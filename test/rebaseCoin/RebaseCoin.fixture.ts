import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";
import { IUniswapV2Factory, IUniswapV2Router02, UniswapV2Deployer } from "uniswap-v2-deploy-plugin";

import type { BondOrchestrator, RebaseCoin, RebaseToken } from "../../src/types/contracts";
import type { BondOrchestrator__factory, RebaseCoin__factory } from "../../src/types/factories/contracts";

export async function deployRebaseCoinFixture(): Promise<{
  rebaseCoin: RebaseCoin;
  rebaseToken: RebaseToken;
  bondOrchestrator: BondOrchestrator;
  factory: IUniswapV2Factory;
  router: IUniswapV2Router02;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const { factory, router } = await UniswapV2Deployer.deploy(owner);

  const rebaseCoinFactory: RebaseCoin__factory = <RebaseCoin__factory>await ethers.getContractFactory("RebaseCoin");
  const rebaseCoin: RebaseCoin = <RebaseCoin>await rebaseCoinFactory.connect(owner).deploy(factory.address);
  await rebaseCoin.deployed();

  const rebaseTokenAddr = await rebaseCoin.tokenContract();
  const rebaseToken: RebaseToken = <RebaseToken>await ethers.getContractAt("RebaseToken", rebaseTokenAddr);

  const bondOrchestratorAddr = await rebaseCoin.bondOrchestrator();
  const bondOrchestrator: BondOrchestrator = <BondOrchestrator>(
    await ethers.getContractAt("BondOrchestrator", bondOrchestratorAddr)
  );

  return { rebaseCoin, rebaseToken, bondOrchestrator, factory, router };
}
