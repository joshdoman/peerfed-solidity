import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { task } from "hardhat/config";
import type { TaskArguments } from "hardhat/types";

import type { StablecashFactory } from "../../src/types/contracts";
import type { StablecashFactory__factory } from "../../src/types/factories/contracts";

task("deploy:Stablecash").setAction(async function (taskArguments: TaskArguments, { ethers }) {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const factoryInstantiator: StablecashFactory__factory = <StablecashFactory__factory>(
    await ethers.getContractFactory("StablecashFactory")
  );
  const factory: StablecashFactory = <StablecashFactory>await factoryInstantiator.connect(owner).deploy();
  await factory.deployed();

  // const unmintedFlatcoinFactory: UnmintedFlatcoin__factory = <UnmintedFlatcoin__factory>(
  //   await ethers.getContractFactory("UnmintedFlatcoin")
  // );
  // const unmintedFlatcoin: UnmintedFlatcoin = <UnmintedFlatcoin>await unmintedFlatcoinFactory.connect(owner).deploy();
  // await unmintedFlatcoin.deployed();
  //
  // const flatcoinFactory: Flatcoin__factory = <Flatcoin__factory>await ethers.getContractFactory("Flatcoin");
  // const flatcoin: Flatcoin = <Flatcoin>await flatcoinFactory.connect(owner).deploy(unmintedFlatcoin.address);
  // await flatcoin.deployed();
  //
  // const orchestratorFactory: Orchestrator__factory = <Orchestrator__factory>(
  //   await ethers.getContractFactory("Orchestrator")
  // );
  // const orchestrator: Orchestrator = <Orchestrator>(
  //   await orchestratorFactory.connect(owner).deploy(flatcoin.address, unmintedFlatcoin.address, flatcoinBond.address)
  // );
  // await orchestrator.deployed();
  //
  // const flatcoinTotalAddress = await orchestrator.flatcoinTotal();
  // const flatcoinTotal: FlatcoinTotal = <FlatcoinTotal>await ethers.getContractAt("FlatcoinTotal", flatcoinTotalAddress);
  //
  // const issuanceTokenAddress = await orchestrator.issuanceToken();
  // const issuanceToken: FlatcoinIssuanceToken = <FlatcoinIssuanceToken>(
  //   await ethers.getContractAt("FlatcoinIssuanceToken", issuanceTokenAddress)
  // );
  //
  // const exchangeAddress = await orchestrator.exchange();
  // const exchange: FlatExchange = <FlatExchange>await ethers.getContractAt("FlatExchange", exchangeAddress);
  //
  // const factoryAddress = await orchestrator.factory();
  // const factory: FlatExchangeFactory = <FlatExchangeFactory>(
  //   await ethers.getContractAt("FlatExchangeFactory", factoryAddress)
  // );

  console.log("Factory deployed to: ", factory.address);
  // console.log("UnmintedFlatcoin deployed to: ", unmintedFlatcoin.address);
  // console.log("Flatcoin deployed to: ", flatcoin.address);
  // console.log("FlatcoinTotal deployed to: ", flatcoinTotal.address);
  // console.log("FlatcoinIssuanceToken deployed to: ", issuanceToken.address);
  // console.log("FlatExchange deployed to: ", exchange.address);
  // console.log("FlatExchangeFactory deployed to: ", factory.address);
  // console.log("Orchestrator deployed to: ", orchestrator.address);
});
