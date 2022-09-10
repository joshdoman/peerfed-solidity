import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type {
  BaseERC20,
  ScaledERC20,
  StablecashAuction,
  StablecashExchange,
  StablecashOrchestrator,
} from "../../src/types/contracts";
import type { StablecashOrchestrator__factory } from "../../src/types/factories/contracts";

task("deploy:Stablecash").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const orchestratorFactory: StablecashOrchestrator__factory = <StablecashOrchestrator__factory>(
    await ethers.getContractFactory("StablecashOrchestrator")
  );
  const orchestrator: StablecashOrchestrator = <StablecashOrchestrator>(
    await orchestratorFactory.connect(owner).deploy()
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

  const auctionAddress = await orchestrator.auction();
  const auction: StablecashAuction = <StablecashAuction>await ethers.getContractAt("StablecashAuction", auctionAddress);

  console.log("StablecashOrchestrator deployed to: ", orchestrator.address);
  console.log("mShare deployed to: ", mShare.address);
  console.log("bShare deployed to: ", bShare.address);
  console.log("mToken deployed to: ", mToken.address);
  console.log("bToken deployed to: ", bToken.address);
  console.log("StablecashExchange deployed to: ", exchange.address);
  console.log("StablecashAuction deployed to: ", auction.address);
});
