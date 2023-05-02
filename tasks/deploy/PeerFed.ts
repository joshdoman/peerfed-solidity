import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { BaseERC20, PeerFedConverter, PeerFedOrchestrator, ScaledERC20 } from "../../src/types/contracts";
import type { PeerFedOrchestrator__factory } from "../../src/types/factories/contracts";

task("deploy:PeerFed").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const orchestratorFactory: PeerFedOrchestrator__factory = <PeerFedOrchestrator__factory>(
    await ethers.getContractFactory("PeerFedOrchestrator")
  );
  const orchestrator: PeerFedOrchestrator = <PeerFedOrchestrator>await orchestratorFactory.connect(owner).deploy();
  await orchestrator.deployed();

  const mShareAddress = await orchestrator.mShare();
  const mShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", mShareAddress);

  const bShareAddress = await orchestrator.bShare();
  const bShare: BaseERC20 = <BaseERC20>await ethers.getContractAt("BaseERC20", bShareAddress);

  const mTokenAddress = await orchestrator.mToken();
  const mToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", mTokenAddress);

  const bTokenAddress = await orchestrator.bToken();
  const bToken: ScaledERC20 = <ScaledERC20>await ethers.getContractAt("ScaledERC20", bTokenAddress);

  const converterAddress = await orchestrator.converter();
  const converter: PeerFedConverter = <PeerFedConverter>(
    await ethers.getContractAt("PeerFedConverter", converterAddress)
  );

  console.log("PeerFedOrchestrator deployed to: ", orchestrator.address);
  console.log("mShare deployed to: ", mShare.address);
  console.log("bShare deployed to: ", bShare.address);
  console.log("mToken deployed to: ", mToken.address);
  console.log("bToken deployed to: ", bToken.address);
  console.log("PeerFedConverter deployed to: ", converter.address);
});
