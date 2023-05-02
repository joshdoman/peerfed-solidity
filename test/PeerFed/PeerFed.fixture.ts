import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { utils } from "ethers";
import { ethers } from "hardhat";

import type {
  BaseERC20,
  PeerFedConverter,
  PeerFedOrchestrator,
  ScaledERC20,
} from "../../src/types/contracts";
import type { PeerFedOrchestrator__factory } from "../../src/types/factories/contracts";

export async function deployPeerFedFixture(): Promise<{
  orchestrator: PeerFedOrchestrator;
  mShare: BaseERC20;
  bShare: BaseERC20;
  mToken: ScaledERC20;
  bToken: ScaledERC20;
  converter: PeerFedConverter;
  auctionHouse: PeerFedAuctionHouse;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const orchestratorFactory: PeerFedOrchestrator__factory = <PeerFedOrchestrator__factory>(
    await ethers.getContractFactory("PeerFedOrchestrator")
  );
  const orchestrator: PeerFedOrchestrator = <PeerFedOrchestrator>(
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

  const converterAddress = await orchestrator.converter();
  const converter: PeerFedConverter = <PeerFedConverter>(
    await ethers.getContractAt("PeerFedConverter", converterAddress)
  );

  return { orchestrator, mShare, bShare, mToken, bToken, converter };
}

function eth(n: number) {
  return utils.parseEther(n.toString());
}

async function setTime(newTime: number): Promise<void> {
  await ethers.provider.send("evm_mine", [newTime]);
}
