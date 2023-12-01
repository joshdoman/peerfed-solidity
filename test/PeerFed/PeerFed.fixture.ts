import type { SignerWithAddress } from "@nomiclabs/hardhat-ethers/dist/src/signer-with-address";
import { ethers } from "hardhat";

import type { PeerFed, PeerFedLibraryExternal, SwappableERC20 } from "../../src/types/contracts";
import type { PeerFedLibraryExternal__factory, PeerFed__factory } from "../../src/types/factories/contracts";

export async function deployPeerFedFixture(): Promise<{
  peerfed: PeerFed;
  token0: SwappableERC20;
  token1: SwappableERC20;
  library: PeerFedLibraryExternal;
}> {
  const signers: SignerWithAddress[] = await ethers.getSigners();
  const owner: SignerWithAddress = signers[0];

  const factory: PeerFed__factory = <PeerFed__factory>await ethers.getContractFactory("PeerFed");
  const peerfed: PeerFed = <PeerFed>await factory.connect(owner).deploy();
  await peerfed.deployed();

  const token0: SwappableERC20 = <SwappableERC20>await ethers.getContractAt("SwappableERC20", await peerfed.token0());
  const token1: SwappableERC20 = <SwappableERC20>await ethers.getContractAt("SwappableERC20", await peerfed.token1());

  const libraryFactory: PeerFedLibraryExternal__factory = <PeerFedLibraryExternal__factory>(
    await ethers.getContractFactory("PeerFedLibraryExternal")
  );
  const library: PeerFedLibraryExternal = <PeerFedLibraryExternal>await libraryFactory.connect(owner).deploy();
  await library.deployed();

  return { peerfed, token0, token1, library };
}
