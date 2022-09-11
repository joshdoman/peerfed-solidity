import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type {
  BaseERC20,
  ScaledERC20,
  StablecashAuctionHouse,
  StablecashExchange,
  StablecashOrchestrator,
} from "../../src/types/contracts";
import type { StablecashOrchestrator__factory } from "../../src/types/factories/contracts";

export async function deployStablecashFixture(): Promise<{
  orchestrator: StablecashOrchestrator;
  mShare: BaseERC20;
  bShare: BaseERC20;
  mToken: ScaledERC20;
  bToken: ScaledERC20;
  exchange: StablecashExchange;
  auctionHouse: StablecashAuctionHouse;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  // WETH address (Goerli)
  const wethAddress = "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6";

  const orchestratorFactory: StablecashOrchestrator__factory = <StablecashOrchestrator__factory>(
    await ethers.getContractFactory("StablecashOrchestrator")
  );
  const orchestrator: StablecashOrchestrator = <StablecashOrchestrator>(
    await orchestratorFactory.connect(owner).deploy(wethAddress)
  );
  await orchestrator.deployed();

  const mShareAddress = await orchestrator.mShare();
  const mShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", mShareAddress);

  const bShareAddress = await orchestrator.bShare();
  const bShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", bShareAddress);

  const mTokenAddress = await orchestrator.mToken();
  const mToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", mTokenAddress);

  const bTokenAddress = await orchestrator.bToken();
  const bToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", bTokenAddress);

  const exchangeAddress = await orchestrator.exchange();
  const exchange: StablecashExchange = <StablecashExchange>(
    await ethers.getContractAt("StablecashExchange", exchangeAddress)
  );

  const auctionHouseAddress = await orchestrator.auction();
  const auctionHouse: StablecashAuctionHouse = <StablecashAuctionHouse>(
    await ethers.getContractAt("StablecashAuctionHouse", auctionHouseAddress)
  );

  return { orchestrator, mShare, bShare, mToken, bToken, exchange, auctionHouse };
}
