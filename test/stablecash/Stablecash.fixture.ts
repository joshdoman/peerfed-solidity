import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

// import type {
//   FlatExchange,
//   FlatExchangeFactory,
//   Flatcoin,
//   FlatcoinBond,
//   FlatcoinIssuanceToken,
//   FlatcoinTotal,
//   Orchestrator,
//   UnmintedFlatcoin,
// } from "../../src/types/contracts";
// import type {
//   FlatcoinBond__factory,
//   Flatcoin__factory,
//   Orchestrator__factory,
//   UnmintedFlatcoin__factory,
// } from "../../src/types/factories/contracts";
//
// export async function deployFlatcoinFixture(): Promise<{
//   flatcoin: Flatcoin;
//   flatcoinBond: FlatcoinBond;
//   unmintedFlatcoin: UnmintedFlatcoin;
//   flatcoinTotal: FlatcoinTotal;
//   issuanceToken: FlatcoinIssuanceToken;
//   orchestrator: Orchestrator;
//   exchange: FlatExchange;
//   factory: FlatExchangeFactory;
// }> {
//   const signers: SignerWithAddress[] = await ethers.getSigners();
//   const owner: SignerWithAddress = signers[0];
//
//   const flatcoinBondFactory: FlatcoinBond__factory = <FlatcoinBond__factory>(
//     await ethers.getContractFactory("FlatcoinBond")
//   );
//   const flatcoinBond: FlatcoinBond = <FlatcoinBond>await flatcoinBondFactory.connect(owner).deploy();
//   await flatcoinBond.deployed();
//
//   const unmintedFlatcoinFactory: UnmintedFlatcoin__factory = <UnmintedFlatcoin__factory>(
//     await ethers.getContractFactory("UnmintedFlatcoin")
//   );
//   const unmintedFlatcoin: UnmintedFlatcoin = <UnmintedFlatcoin>await unmintedFlatcoinFactory.connect(owner).deploy();
//   await unmintedFlatcoin.deployed();
//
//   const flatcoinFactory: Flatcoin__factory = <Flatcoin__factory>await ethers.getContractFactory("Flatcoin");
//   const flatcoin: Flatcoin = <Flatcoin>await flatcoinFactory.connect(owner).deploy(unmintedFlatcoin.address);
//   await flatcoin.deployed();
//
//   const orchestratorFactory: Orchestrator__factory = <Orchestrator__factory>(
//     await ethers.getContractFactory("Orchestrator")
//   );
//   const orchestrator: Orchestrator = <Orchestrator>(
//     await orchestratorFactory.connect(owner).deploy(flatcoin.address, unmintedFlatcoin.address, flatcoinBond.address)
//   );
//   await orchestrator.deployed();
//
//   const flatcoinTotalAddress = await orchestrator.flatcoinTotal();
//   const flatcoinTotal: FlatcoinTotal = <FlatcoinTotal>await ethers.getContractAt("FlatcoinTotal", flatcoinTotalAddress);
//
//   const issuanceTokenAddress = await orchestrator.issuanceToken();
//   const issuanceToken: FlatcoinIssuanceToken = <FlatcoinIssuanceToken>(
//     await ethers.getContractAt("FlatcoinIssuanceToken", issuanceTokenAddress)
//   );
//
//   const exchangeAddress = await orchestrator.exchange();
//   const exchange: FlatExchange = <FlatExchange>await ethers.getContractAt("FlatExchange", exchangeAddress);
//
//   const factoryAddress = await orchestrator.factory();
//   const factory: FlatExchangeFactory = <FlatExchangeFactory>(
//     await ethers.getContractAt("FlatExchangeFactory", factoryAddress)
//   );
//
//   return { flatcoin, flatcoinBond, unmintedFlatcoin, flatcoinTotal, issuanceToken, orchestrator, exchange, factory };
// }
